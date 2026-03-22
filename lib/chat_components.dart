import 'package:flutter/material.dart';
import '../translations.dart';

class ChatComponents {
  // --- 1. ІНДИКАТОР ПРОГРЕСУ (iOS Style Pill) ---
  static Widget buildUploadProgress(double? progress, bool isDark, Color textColor) {
    return Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey.shade900 : Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
            children: [
              SizedBox(width: 24, height: 24, child: CircularProgressIndicator(value: progress, strokeWidth: 3, color: Colors.green)),
              const SizedBox(width: 16),
              Expanded(child: Text(AppText.get('chat_uploading'), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14))),
              Text("${((progress ?? 0) * 100).toInt()}%", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14)),
            ]
        )
    );
  }

  // --- 2. ПЛАШКА ЗАКРІПЛЕНИХ ПОВІДОМЛЕНЬ ---
  static Widget buildPinnedMessageBar({ required BuildContext context, required List<Map<String, dynamic>> pinnedMessages, required int currentIndex, required Function(Map<String, dynamic>) onUnpin, required VoidCallback onTap, required Color textColor }) {
    if (pinnedMessages.isEmpty) return const SizedBox.shrink();
    int safeIndex = currentIndex >= 0 && currentIndex < pinnedMessages.length ? currentIndex : pinnedMessages.length - 1;
    final activePin = pinnedMessages[safeIndex]; final int count = pinnedMessages.length; final int displayNum = safeIndex + 1;
    return GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Theme.of(context).cardColor, border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)))),
          child: Row(
              children: [
                Container(width: 3, height: 36, decoration: BoxDecoration(color: const Color(0xFF00897B), borderRadius: BorderRadius.circular(2))), const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Text(AppText.get('chat_pinned'), style: const TextStyle(color: Color(0xFF00897B), fontSize: 13, fontWeight: FontWeight.bold)), if (count > 1) Padding(padding: const EdgeInsets.only(left: 6), child: Text("($displayNum/$count)", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)))]), Text("${activePin['senderName']}: ${activePin['text']}", maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontSize: 14))])),
                IconButton(icon: const Icon(Icons.close, color: Colors.grey, size: 22), onPressed: () => onUnpin(activePin), padding: EdgeInsets.zero, constraints: const BoxConstraints())
              ]
          )
      ),
    );
  }

  // --- 3. СУЧАСНЕ МЕНЮ НАЛАШТУВАНЬ ЧАТУ ---
  static void showChatMenu({ required BuildContext context, required VoidCallback onChangeBackground, required VoidCallback onClearBackground, required bool hasBackground, required VoidCallback onChangeColor, required VoidCallback onChangeFont, required bool showMediaOnly, required VoidCallback onToggleMediaOnly, required VoidCallback onShowStats, required VoidCallback onClearHistory }) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(margin: const EdgeInsets.only(top: 12, bottom: 8), width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10))),
            _buildMenuItem(Icons.wallpaper, Colors.blue, AppText.get('chat_change_bg'), () { Navigator.pop(ctx); onChangeBackground(); }), if (hasBackground) _buildMenuItem(Icons.layers_clear, Colors.red, AppText.get('chat_remove_bg'), () { Navigator.pop(ctx); onClearBackground(); }), const Divider(height: 1),
            _buildMenuItem(Icons.color_lens, Colors.purple, AppText.get('chat_color'), () { Navigator.pop(ctx); onChangeColor(); }), _buildMenuItem(Icons.format_size, Colors.orange, AppText.get('chat_font_size'), () { Navigator.pop(ctx); onChangeFont(); }), const Divider(height: 1),
            _buildMenuItem(showMediaOnly ? Icons.check_box : Icons.check_box_outline_blank, Colors.green, AppText.get('chat_media_only'), () { Navigator.pop(ctx); onToggleMediaOnly(); }), _buildMenuItem(Icons.bar_chart, Colors.indigo, AppText.get('chat_stats'), () { Navigator.pop(ctx); onShowStats(); }), const Divider(height: 1),
            _buildMenuItem(Icons.delete_forever, Colors.red, AppText.get('chat_clear_history'), () { Navigator.pop(ctx); onClearHistory(); }, isDestructive: true), const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
  static Widget _buildMenuItem(IconData icon, Color color, String title, VoidCallback onTap, {bool isDestructive = false}) { return ListTile(leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)), title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: isDestructive ? Colors.red : null)), onTap: onTap); }

  // --- 4. ПРОФЕСІЙНЕ СТВОРЕННЯ ОПИТУВАННЯ ---
  static void showCreatePollSheet(BuildContext context, Function(String, List<String>) onSend) {
    final TextEditingController questionCtrl = TextEditingController(); final List<TextEditingController> optionsCtrls = [TextEditingController(), TextEditingController()];
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) { return StatefulBuilder(builder: (context, setModalState) { final isDark = Theme.of(context).brightness == Brightness.dark; return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom), child: Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28))), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)))), const SizedBox(height: 20), Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.poll, color: Colors.orange)), const SizedBox(width: 12), Text(AppText.get('poll_create'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]), const SizedBox(height: 24), TextField(controller: questionCtrl, maxLines: 2, minLines: 1, decoration: InputDecoration(labelText: AppText.get('poll_question_hint'), filled: true, fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))), const SizedBox(height: 16), Text(AppText.get('poll_option'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(height: 8), ...List.generate(optionsCtrls.length, (index) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(children: [Expanded(child: TextField(controller: optionsCtrls[index], decoration: InputDecoration(hintText: "${AppText.get('chat_option_text')} ${index + 1}", filled: true, fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)))), if (optionsCtrls.length > 2) IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => setModalState(() => optionsCtrls.removeAt(index)))]))), if (optionsCtrls.length < 10) TextButton.icon(onPressed: () => setModalState(() => optionsCtrls.add(TextEditingController())), icon: const Icon(Icons.add_circle, color: Color(0xFF00897B)), label: Text(AppText.get('poll_add_option'), style: const TextStyle(color: Color(0xFF00897B), fontWeight: FontWeight.bold))), const SizedBox(height: 24), SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00897B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 16)), onPressed: () { final question = questionCtrl.text.trim(); final options = optionsCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList(); if (question.isEmpty || options.length < 2) { ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppText.get('err_fill_all')))); return; } Navigator.pop(ctx); onSend(question, options); }, child: Text(AppText.get('poll_send'), style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold))))]))); }); });
  }

  // --- 5. СТАТИСТИКА ЧАТУ ---
  static void showChatStats({ required BuildContext context, required int total, required int texts, required int photos, required int voices, required int files }) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (ctx) => Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(28)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, -5))]), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)))), const SizedBox(height: 20), Text(AppText.get('chat_stats'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 24), Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF00897B), Color(0xFF004D40)]), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(AppText.get('chat_stats_total'), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)), Text("$total", style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold))])), const SizedBox(height: 20), GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 16, crossAxisSpacing: 16, childAspectRatio: 2.5, children: [_buildStatCard(AppText.get('chat_stats_text'), "$texts", Icons.short_text, Colors.blue), _buildStatCard(AppText.get('chat_stats_photo'), "$photos", Icons.image, Colors.purple), _buildStatCard(AppText.get('chat_stats_voice'), "$voices", Icons.mic, Colors.orange), _buildStatCard(AppText.get('chat_stats_file'), "$files", Icons.insert_drive_file, Colors.red)]), const SizedBox(height: 30), SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00897B), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(vertical: 16)), onPressed: () => Navigator.pop(ctx), child: Text(AppText.get('chat_stats_ok'), style: const TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)))), const SizedBox(height: 10)])));
  }

  // 🔥 ФІКС ЖОВТИХ СМУГ: Додано Expanded та TextOverflow.ellipsis
  static Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.3))),
        child: Row(
            children: [
              CircleAvatar(backgroundColor: color.withValues(alpha: 0.2), radius: 18, child: Icon(icon, color: color, size: 20)),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(count, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                        Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis)
                      ]
                  )
              )
            ]
        )
    );
  }
}