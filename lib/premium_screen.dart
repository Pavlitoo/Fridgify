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

  @override
  void initState() {
    super.initState();
    SubscriptionService().init();
  }

  Future<void> _buy() async {
    setState(() => _isLoading = true);

    if (SubscriptionService().products.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppText.get('err_store')), backgroundColor: Colors.orange),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    try {
      bool launched = await SubscriptionService().buyPremium();
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppText.get('msg_buy_error')), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      // ignore
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SubscriptionService(),
      builder: (context, child) {
        final isPremium = SubscriptionService().isPremium;
        final products = SubscriptionService().products;
        final String priceText = products.isNotEmpty ? products.first.price : "...";

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1E1E2C), Color(0xFF2D2D44)],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  // Кнопка закриття
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 30),
                        onPressed: () => Navigator.pop(context, isPremium),
                      ),
                    ),
                  ),

                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Spacer(flex: 2),

                      // Іконка
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isPremium ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                            isPremium ? Icons.check_circle : Icons.workspace_premium,
                            size: 80,
                            color: isPremium ? Colors.green : Colors.amber
                        ),
                      ),
                      const SizedBox(height: 30),

                      // Заголовок
                      Text(
                        isPremium ? AppText.get('prem_active') : AppText.get('prem_title'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1),
                      ),
                      const SizedBox(height: 15),

                      // Опис
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Text(
                          isPremium ? AppText.get('prem_sub_active') : AppText.get('prem_desc'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.white70, height: 1.5),
                        ),
                      ),

                      const Spacer(flex: 1),

                      // Список переваг (тільки якщо не куплено або для нагадування)
                      if (!isPremium) ...[
                        _benefitRow(Icons.block, AppText.get('ben_1')),
                        _benefitRow(Icons.all_inclusive, AppText.get('ben_2')),
                        _benefitRow(Icons.family_restroom, AppText.get('ben_3')),
                        _benefitRow(Icons.auto_awesome, AppText.get('ben_4')),
                      ],

                      const Spacer(flex: 3),

                      // Кнопки
                      if (isPremium) ...[
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.green.withOpacity(0.3))
                          ),
                          child: Column(
                            children: [
                              Text(AppText.get('prem_congrats'), style: const TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 15),
                              ElevatedButton(
                                onPressed: () => SubscriptionService().openManagementPage(),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white12,
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size(double.infinity, 50),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0
                                ),
                                child: Text(AppText.get('prem_btn_manage')),
                              ),
                            ],
                          ),
                        )
                      ] else ...[
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
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 8,
                              shadowColor: Colors.amber.withOpacity(0.4),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(AppText.get('prem_btn_buy'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                                Text("$priceText / ${AppText.get('u_months')}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.normal)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      const SizedBox(height: 30),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _benefitRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.amber, size: 24),
          const SizedBox(width: 15),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}