import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'secrets.dart'; // 👇 Імпортуємо файл з секретами

class AdService {
  Future<void> initialize() async {
    await MobileAds.instance.initialize();
  }

  String get bannerAdUnitId {
    if (kDebugMode) {
      // Тестовий ID залишаємо як є (для розробки)
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'
          : 'ca-app-pub-3940256099942544/2934735716';
    }

    // 👇 А тут беремо з секретного файлу
    return Secrets.adUnitId;
  }

  BannerAd? createBannerAd({required VoidCallback onLoaded}) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          print("✅ Реклама завантажена");
          onLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          print("❌ Помилка реклами: $error");
          ad.dispose();
        },
      ),
    );
  }
}