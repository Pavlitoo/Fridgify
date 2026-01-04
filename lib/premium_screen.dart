import 'package:flutter/material.dart';
import 'subscription_service.dart';
import 'translations.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  bool _isLoading = false;

  Future<void> _buy() async {
    setState(() => _isLoading = true);
    try {
      bool success = await SubscriptionService().buyPremium();
      if (success && mounted) {
        Navigator.pop(context, true); // Повертаємо true, що купили
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Вітаємо в Premium клубі! 🌟"), backgroundColor: Colors.amber));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Помилка оплати"), backgroundColor: Colors.red));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1E2C), Color(0xFF2D2D44)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Кнопка закрити
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(height: 20),

              // Іконка корони
              const Icon(Icons.workspace_premium, size: 80, color: Colors.amber),
              const SizedBox(height: 20),

              const Text(
                "Fridgify Premium",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              const Text(
                "Розблокуй повний потенціал!",
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),

              const SizedBox(height: 40),

              // Список переваг
              _benefitRow(Icons.all_inclusive, "Безлімітний пошук рецептів"),
              _benefitRow(Icons.block, "Ніякої реклами"),
              _benefitRow(Icons.family_restroom, "Доступ до 'Сім'ї'"),
              _benefitRow(Icons.high_quality, "Найрозумніша модель ШІ"),

              const Spacer(),

              // Кнопка купити
              _isLoading
                  ? const CircularProgressIndicator(color: Colors.amber)
                  : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: ElevatedButton(
                  onPressed: _buy,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 60),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 10,
                    shadowColor: Colors.amber.withOpacity(0.5),
                  ),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Отримати Premium", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text("1.99\$ / місяць", style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 15),

              TextButton(
                  onPressed: () async {
                    await SubscriptionService().restorePurchases();
                    Navigator.pop(context);
                  },
                  child: const Text("Відновити покупки", style: TextStyle(color: Colors.white54))
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _benefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.amber, size: 24),
          ),
          const SizedBox(width: 15),
          Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}