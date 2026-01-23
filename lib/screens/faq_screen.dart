import 'package:flutter/material.dart';
import '../translations.dart';
import '../global.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

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
                    icon: Icons.add_circle_outline, color: Colors.green, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q2'),
                    content: AppText.get('faq_a2'),
                    icon: Icons.delete_outline, color: Colors.red, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q3'),
                    content: AppText.get('faq_a3'),
                    icon: Icons.restaurant_menu, color: Colors.orange, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q4'),
                    content: AppText.get('faq_a4'),
                    icon: Icons.language, color: Colors.blue, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q5'),
                    content: AppText.get('faq_a5'),
                    icon: Icons.restore_from_trash, color: Colors.teal, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q6'),
                    content: AppText.get('faq_a6'),
                    icon: Icons.star, color: Colors.amber, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q7'),
                    content: AppText.get('faq_a7'),
                    icon: Icons.support_agent, color: Colors.purple, isDark: isDark
                ),

                const SizedBox(height: 30),
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