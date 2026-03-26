import 'package:flutter/material.dart';
import 'subscription_service.dart';
import 'translations.dart';
import 'screens/home_screen.dart';

class PremiumScreen extends StatefulWidget {
  const PremiumScreen({super.key});

  @override
  State<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends State<PremiumScreen> {
  String? _loadingPlanId;

  @override
  void initState() {
    super.initState();
    SubscriptionService().init();
  }

  Future<void> _buy(String planId) async {
    setState(() => _loadingPlanId = planId);

    if (SubscriptionService().products.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppText.get('err_store')), backgroundColor: Colors.orange),
        );
      }
      setState(() => _loadingPlanId = null);
      return;
    }

    try {
      bool launched = await SubscriptionService().buySubscription(planId);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppText.get('msg_buy_error')), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      debugPrint("Buy error: $e");
    } finally {
      if (mounted) setState(() => _loadingPlanId = null);
    }
  }

  String _getPrice(String id, String fallback) {
    try {
      final products = SubscriptionService().products;
      if (products.isEmpty) return fallback;
      return products.firstWhere((p) => p.id == id).price;
    } catch (e) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SubscriptionService(),
      builder: (context, child) {
        final currentTier = SubscriptionService().currentTier;

        final String proPrice = _getPrice('premium_pro_monthly', "2.99 \$");
        final String familyPrice = _getPrice('family_max_monthly', "4.99 \$");

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
                  // 1. СПОЧАТКУ ЙДЕ СКРОЛ (щоб він був під хрестиком)
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        const Icon(Icons.workspace_premium_rounded, size: 80, color: Colors.amber),
                        const SizedBox(height: 20),
                        Text(
                          currentTier == SubTier.free ? AppText.get('prem_choose_plan') : AppText.get('prem_your_sub'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          AppText.get('prem_subtitle'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                        const SizedBox(height: 40),

                        // --- КАРТКА PREMIUM PRO ---
                        _buildPlanCard(
                          title: "Premium PRO",
                          priceText: "$proPrice ${AppText.get('prem_per_month')}",
                          color: Colors.blueAccent,
                          icon: Icons.person_rounded,
                          features: [
                            AppText.get('ben_1'),
                            AppText.get('ben_2'),
                            AppText.get('prem_pro_ben_3'),
                          ],
                          buttonText: _getProButtonText(currentTier),
                          isButtonDisabled: currentTier == SubTier.pro || currentTier == SubTier.family,
                          isLoading: _loadingPlanId == 'premium_pro_monthly',
                          onTap: () => _buy('premium_pro_monthly'),
                        ),

                        const SizedBox(height: 25),

                        // --- КАРТКА FAMILY MAX ---
                        _buildPlanCard(
                          title: "Family MAX",
                          priceText: "$familyPrice ${AppText.get('prem_per_month')}",
                          color: Colors.amber,
                          icon: Icons.family_restroom_rounded,
                          isBestValue: true,
                          features: [
                            AppText.get('prem_fam_ben_1'),
                            AppText.get('prem_fam_ben_2'),
                            AppText.get('prem_fam_ben_3'),
                            AppText.get('prem_fam_ben_4'),
                            AppText.get('prem_fam_ben_5'), // Сканер чеків
                          ],
                          buttonText: _getFamilyButtonText(currentTier),
                          isButtonDisabled: currentTier == SubTier.family,
                          isLoading: _loadingPlanId == 'family_max_monthly',
                          onTap: () => _buy('family_max_monthly'),
                        ),

                        const SizedBox(height: 40),

                        // Кнопки відновлення та керування
                        if (currentTier != SubTier.free)
                          ElevatedButton.icon(
                            onPressed: () => SubscriptionService().openManagementPage(),
                            icon: const Icon(Icons.settings, color: Colors.white),
                            label: Text(AppText.get('prem_btn_manage'), style: const TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white12,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),

                        TextButton(
                          onPressed: () => SubscriptionService().restorePurchases(),
                          child: Text(AppText.get('prem_btn_restore'), style: const TextStyle(color: Colors.white54, decoration: TextDecoration.underline)),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),

                  // 2. А ТЕПЕР ЙДЕ ХРЕСТИК (тепер він лежить поверх усього екрану і точно клікнеться!)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70, size: 30),
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context, currentTier != SubTier.free);
                          } else {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(builder: (context) => const HomeScreen()),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getProButtonText(SubTier tier) {
    if (tier == SubTier.family) return AppText.get('prem_btn_included');
    if (tier == SubTier.pro) return AppText.get('prem_active');
    return AppText.get('prem_btn_choose_pro');
  }

  String _getFamilyButtonText(SubTier tier) {
    if (tier == SubTier.family) return AppText.get('prem_active');
    if (tier == SubTier.pro) return AppText.get('prem_btn_upgrade_fam');
    return AppText.get('prem_btn_choose_fam');
  }

  Widget _buildPlanCard({
    required String title,
    required String priceText,
    required Color color,
    required IconData icon,
    required List<String> features,
    required String buttonText,
    required bool isButtonDisabled,
    required bool isLoading,
    required VoidCallback onTap,
    bool isBestValue = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(isButtonDisabled ? 0.3 : 0.8), width: 2),
        boxShadow: isButtonDisabled ? [] : [
          BoxShadow(color: color.withOpacity(0.15), blurRadius: 20, spreadRadius: 2)
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (isBestValue)
            Positioned(
              top: -12,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8)],
                ),
                child: Text(AppText.get('prem_badge_best'), style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: color.withOpacity(0.2), shape: BoxShape.circle),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          Text(priceText, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Divider(color: Colors.white24, height: 1),
                ),
                ...features.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_outline, color: color, size: 20),
                      const SizedBox(width: 12),
                      Expanded(child: Text(f, style: const TextStyle(color: Colors.white70, fontSize: 15, height: 1.3))),
                    ],
                  ),
                )),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: isButtonDisabled || isLoading ? null : onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: isBestValue ? Colors.black : Colors.white,
                      disabledBackgroundColor: Colors.white12,
                      disabledForegroundColor: Colors.white54,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: isLoading
                        ? SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: isBestValue ? Colors.black : Colors.white, strokeWidth: 2))
                        : Text(buttonText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}