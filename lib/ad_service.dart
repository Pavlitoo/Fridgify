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
import 'translations.dart';
import 'secrets.dart';

class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  InterstitialAd? _interstitialAd;
  bool _isAdLoaded = false;

  // ===========================================================================
  // 🆔 ОТРИМАННЯ ID РЕКЛАМИ
  // ===========================================================================

  String get bannerAdUnitId {
    if (kReleaseMode) {
      return Secrets.bannerAdUnitId;
    }
    return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/6300978111'
        : 'ca-app-pub-3940256099942544/2934735716';
  }

  String get interstitialAdUnitId {
    if (kReleaseMode) {
      return Secrets.interstitialAdUnitId;
    }
    return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/1033173712'
        : 'ca-app-pub-3940256099942544/4411468910';
  }

  // ===========================================================================
  // ⚙️ ІНІЦІАЛІЗАЦІЯ
  // ===========================================================================

  Future<void> init() async {
    await MobileAds.instance.initialize();
    _loadInterstitialAd();
  }

  void _loadInterstitialAd() {
    // 🔥 ВИПРАВЛЕНО: Використовуємо hasProOrHigher
    if (SubscriptionService().hasProOrHigher) return;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
          debugPrint("✅ Відео-реклама готова до показу");

          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _loadInterstitialAd();
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              _loadInterstitialAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint("❌ Помилка завантаження реклами: $error");
          _isAdLoaded = false;
        },
      ),
    );
  }

  // ===========================================================================
  // 🔥 ЛОГІКА ЛІМІТІВ (FIREBASE)
  // ===========================================================================

  Future<int> _getDailySearchCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('usage')
        .doc('daily_limit');

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
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('usage')
        .doc('daily_limit');

    try {
      final doc = await docRef.get();
      int currentCount = 0;

      if (doc.exists && doc.data() != null && doc.data()!['date'] == todayStr) {
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

  // ===========================================================================
  // 🎬 ГОЛОВНИЙ МЕТОД: ПЕРЕВІРКА ТА ПОКАЗ
  // ===========================================================================

  Future<bool> checkAndShowAd(BuildContext context) async {
    // 🔥 ВИПРАВЛЕНО: Використовуємо hasProOrHigher
    if (SubscriptionService().hasProOrHigher) return true;

    int searchCount = await _getDailySearchCount();
    debugPrint("🔎 Юзер шукав сьогодні: $searchCount разів");

    // 🔥 ВИПРАВЛЕНО: Перевірка context.mounted після await
    if (searchCount >= 10) {
      if (context.mounted) {
        _showLimitDialog(context);
      }
      return false;
    }

    if (searchCount >= 3) {
      if (_isAdLoaded && _interstitialAd != null) {
        debugPrint("🎬 Запуск відео-реклами...");
        await _interstitialAd!.show();
        _interstitialAd = null;
        _isAdLoaded = false;
        await _incrementSearchCount();
        return true;
      } else {
        debugPrint("⚠️ Реклама не готова, пропускаємо, але лічильник крутимо.");
        _loadInterstitialAd();
        await _incrementSearchCount();
        return true;
      }
    }

    await _incrementSearchCount();
    return true;
  }

  // ===========================================================================
  // 💬 ДІАЛОГ ПРО ЛІМІТ
  // ===========================================================================
  void _showLimitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(ctx).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Expanded(
                child: Text(
                    AppText.get('limit_title'),
                    style: const TextStyle(fontWeight: FontWeight.bold)
                )
            ),
            const SizedBox(width: 10),
            const Icon(Icons.front_hand, color: Colors.red),
          ],
        ),
        content: Text(
          AppText.get('limit_content'),
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppText.get('btn_ok')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PremiumScreen())
              );
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black
            ),
            child: Text(AppText.get('btn_premium')),
          )
        ],
      ),
    );
  }
}