import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Для роботи з датами
import 'subscription_service.dart';
import 'premium_screen.dart'; // Щоб відкривати екран преміуму з діалогу

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;

  // 👇 ТВОЇ РЕАЛЬНІ ID
  final String _realBannerId = 'ca-app-pub-9946334990188142/1828107398';
  final String _realInterstitialId = 'ca-app-pub-9946334990188142/5585026173';

  // 👇 ТЕСТОВІ ID
  final String _testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  final String _testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';

  String get bannerAdUnitId {
    if (kReleaseMode) return _realBannerId;
    return Platform.isAndroid ? _testBannerId : 'ca-app-pub-3940256099942544/2934735716';
  }

  String get interstitialAdUnitId {
    if (kReleaseMode) return _realInterstitialId;
    return Platform.isAndroid ? _testInterstitialId : 'ca-app-pub-3940256099942544/4411468910';
  }

  Future<void> init() async {
    await MobileAds.instance.initialize();
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    if (SubscriptionService().isPremium) return;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
          debugPrint("✅ Відео-реклама готова");
        },
        onAdFailedToLoad: (error) {
          debugPrint("❌ Помилка завантаження реклами: $error");
          _isAdLoaded = false;
        },
      ),
    );
  }

  // --- 🔥 ГОЛОВНА ЛОГІКА З FIREBASE ---

  // 1. Отримуємо поточний лічильник з бази
  Future<int> _getDailySearchCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('usage').doc('daily_limit');

    try {
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data()!;
        // Якщо дата в базі співпадає з сьогоднішньою - повертаємо count
        if (data['date'] == todayStr) {
          return data['count'] ?? 0;
        }
      }
      // Якщо документа немає або дата стара (вчорашня) - повертаємо 0
      return 0;
    } catch (e) {
      debugPrint("Error reading limit: $e");
      return 0;
    }
  }

  // 2. Оновлюємо лічильник (+1)
  Future<void> _incrementSearchCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('usage').doc('daily_limit');

    try {
      final doc = await docRef.get();
      int currentCount = 0;
      if (doc.exists && doc.data()!['date'] == todayStr) {
        currentCount = doc.data()!['count'] ?? 0;
      }

      // Записуємо нове значення
      await docRef.set({
        'date': todayStr,
        'count': currentCount + 1
      });
    } catch (e) {
      debugPrint("Error updating limit: $e");
    }
  }

  // 3. Основна функція перевірки (викликається з кнопки)
  Future<bool> checkAndShowAd(BuildContext context) async {
    // 1. Якщо Premium - пропускаємо миттєво
    if (SubscriptionService().isPremium) return true;

    // 2. Читаємо з бази, скільки разів юзер вже шукав СЬОГОДНІ
    int searchCount = await _getDailySearchCount();
    debugPrint("🔎 Юзер шукав сьогодні: $searchCount разів");

    // 3. БЛОКУВАННЯ: Якщо 10 або більше запитів (0..9 = 10 разів)
    if (searchCount >= 10) {
      _showLimitDialog(context);
      return false; // Блокуємо пошук
    }

    // 4. ЛОГІКА РЕКЛАМИ:
    // 0, 1, 2 (1-й, 2-й, 3-й запити) -> Без реклами
    // 3 і більше (4-й...10-й) -> Реклама

    if (searchCount >= 3) {
      // Треба показати рекламу
      if (_isAdLoaded && _interstitialAd != null) {
        debugPrint("🎬 Запуск відео-реклами (запит №${searchCount + 1})...");
        final completer = Completer<bool>();

        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) async {
            ad.dispose();
            _loadInterstitialAd(); // Вантажимо наступну
            // Збільшуємо лічильник тільки після перегляду
            await _incrementSearchCount();
            completer.complete(true); // Дозволяємо йти далі
          },
          onAdFailedToShowFullScreenContent: (ad, err) async {
            ad.dispose();
            _loadInterstitialAd();
            // Якщо помилка показу, все одно зараховуємо і пускаємо
            await _incrementSearchCount();
            completer.complete(true);
          },
        );

        _interstitialAd!.show();
        return completer.future; // Чекаємо закриття реклами
      } else {
        // Реклама не завантажилась - пускаємо, але лічильник крутимо
        debugPrint("⚠️ Реклама не готова, пропускаємо.");
        _loadInterstitialAd();
        await _incrementSearchCount();
        return true;
      }
    }

    // Якщо це 1-й, 2-й або 3-й запит (searchCount < 3) - просто збільшуємо лічильник і пускаємо
    await _incrementSearchCount();
    return true;
  }

  void _showLimitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Ліміт на сьогодні 🛑"),
        content: const Text("Ви використали 10 безкоштовних пошуків.\nЩоб готувати без обмежень, перейдіть на Premium!"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
            },
            child: const Text("Premium"),
          )
        ],
      ),
    );
  }
}