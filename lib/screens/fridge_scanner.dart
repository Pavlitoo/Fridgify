import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../ai_service.dart';
import '../translations.dart';
import '../utils/snackbar_utils.dart';

class FridgeScanner {

  static Future<void> startScan(BuildContext context, CollectionReference collection, String userLang) async {
    final picker = ImagePicker();

    // 1. ІДЕАЛЬНИЙ ДИЗАЙН ВИБОРУ ДЖЕРЕЛА (Камера / Галерея)
    final ImageSource? source = await showDialog<ImageSource>(
        context: context,
        builder: (ctx) {
          final textColor = Theme.of(context).textTheme.bodyLarge?.color;

          return Dialog(
            backgroundColor: Theme.of(context).cardColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Верхня іконка-логотип
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.document_scanner_rounded, color: Colors.blue, size: 36),
                  ),
                  const SizedBox(height: 16),

                  // Заголовок
                  Text(
                      AppText.get('scan_title'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: textColor)
                  ),
                  const SizedBox(height: 24),

                  // Дві великі кнопки пліч-о-пліч
                  Row(
                    children: [
                      _buildOptionBtn(
                          context,
                          text: AppText.get('scan_camera'),
                          icon: Icons.camera_alt_rounded,
                          color: Colors.blue,
                          source: ImageSource.camera
                      ),
                      const SizedBox(width: 16),
                      _buildOptionBtn(
                          context,
                          text: AppText.get('scan_gallery'),
                          icon: Icons.photo_library_rounded,
                          color: Colors.purple,
                          source: ImageSource.gallery
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          );
        }
    );

    if (source == null) return;

    final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
    if (image == null) return;

    // 2. Красивий Лоадер аналізу
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                child: const CircularProgressIndicator(color: Colors.blue, strokeWidth: 4),
              ),
              const SizedBox(height: 24),
              Text(
                AppText.get('scan_analyzing'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // 3. Відправляємо на сервер
      final List<Map<String, dynamic>> items = await AiRecipeService().analyzeFridgeImage(
        imageFile: File(image.path),
        userLanguage: userLang,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Закриваємо лоадер

      if (items.isEmpty) {
        SnackbarUtils.showWarning(context, AppText.get('scan_not_found'));
        return;
      }

      // 4. Показуємо результати
      _showConfirmationSheet(context, collection, items);

    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        SnackbarUtils.showError(context, "${AppText.get('scan_error')} $e");
      }
    }
  }

  // 🔥 ДОПОМІЖНИЙ ВІДЖЕТ ДЛЯ КНОПОК ВИБОРУ ФОТО
  static Widget _buildOptionBtn(BuildContext context, {required String text, required IconData icon, required Color color, required ImageSource source}) {
    return Expanded(
      child: Material(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () => Navigator.pop(context, source),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 40, color: color),
                const SizedBox(height: 12),
                Text(
                    text,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void _showConfirmationSheet(BuildContext context, CollectionReference collection, List<Map<String, dynamic>> items) {
    List<Map<String, dynamic>> confirmedItems = List.from(items);

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) {
          return StatefulBuilder(builder: (context, setModalState) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            final textColor = Theme.of(context).textTheme.bodyLarge?.color;

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.only(top: 20, left: 16, right: 16),
              child: Column(
                children: [
                  Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10))),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.blue, size: 28),
                      const SizedBox(width: 10),
                      Text("${AppText.get('scan_found')}: ${confirmedItems.length}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(AppText.get('scan_remove_extra'), style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),

                  Expanded(
                    child: confirmedItems.isEmpty
                        ? Center(child: Text(AppText.get('scan_no_items'), style: const TextStyle(fontSize: 16, color: Colors.grey)))
                        : ListView.builder(
                      itemCount: confirmedItems.length,
                      itemBuilder: (context, index) {
                        final item = confirmedItems[index];
                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          color: Theme.of(context).cardColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.check, color: Colors.blue, size: 20),
                            ),
                            title: Text(item['name'], style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            subtitle: Text("${item['quantity']} ${AppText.get('u_${item['unit']}') ?? item['unit']}", style: const TextStyle(color: Colors.grey)),
                            trailing: IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                setModalState(() {
                                  confirmedItems.removeAt(index);
                                });
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.only(bottom: 30, top: 10),
                    child: ElevatedButton.icon(
                      onPressed: confirmedItems.isEmpty ? null : () async {
                        Navigator.pop(ctx);
                        showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

                        try {
                          final batch = FirebaseFirestore.instance.batch();
                          final defaultExpiration = DateTime.now().add(const Duration(days: 7));

                          for (var item in confirmedItems) {
                            final docRef = collection.doc();
                            batch.set(docRef, {
                              'name': item['name'],
                              'quantity': item['quantity'],
                              'unit': item['unit'],
                              'category': item['category'] ?? 'other',
                              'expirationDate': Timestamp.fromDate(defaultExpiration),
                              'isBought': false,
                              'addedDate': Timestamp.now(),
                            });
                          }
                          await batch.commit();

                          if (context.mounted) {
                            Navigator.pop(context);
                            SnackbarUtils.showSuccess(context, AppText.get('scan_success'));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context);
                            SnackbarUtils.showError(context, "${AppText.get('scan_error')} $e");
                          }
                        }
                      },
                      icon: const Icon(Icons.kitchen, color: Colors.white),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                      ),
                      label: Text(AppText.get('scan_save_all'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  )
                ],
              ),
            );
          });
        }
    );
  }
}