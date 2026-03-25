import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../translations.dart';
import '../utils/snackbar_utils.dart';
import '../subscription_service.dart';

class ReceiptScanner {
  static Future<void> startScan(BuildContext context, CollectionReference collection, String userLang) async {
    // 1. ПЕРЕВІРКА ПІДПИСКИ FAMILY MAX
    bool hasFamilyMax = SubscriptionService().hasFamily;

    if (!hasFamilyMax) {
      _showPremiumPaywall(context);
      return;
    }

    // 2. ЯКЩО ПІДПИСКА Є - ВІДКРИВАЄМО ВІКНО ВИБОРУ
    final picker = ImagePicker();

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final textColor = Theme.of(context).textTheme.bodyLarge?.color;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.only(top: 12, bottom: 30, left: 24, right: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10))),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.receipt_long, color: Colors.blue, size: 28),
                  const SizedBox(width: 10),
                  Text(AppText.get('scan_receipt_title'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                ],
              ),
              const SizedBox(height: 8),
              Text(AppText.get('scan_receipt_desc'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildOptionBtn(
                    context,
                    text: AppText.get('scan_camera'),
                    icon: Icons.camera_alt_rounded,
                    color: Colors.blue,
                    source: ImageSource.camera,
                  ),
                  _buildOptionBtn(
                    context,
                    text: AppText.get('scan_gallery'),
                    icon: Icons.photo_library_rounded,
                    color: Colors.purple,
                    source: ImageSource.gallery,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    final XFile? image = await picker.pickImage(source: source, imageQuality: 80);
    if (image == null) return;

    if (!context.mounted) return;

    // 3. АНІМОВАНИЙ ЛОАДЕР СКАНЕРА
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ScanningLoader(imageFile: File(image.path)),
    );

    try {
      // ТУТ БУДЕ ЗАПИТ ДО AI ДЛЯ ЧЕКІВ
      // Поки що імітуємо завантаження
      await Future.delayed(const Duration(seconds: 3));

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Закриваємо лоадер

      // Тимчасово показуємо повідомлення, поки не підключимо логіку ШІ
      SnackbarUtils.showSuccess(context, AppText.get('scan_receipt_dev'));

    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        SnackbarUtils.showError(context, "${AppText.get('scan_error')} $e");
      }
    }
  }

  // --- ВІКНО ПРОДАЖУ (PAYWALL) ---
  static void _showPremiumPaywall(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.workspace_premium, color: Colors.amber, size: 80),
              const SizedBox(height: 16),
              Text(
                AppText.get('prem_family_exclusive'),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                AppText.get('prem_family_exclusive_desc'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    // ТУТ МАЄ БУТИ НАВІГАЦІЯ НА ЕКРАН ПІДПИСОК
                    // Наприклад: Navigator.pushNamed(context, '/subscription_screen');
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.amber.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                  ),
                  child: Text(
                    AppText.get('prem_get_family'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(AppText.get('prem_maybe_later'), style: const TextStyle(color: Colors.grey)),
              )
            ],
          ),
        );
      },
    );
  }

  static Widget _buildOptionBtn(BuildContext context, {required String text, required IconData icon, required Color color, required ImageSource source}) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => Navigator.pop(context, source),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

// --- АНІМОВАНИЙ ЛОАДЕР ---
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
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
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
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: 280,
              height: 380,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(widget.imageFile, fit: BoxFit.cover),
                  Container(color: Colors.black.withValues(alpha: 0.3)),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Positioned(
                        top: _controller.value * 350,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.blueAccent.withValues(alpha: 0.0), Colors.blueAccent.withValues(alpha: 0.8), Colors.cyanAccent],
                            ),
                            boxShadow: [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.5), blurRadius: 15, spreadRadius: 5, offset: const Offset(0, 0))],
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned.fill(
                    child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5), width: 2), borderRadius: BorderRadius.circular(24))),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))]
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.blue)),
                const SizedBox(width: 16),
                Text(AppText.get('scan_receipt_analyzing'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color)),
              ],
            ),
          )
        ],
      ),
    );
  }
}