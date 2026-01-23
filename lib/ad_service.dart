import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'subscription_service.dart';
import 'premium_screen.dart';
import 'translations.dart'; // ✅ Імпорт перекладів
import 'secrets.dart'; // ✅ Імпорт секретів (твоїх ID)

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;

  // 👇 Беремо ID з secrets.dart або використовуємо тестові
  String get bannerAdUnitId {
    if (kReleaseMode) {
      // Тут можеш додати Secrets.bannerAdUnitId, якщо він там є
      return 'ca-app-pub-9946334990188142/1828107398';
    }
    return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/6300978111'
        : 'ca-app-pub-3940256099942544/2934735716';
  }

  String get interstitialAdUnitId {
    if (kReleaseMode) {
      // Тут можеш додати Secrets.interstitialAdUnitId, якщо він там є
      return 'ca-app-pub-9946334990188142/5585026173';
    }
    return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/1033173712'
        : 'ca-app-pub-3940256099942544/4411468910';
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

  // --- 🔥 ЛОГІКА ЛІМІТІВ (FIREBASE) ---

  Future<int> _getDailySearchCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('usage').doc('daily_limit');

    try {
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data()!;
        if (data['date'] == todayStr) {
          return data['count'] ?? 0;
        }
      }
      return 0;
    } catch (e) {
      debugPrint("Error reading limit: $e");
      return 0;
    }
  }

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

      await docRef.set({
        'date': todayStr,
        'count': currentCount + 1
      });
    } catch (e) {
      debugPrint("Error updating limit: $e");
    }
  }

  Future<bool> checkAndShowAd(BuildContext context) async {
    if (SubscriptionService().isPremium) return true;

    int searchCount = await _getDailySearchCount();
    debugPrint("🔎 Юзер шукав сьогодні: $searchCount разів");

    // Блокування після 10 спроб
    if (searchCount >= 10) {
      _showLimitDialog(context); // 🔥 Тепер показує перекладений діалог
      return false;
    }

    // Реклама з 4-го запиту (індекс 3)
    if (searchCount >= 3) {
      if (_isAdLoaded && _interstitialAd != null) {
        debugPrint("🎬 Запуск відео-реклами...");
        final completer = Completer<bool>();

        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) async {
            ad.dispose();
            _loadInterstitialAd();
            await _incrementSearchCount();
            completer.complete(true);
          },
          onAdFailedToShowFullScreenContent: (ad, err) async {
            ad.dispose();
            _loadInterstitialAd();
            await _incrementSearchCount();
            completer.complete(true);
          },
        );

        _interstitialAd!.show();
        return completer.future;
      } else {
        debugPrint("⚠️ Реклама не готова, пропускаємо.");
        _loadInterstitialAd();
        await _incrementSearchCount();
        return true;
      }
    }

    await _incrementSearchCount();
    return true;
  }

  // 🔥 ОНОВЛЕНИЙ ДІАЛОГ З ПЕРЕКЛАДАМИ
  void _showLimitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Expanded(child: Text(AppText.get('limit_title'), style: const TextStyle(fontWeight: FontWeight.bold))), // ✅ Переклад
            const SizedBox(width: 10),
            const Icon(Icons.front_hand, color: Colors.red),
          ],
        ),
        content: Text(
          AppText.get('limit_content'), // ✅ Переклад
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppText.get('btn_ok')), // ✅ Переклад
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
            child: Text(AppText.get('btn_premium')), // ✅ Переклад
          )
        ],
      ),
    );
  }
}