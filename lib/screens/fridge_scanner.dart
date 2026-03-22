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

    // 1. ВИБІР ДЖЕРЕЛА (Камера / Галерея)
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.document_scanner_rounded, color: Colors.blue, size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(
                      AppText.get('scan_title'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: textColor)
                  ),
                  const SizedBox(height: 24),
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

    if (!context.mounted) return;

    // 2. КРАСИВИЙ АНІМОВАНИЙ ЛОАДЕР СКАНЕРА
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ScanningLoader(imageFile: File(image.path)),
    );

    try {
      // 3. Відправляємо на сервер
      final List<Map<String, dynamic>> items = await AiRecipeService().analyzeFridgeImage(
        imageFile: File(image.path),
        userLanguage: userLang,
      );

      if (!context.mounted) return;

      // Закриваємо красивий лоадер сканера
      Navigator.of(context, rootNavigator: true).pop();

      if (items.isEmpty) {
        SnackbarUtils.showWarning(context, AppText.get('scan_not_found'));
        return;
      }

      // 4. Показуємо результати
      _showConfirmationSheet(context, collection, items);

    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Закриваємо лоадер у разі помилки
        SnackbarUtils.showError(context, "${AppText.get('scan_error')} $e");
      }
    }
  }

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
          return StatefulBuilder(builder: (sheetContext, setModalState) {
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
                        // 1. Спочатку закриваємо BottomSheet
                        Navigator.pop(ctx);

                        // 2. Показуємо лоадер збереження (ЗІ СВОЇМ ВЛАСНИМ КОНТЕКСТОМ)
                        showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (dialogCtx) => const Center(child: CircularProgressIndicator())
                        );

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
                            // 3. ФІКС ВІЧНОГО СПІНЕРА: закриваємо найвищий діалог надійно
                            Navigator.of(context, rootNavigator: true).pop();
                            SnackbarUtils.showSuccess(context, AppText.get('scan_success'));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.of(context, rootNavigator: true).pop();
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

// ============================================================================
// 🔥 НОВИЙ ВІДЖЕТ АНІМОВАНОГО СКАНЕРА
// ============================================================================
class _ScanningLoader extends StatefulWidget {
  final File imageFile;

  const _ScanningLoader({required this.imageFile});

  @override
  State<_ScanningLoader> createState() => _ScanningLoaderState();
}

class _ScanningLoaderState extends State<_ScanningLoader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Анімація триває 2 секунди вниз, і 2 секунди вгору (reverse)
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Блок з картинкою та лазером
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: 280,
              height: 380,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Оригінальне фото
                  Image.file(widget.imageFile, fit: BoxFit.cover),

                  // Легке затемнення, щоб лазер виглядав яскравіше
                  Container(color: Colors.black.withOpacity(0.3)),

                  // Лазер, що рухається
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Positioned(
                        top: _controller.value * 350, // Рух від 0 до 350px вниз
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.blueAccent.withOpacity(0.0),
                                Colors.blueAccent.withOpacity(0.8),
                                Colors.cyanAccent,
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blueAccent.withOpacity(0.5),
                                blurRadius: 15,
                                spreadRadius: 5,
                                offset: const Offset(0, 0),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  // Декоративна рамка сканера ("приціл")
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Текст "Аналізуємо..."
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                ]
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.blue)),
                const SizedBox(width: 16),
                Text(
                  AppText.get('scan_analyzing'),
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}