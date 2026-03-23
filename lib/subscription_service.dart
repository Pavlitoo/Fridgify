import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 🔥 Визначаємо 3 рівні доступу
enum SubTier { free, pro, family }

class SubscriptionService extends ChangeNotifier {
  // ID твоїх підписок з Google Play Console
  static const String _proId = 'premium_pro_monthly';
  static const String _familyId = 'family_max_monthly';

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  SubTier _localTier = SubTier.free; // Що юзер купив сам
  SubTier _familyTier = SubTier.free; // Що юзер отримав від сім'ї

  List<ProductDetails> _products = [];
  StreamSubscription? _userSub;
  StreamSubscription? _householdSub;

  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // --- 🔥 РОЗУМНІ ГЕТТЕРИ ДЛЯ ПЕРЕВІРОК В UI ---

  // Визначає максимальний рівень користувача
  SubTier get currentTier {
    if (_localTier == SubTier.family || _familyTier == SubTier.family) return SubTier.family;
    if (_localTier == SubTier.pro) return SubTier.pro;
    return SubTier.free;
  }

  // Перевірки для того, щоб ховати рекламу (Pro і Family ховають рекламу)
  bool get hasProOrHigher => currentTier == SubTier.pro || currentTier == SubTier.family;

  // Перевірка для доступу до сімейного чату (Тільки Family)
  bool get hasFamily => currentTier == SubTier.family;

  List<ProductDetails> get products => _products;

  // --- ІНІЦІАЛІЗАЦІЯ ---
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    String savedTier = prefs.getString('local_tier') ?? 'free';
    _localTier = _stringToTier(savedTier);
    notifyListeners();

    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {}, onError: (error) {
      debugPrint("❌ IAP Stream Error: $error");
    });

    await _loadProducts();
    await _iap.restorePurchases();

    _listenToFamilyPremium();
  }

  Future<void> _loadProducts() async {
    final bool available = await _iap.isAvailable();
    if (!available) return;
    const Set<String> ids = {_proId, _familyId};
    final ProductDetailsResponse response = await _iap.queryProductDetails(ids);
    _products = response.productDetails;
    notifyListeners();
  }

  // --- МЕТОД КУПІВЛІ (Тепер приймає ID того, що хочемо купити) ---
  Future<bool> buySubscription(String productId) async {
    if (_products.isEmpty) await _loadProducts();
    if (_products.isEmpty) return false;

    try {
      ProductDetails productDetails = _products.firstWhere((p) => p.id == productId);
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
      _iap.buyNonConsumable(purchaseParam: purchaseParam);
      return true;
    } catch (e) {
      debugPrint("Помилка купівлі: Продукт не знайдено");
      return false;
    }
  }

  Future<void> restorePurchases() async {
    await _iap.restorePurchases();
  }

  Future<void> openManagementPage() async {
    final Uri url = Uri.parse("https://play.google.com/store/account/subscriptions");
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
  }

  // --- 🔥 СЛУХАЧ FIREBASE (ДЛЯ СІМЕЙНОГО ДОСТУПУ) ---
  void _listenToFamilyPremium() {
    final user = _auth.currentUser;
    if (user == null) return;

    _userSub = _firestore.collection('users').doc(user.uid).snapshots().listen((userDoc) {
      if (!userDoc.exists) return;

      final householdId = userDoc.data()?['householdId'];

      if (householdId != null) {
        _householdSub?.cancel();
        _householdSub = _firestore.collection('households').doc(householdId).snapshots().listen((householdDoc) {
          if (householdDoc.exists) {
            String dbTier = householdDoc.data()?['tier'] ?? 'free';
            SubTier familySubTier = _stringToTier(dbTier);

            if (_familyTier != familySubTier) {
              _familyTier = familySubTier;
              notifyListeners();
              debugPrint("👨‍👩‍👧‍👦 Family Tier Updated: ${_familyTier.name}");
            }
          }
        });
      } else {
        if (_familyTier != SubTier.free) {
          _familyTier = SubTier.free;
          _householdSub?.cancel();
          notifyListeners();
          debugPrint("👨‍👩‍👧‍👦 Left family. Family Tier reset to free");
        }
      }
    });
  }

  // --- ОБРОБКА РЕЗУЛЬТАТІВ ВІД GOOGLE ---
  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    SubTier highestFoundTier = SubTier.free;

    if (purchaseDetailsList.isEmpty) {
      await _setLocalTier(SubTier.free);
      return;
    }

    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {

        // Визначаємо, що саме купив юзер
        if (purchaseDetails.productID == _familyId) {
          highestFoundTier = SubTier.family; // Family перебиває Pro
        } else if (purchaseDetails.productID == _proId && highestFoundTier != SubTier.family) {
          highestFoundTier = SubTier.pro;
        }

      }
      if (purchaseDetails.pendingCompletePurchase) {
        await _iap.completePurchase(purchaseDetails);
      }
    }

    await _setLocalTier(highestFoundTier);
  }

  // --- 🔥 СИНХРОНІЗАЦІЯ З БАЗОЮ ДАНИХ ---
  Future<void> _setLocalTier(SubTier tier) async {
    if (_localTier != tier) {
      _localTier = tier;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('local_tier', tier.name);
      notifyListeners();
      debugPrint("👑 Local Tier Updated: ${tier.name}");

      _syncTierToFirebase(tier);
    }
  }

  Future<void> _syncTierToFirebase(SubTier tier) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // 1. Записуємо рівень собі в профіль
      await _firestore.collection('users').doc(user.uid).set({
        'tier': tier.name,
      }, SetOptions(merge: true));

      // 2. Якщо ми АДМІН сім'ї - передаємо цей рівень сім'ї
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final householdId = userDoc.data()?['householdId'];

      if (householdId != null) {
        final householdDoc = await _firestore.collection('households').doc(householdId).get();
        if (householdDoc.exists && householdDoc.data()?['adminId'] == user.uid) {
          await _firestore.collection('households').doc(householdId).set({
            'tier': tier.name, // 'free', 'pro', або 'family'
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      debugPrint("Помилка синхронізації рівня: $e");
    }
  }

  // Helper
  SubTier _stringToTier(String tierStr) {
    if (tierStr == 'family') return SubTier.family;
    if (tierStr == 'pro') return SubTier.pro;
    return SubTier.free;
  }
}