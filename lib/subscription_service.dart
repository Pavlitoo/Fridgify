import 'dart:async';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionService extends ChangeNotifier {
  // ID твоєї підписки
  static const String _premiumId = 'fridgify_premium_monthly';

  final InAppPurchase _iap = InAppPurchase.instance;
  bool _isPremium = false;
  List<ProductDetails> _products = [];

  // Сінґлтон
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  bool get isPremium => _isPremium;
  List<ProductDetails> get products => _products;

  // --- ІНІЦІАЛІЗАЦІЯ ---
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('is_premium') ?? false;
    notifyListeners();

    final Stream<List<PurchaseDetails>> purchaseUpdated = _iap.purchaseStream;
    purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {}, onError: (error) {
      debugPrint("❌ IAP Stream Error: $error");
    });

    await _loadProducts();

    // 🔥 СУВОРА ПЕРЕВІРКА ПРИ ЗАПУСКУ
    // Це змушує Google перевірити статус. Якщо підписка закінчилася,
    // потік поверне дані, які ми обробимо і вимкнемо преміум.
    await _iap.restorePurchases();
  }

  Future<void> _loadProducts() async {
    final bool available = await _iap.isAvailable();
    if (!available) return;
    const Set<String> ids = {_premiumId};
    final ProductDetailsResponse response = await _iap.queryProductDetails(ids);
    _products = response.productDetails;
    notifyListeners();
  }

  // --- МЕТОД КУПІВЛІ ---
  Future<bool> buyPremium() async {
    if (_products.isEmpty) await _loadProducts();
    if (_products.isEmpty) return false;

    ProductDetails productDetails;
    try {
      productDetails = _products.firstWhere((p) => p.id == _premiumId);
    } catch (e) {
      productDetails = _products.first;
    }

    final PurchaseParam purchaseParam = PurchaseParam(productDetails: productDetails);
    try {
      _iap.buyNonConsumable(purchaseParam: purchaseParam);
      return true;
    } catch (e) {
      return false;
    }
  }

  // --- 👇 ОСЬ ЦЕЙ МЕТОД, ЯКОГО НЕ ВИСТАЧАЛО ---
  Future<void> restorePurchases() async {
    // Цей метод просто запускає процес відновлення.
    // Результат прийде в _listenToPurchaseUpdated через Stream.
    await _iap.restorePurchases();
  }

  // --- ВІДКРИТТЯ GOOGLE PLAY ---
  Future<void> openManagementPage() async {
    final Uri url = Uri.parse("https://play.google.com/store/account/subscriptions?sku=$_premiumId&package=com.pavlo.smart_fridge");
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Error launching URL: $e");
    }
  }

  // --- ОБРОБКА РЕЗУЛЬТАТІВ ВІД GOOGLE ---
  Future<void> _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) async {
    // Починаємо з false (немає преміуму)
    bool isValid = false;

    if (purchaseDetailsList.isEmpty) {
      // Якщо список пустий - точно вимикаємо
      debugPrint("📉 Список покупок пустий -> Вимикаємо Premium");
      await _setPremiumStatus(false);
      return;
    }

    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Очікування...
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          // Помилка...
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // ✅ ЗНАЙШЛИ АКТИВНУ!
          isValid = true;
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _iap.completePurchase(purchaseDetails);
        }
      }
    }

    // Оновлюємо статус (якщо не знайшли активної - вимкнеться)
    await _setPremiumStatus(isValid);
  }

  Future<void> _setPremiumStatus(bool status) async {
    if (_isPremium != status) {
      _isPremium = status;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_premium', status);
      notifyListeners();
      debugPrint("👑 Premium Status Updated: $status");
    }
  }
}