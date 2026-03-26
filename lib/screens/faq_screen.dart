import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart'; // 🔥 ДОДАЛИ ІМПОРТ
import '../translations.dart';
import '../global.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  // 🔥 ФУНКЦІЯ ДЛЯ ВІДПРАВКИ ЛИСТА
  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'pasalugovij@gmail.com',
      query: 'subject=Fridgify Support', // Тема листа
    );

    try {
      await launchUrl(emailLaunchUri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint("Не вдалося відкрити пошту: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = isDark ? Colors.white : Colors.black;

    return ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, lang, child) {
          return Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(
                title: Text(AppText.get('faq_title'), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                centerTitle: true,
                backgroundColor: Colors.transparent,
                elevation: 0,
                iconTheme: IconThemeData(color: textColor)
            ),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _FAQItem(
                    title: AppText.get('faq_q1'),
                    content: AppText.get('faq_a1'),
                    icon: Icons.kitchen, color: Colors.green, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q2'),
                    content: AppText.get('faq_a2'),
                    icon: Icons.receipt_long, color: Colors.blue, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q3'),
                    content: AppText.get('faq_a3'),
                    icon: Icons.restaurant_menu, color: Colors.orange, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q4'),
                    content: AppText.get('faq_a4'),
                    icon: Icons.timer_off_outlined, color: Colors.redAccent, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q5'),
                    content: AppText.get('faq_a5'),
                    icon: Icons.restore_from_trash, color: Colors.teal, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q6'),
                    content: AppText.get('faq_a6'),
                    icon: Icons.family_restroom, color: Colors.amber.shade700, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q7'),
                    content: AppText.get('faq_a7'),
                    icon: Icons.share, color: Colors.purple, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q8'),
                    content: AppText.get('faq_a8'),
                    icon: Icons.bar_chart, color: Colors.blueAccent, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q9'),
                    content: AppText.get('faq_a9'),
                    icon: Icons.chat_bubble_outline, color: Colors.indigo, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q10'),
                    content: AppText.get('faq_a10'),
                    icon: Icons.qr_code_scanner, color: Colors.brown, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q11'),
                    content: AppText.get('faq_a11'),
                    icon: Icons.language, color: Colors.lightBlue, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q12'),
                    content: AppText.get('faq_a12'),
                    icon: Icons.cancel_outlined, color: Colors.grey, isDark: isDark
                ),

                const SizedBox(height: 30),

                // 🔥 КНОПКА ТЕХНІЧНОЇ ПІДТРИМКИ
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _launchEmail,
                    icon: const Icon(Icons.email_outlined, color: Colors.white),
                    label: Text(AppText.get('faq_support_btn'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      elevation: 3,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
                Center(
                  child: Text("Version 1.0.0", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                )
              ],
            ),
          );
        }
    );
  }
}

class _FAQItem extends StatelessWidget {
  final String title;
  final String content;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _FAQItem({required this.title, required this.content, required this.icon, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isDark ? Colors.white : Colors.black87)),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 10),
          Text(content, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700], fontSize: 15, height: 1.5))
        ],
        shape: Border.all(color: Colors.transparent),
      ),
    );
  }
}