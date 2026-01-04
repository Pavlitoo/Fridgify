import 'package:shared_preferences/shared_preferences.dart';
// import 'package:purchases_flutter/purchases_flutter.dart'; // Розкоментуємо, коли буде Google Play

class SubscriptionService {
  // Сінґлтон (щоб сервіс був один на весь додаток)
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  bool _isPremium = false;

  // Отримання статусу
  bool get isPremium => _isPremium;

  Future<void> init() async {
    // ТУТ БУДЕ REVENUECAT (коли буде ключ)
    // await Purchases.configure(PurchasesConfiguration("ТВІЙ_REVENUECAT_KEY"));

    // Поки що зберігаємо статус локально для тесту
    final prefs = await SharedPreferences.getInstance();
    _isPremium = prefs.getBool('is_premium') ?? false;
  }

  // Імітація покупки (для тестування інтерфейсу)
  Future<bool> buyPremium() async {
    // Тут буде реальна логіка оплати
    await Future.delayed(const Duration(seconds: 2)); // Типу думаємо

    _isPremium = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', true);

    return true; // Успіх
  }

  // Відновити покупки (якщо видалив додаток і поставив знову)
  Future<void> restorePurchases() async {
    _isPremium = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', true);
  }

  // Скинути преміум (для тестів розробника)
  Future<void> debugResetPremium() async {
    _isPremium = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', false);
  }
}