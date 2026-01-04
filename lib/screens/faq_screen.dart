import 'package:flutter/material.dart';
import '../translations.dart';
import '../global.dart';

class FAQScreen extends StatelessWidget {
  const FAQScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, lang, child) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(title: Text(AppText.get('faq_title')), centerTitle: true, backgroundColor: Theme.of(context).appBarTheme.backgroundColor),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _FAQItem(
                    title: AppText.get('faq_q1'),
                    content: AppText.get('faq_a1'),
                    icon: Icons.restaurant_menu, color: Colors.green, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q2'),
                    content: AppText.get('faq_a2'),
                    icon: Icons.family_restroom, color: Colors.blue, isDark: isDark
                ),
                _FAQItem(
                    title: AppText.get('faq_q3'),
                    content: AppText.get('faq_a3'),
                    icon: Icons.star, color: Colors.orange, isDark: isDark
                ),
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
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]
      ),
      child: ExpansionTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.2), child: Icon(icon, color: color)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        children: [Padding(padding: const EdgeInsets.all(16.0), child: Text(content, style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700], fontSize: 16, height: 1.5)))],
        shape: Border.all(color: Colors.transparent),
      ),
    );
  }
}