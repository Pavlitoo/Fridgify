import 'package:flutter/material.dart';
import '../translations.dart';
import '../global.dart';

class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, lang, child) {
          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(
                title: Text(AppText.get('faq_title')),
                centerTitle: true,
                backgroundColor: Theme.of(context).appBarTheme.backgroundColor
            ),
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 1. Додавання
                _FAQItem(
                    title: AppText.get('faq_q1'),
                    content: AppText.get('faq_a1'),
                    icon: Icons.add_circle_outline, color: Colors.green, isDark: isDark
                ),
                // 2. Рецепти
                _FAQItem(
                    title: AppText.get('faq_q2'),
                    content: AppText.get('faq_a2'),
                    icon: Icons.restaurant_menu, color: Colors.orange, isDark: isDark
                ),
                // 3. Список покупок
                _FAQItem(
                    title: AppText.get('faq_q3'),
                    content: AppText.get('faq_a3'),
                    icon: Icons.shopping_cart, color: Colors.blue, isDark: isDark
                ),
                // 4. Сім'я
                _FAQItem(
                    title: AppText.get('faq_q4'),
                    content: AppText.get('faq_a4'),
                    icon: Icons.family_restroom, color: Colors.purple, isDark: isDark
                ),
                // 5. Смітник
                _FAQItem(
                    title: AppText.get('faq_q5'),
                    content: AppText.get('faq_a5'),
                    icon: Icons.delete_outline, color: Colors.red, isDark: isDark
                ),
                // 6. Premium
                _FAQItem(
                    title: AppText.get('faq_q6'),
                    content: AppText.get('faq_a6'),
                    icon: Icons.star, color: Colors.amber, isDark: isDark
                ),
                // 7. Скасування підписки
                _FAQItem(
                    title: AppText.get('faq_q7'),
                    content: AppText.get('faq_a7'),
                    icon: Icons.credit_card_off, color: Colors.grey, isDark: isDark
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
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(icon, color: color)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
        children: [Padding(padding: const EdgeInsets.all(16.0), child: Text(content, style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700], fontSize: 16, height: 1.5)))],
        shape: Border.all(color: Colors.transparent),
      ),
    );
  }
}