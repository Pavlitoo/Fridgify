import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../translations.dart';
import '../utils/snackbar_utils.dart';
import '../subscription_service.dart';
import '../premium_screen.dart';

class ReceiptScanner {

  // --- ДОПОМІЖНА ЛОГІКА ДЛЯ ЗЛИТТЯ ПРОДУКТІВ ---
  static bool _isSameProduct(String name1, String name2) {
    String n1 = name1.toLowerCase().trim().replaceAll(RegExp(r'[^\w\sа-яА-ЯіІїЇєЄ]'), '');
    String n2 = name2.toLowerCase().trim().replaceAll(RegExp(r'[^\w\sа-яА-ЯіІїЇєЄ]'), '');
    if (n1.isEmpty || n2.isEmpty) return false;
    return n1 == n2 || n1.contains(n2) || n2.contains(n1);
  }

  static String _getUnitType(String unit) {
    if (unit == 'g' || unit == 'kg') return 'weight';
    if (unit == 'ml' || unit == 'l') return 'volume';
    return 'count';
  }

  static double _getBaseQty(double qty, String unit) {
    if (unit == 'kg' || unit == 'l') return qty * 1000;
    return qty;
  }

  static Map<String, dynamic> _formatQtyAndUnit(double baseQty, String type) {
    if (type == 'weight') {
      if (baseQty >= 1000) return {'qty': baseQty / 1000, 'unit': 'kg'};
      return {'qty': baseQty, 'unit': 'g'};
    }
    if (type == 'volume') {
      if (baseQty >= 1000) return {'qty': baseQty / 1000, 'unit': 'l'};
      return {'qty': baseQty, 'unit': 'ml'};
    }
    return {'qty': baseQty, 'unit': 'pcs'};
  }

  // ==========================================================
  // ГОЛОВНА ФУНКЦІЯ СКАНУВАННЯ
  // ==========================================================
  static Future<void> startScan(BuildContext context, CollectionReference collection, String userLang) async {
    bool hasFamilyMax = SubscriptionService().hasFamily;

    if (!hasFamilyMax) {
      _showPremiumPaywall(context);
      return;
    }

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

    // 🔥 ГОЛОВНИЙ ФІКС ДЛЯ ЕКОНОМІЇ КОШТІВ (Жорстке стиснення)
    final XFile? image = await picker.pickImage(
      source: source,
      imageQuality: 60, // Стискаємо якість
      maxWidth: 800,    // Обмежуємо ширину
      maxHeight: 800,   // Обмежуємо висоту
    );

    if (image == null) return;

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ScanningLoader(imageFile: File(image.path)),
    );

    try {
      final bytes = await File(image.path).readAsBytes();
      final String base64Image = base64Encode(bytes);

      final callable = FirebaseFunctions.instance.httpsCallable(
        'analyzeReceiptPhoto',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
      );

      final response = await callable.call({
        'imageBase64': base64Image,
        'userLanguage': userLang,
      });

      String jsonString = response.data['result'] as String;
      jsonString = jsonString.replaceAll('```json', '').replaceAll('```', '').trim();

      List<dynamic> items = jsonDecode(jsonString);

      if (items.isEmpty) {
        if (!context.mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        SnackbarUtils.showWarning(context, AppText.get('scan_not_found'));
        return;
      }

      final existingDocs = await collection.get();

      for (var item in items) {
        String newName = item['name'];
        double qty = (item['quantity'] as num).toDouble();
        String unit = item['unit'];
        String category = item['category'];
        int days = (item['estimatedDaysToExpire'] as num).toInt();
        DateTime expDate = DateTime.now().add(Duration(days: days));

        QueryDocumentSnapshot? matchDoc;

        for (var doc in existingDocs.docs) {
          final d = doc.data() as Map<String, dynamic>;
          if (d['category'] != 'trash' && _isSameProduct(d['name'], newName) && _getUnitType(d['unit']) == _getUnitType(unit)) {
            matchDoc = doc;
            break;
          }
        }

        if (matchDoc != null) {
          final matchData = matchDoc.data() as Map<String, dynamic>;
          final baseExt = _getBaseQty((matchData['quantity'] as num).toDouble(), matchData['unit']);
          final baseNew = _getBaseQty(qty, unit);
          final formatted = _formatQtyAndUnit(baseExt + baseNew, _getUnitType(unit));

          DateTime existingDate = (matchData['expirationDate'] as Timestamp).toDate();
          DateTime finalDate = expDate.isAfter(existingDate) ? expDate : existingDate;

          await collection.doc(matchDoc.id).update({
            'quantity': formatted['qty'],
            'unit': formatted['unit'],
            'expirationDate': Timestamp.fromDate(finalDate)
          });
        } else {
          await collection.add({
            'name': newName,
            'expirationDate': Timestamp.fromDate(expDate),
            'category': category,
            'quantity': qty,
            'unit': unit,
            'addedDate': Timestamp.now()
          });
        }
      }

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      SnackbarUtils.showSuccess(context, AppText.get('scan_success'));

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
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
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
      color: color.withOpacity(0.1),
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
                  Container(color: Colors.black.withOpacity(0.3)),
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
                              colors: [Colors.blueAccent.withOpacity(0.0), Colors.blueAccent.withOpacity(0.8), Colors.cyanAccent],
                            ),
                            boxShadow: [BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 15, spreadRadius: 5, offset: const Offset(0, 0))],
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned.fill(
                    child: Container(decoration: BoxDecoration(border: Border.all(color: Colors.blueAccent.withOpacity(0.5), width: 2), borderRadius: BorderRadius.circular(24))),
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
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
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