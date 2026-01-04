import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'subscription_service.dart';

class AdService {
  // Це тестові ID від Google.
  // Їх можна безпечно використовувати під час розробки, щоб не заблокували акаунт.
  final String _androidBannerId = 'ca-app-pub-3940256099942544/6300978111';
  final String _iosBannerId = 'ca-app-pub-3940256099942544/2934735716';

  String get bannerAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) return _androidBannerId;
    if (Platform.isIOS) return _iosBannerId;
    return '';
  }

  BannerAd? createBannerAd({required Function() onLoaded}) {
    // 1. Головна перевірка: Якщо у користувача Premium — повертаємо null (реклами не буде)
    if (SubscriptionService().isPremium) return null;

    // 2. Якщо це Веб або Windows (не телефон) — теж без реклами
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return null;

    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          // Повідомляємо інтерфейс, що реклама завантажилась і можна показати блок
          onLoaded();
        },
        onAdFailedToLoad: (ad, error) {
          print('Помилка завантаження реклами: $error');
          ad.dispose();
        },
      ),
    );
  }
}