import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart'; // Потрібно для ProductDetails, якщо використовується
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
      // ignore error
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

        // Беремо реальну ціну
        final String priceText = products.isNotEmpty
            ? products.first.price
            : "...";

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
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(context, isPremium),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Icon(
                      isPremium ? Icons.check_circle : Icons.workspace_premium,
                      size: 80,
                      color: isPremium ? Colors.green : Colors.amber
                  ),
                  const SizedBox(height: 20),

                  Text(
                    isPremium ? AppText.get('prem_active') : AppText.get('prem_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isPremium ? AppText.get('prem_sub_active') : AppText.get('prem_desc'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.white70),
                  ),

                  const SizedBox(height: 30),

                  _benefitRow(Icons.all_inclusive, AppText.get('ben_1'), isPremium),
                  _benefitRow(Icons.block, AppText.get('ben_2'), isPremium),
                  _benefitRow(Icons.family_restroom, AppText.get('ben_3'), isPremium),
                  _benefitRow(Icons.high_quality, AppText.get('ben_4'), isPremium),

                  const Spacer(),

                  if (isPremium) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15)
                      ),
                      child: Column(
                        children: [
                          const Text("🎉 You are Premium!", style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          ElevatedButton(
                            onPressed: () => SubscriptionService().openManagementPage(),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white10,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                            ),
                            child: Text(AppText.get('prem_btn_manage')),
                          )
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                          elevation: 10,
                          shadowColor: Colors.amber.withOpacity(0.5),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(AppText.get('prem_btn_buy'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            Text("$priceText / ${AppText.get('u_months')}", style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    TextButton(
                        onPressed: () async {
                          // 👇 ТЕПЕР ЦЕЙ МЕТОД ІСНУЄ І ПОМИЛКИ НЕ БУДЕ
                          await SubscriptionService().restorePurchases();
                        },
                        child: Text(AppText.get('prem_btn_restore'), style: const TextStyle(color: Colors.white54))
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _benefitRow(IconData icon, String text, bool isActive) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: isActive ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)
            ),
            child: Icon(icon, color: isActive ? Colors.green : Colors.amber, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}