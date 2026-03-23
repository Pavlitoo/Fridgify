import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../product_model.dart';
import '../translations.dart';
import '../global.dart';
import '../utils/snackbar_utils.dart';

class FridgeDialogs {

  // ==========================================
  // ДІАЛОГ ДОДАВАННЯ / РЕДАГУВАННЯ ПРОДУКТУ
  // ==========================================
  static void showProductDialog({
    required BuildContext context,
    Product? productToEdit,
    required CollectionReference collection,
    required List<dynamic> categories, // CategoryData List
    required Function(int) cancelNotification,
  }) {
    final nameController = TextEditingController(text: productToEdit?.name ?? '');
    final qtyController = TextEditingController(text: productToEdit?.quantity.toString() ?? '1');
    String selectedUnit = productToEdit?.unit ?? 'pcs';
    DateTime selectedDate = productToEdit?.expirationDate ?? DateTime.now().add(const Duration(days: 7));
    final isEditing = productToEdit != null;

    String selectedCategory = productToEdit?.category ?? 'other';
    if (selectedCategory == 'trash') selectedCategory = 'other';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          String formattedDate = "${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}";
          final dialogBg = Theme.of(context).cardColor;
          final textColor = Theme.of(context).textTheme.bodyLarge?.color;
          final inputFill = Theme.of(context).scaffoldBackgroundColor;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          Widget quickDateChip(String label, int days) {
            final targetDate = DateTime.now().add(Duration(days: days));
            final isSelected = selectedDate.year == targetDate.year &&
                selectedDate.month == targetDate.month &&
                selectedDate.day == targetDate.day;

            return Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: InkWell(
                onTap: () => setDialogState(() => selectedDate = targetDate),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.green : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? Colors.green : Colors.transparent),
                  ),
                  child: Text(label, style: TextStyle(color: isSelected ? Colors.white : textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                ),
              ),
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: dialogBg,
            contentPadding: const EdgeInsets.all(24),
            title: Text(isEditing ? AppText.get('edit_product') : AppText.get('add_product'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: textColor), textAlign: TextAlign.center),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(controller: nameController, style: TextStyle(fontSize: 18, color: textColor), decoration: InputDecoration(hintText: AppText.get('product_name'), hintStyle: const TextStyle(color: Colors.grey), prefixIcon: const Icon(Icons.edit, color: Colors.green), filled: true, fillColor: inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)), autofocus: true),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: TextField(controller: qtyController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: textColor), decoration: InputDecoration(hintText: AppText.get('quantity'), hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
                      const SizedBox(width: 12),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(16)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(dropdownColor: dialogBg, value: selectedUnit, style: TextStyle(color: textColor), onChanged: (val) => setDialogState(() => selectedUnit = val!), items: ['pcs', 'kg', 'g', 'l', 'ml'].map((unit) { return DropdownMenuItem(value: unit, child: Text(AppText.get('u_$unit'), style: TextStyle(color: textColor))); }).toList())))
                    ]),
                    const SizedBox(height: 24),

                    Center(child: Text(AppText.get('category_label'), style: TextStyle(color: textColor?.withValues(alpha: 0.7), fontWeight: FontWeight.bold))),
                    const SizedBox(height: 12),
                    Center(
                      child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 10, children: categories.map((cat) { final isSelected = selectedCategory == cat.id; return InkWell(onTap: () => setDialogState(() => selectedCategory = cat.id), child: Column(mainAxisSize: MainAxisSize.min, children: [AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isSelected ? cat.color : inputFill, shape: BoxShape.circle, boxShadow: isSelected ? [BoxShadow(color: cat.color.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))] : []), child: Icon(cat.icon, color: isSelected ? Colors.white : Colors.grey, size: 28)), const SizedBox(height: 4), Text(AppText.get(cat.labelKey), style: TextStyle(fontSize: 10, color: isSelected ? cat.color : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))])); }).toList()),
                    ),
                    const SizedBox(height: 24),

                    Text(AppText.get('days_valid'), style: TextStyle(color: textColor?.withValues(alpha: 0.7), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          quickDateChip("+3 ${AppText.get('u_days')}", 3),
                          quickDateChip("+7 ${AppText.get('u_days')}", 7),
                          quickDateChip("+14 ${AppText.get('u_days')}", 14),
                          quickDateChip("+30 ${AppText.get('u_days')}", 30),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                              builder: (ctx, child) {
                                // Форсуємо мову календаря
                                Locale loc = const Locale('en', 'US');
                                switch(languageNotifier.value) {
                                  case 'Українська': loc = const Locale('uk', 'UA'); break;
                                  case 'Español': loc = const Locale('es', 'ES'); break;
                                  case 'Français': loc = const Locale('fr', 'FR'); break;
                                  case 'Deutsch': loc = const Locale('de', 'DE'); break;
                                }
                                return Localizations.override(context: ctx, locale: loc, child: child!);
                              }
                          );
                          if (picked != null && picked != selectedDate) { setDialogState(() { selectedDate = picked; }); }
                        },
                        child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(color: Colors.green.shade50.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.green.withValues(alpha: 0.5))),
                            child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.calendar_month_rounded, size: 20, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16))
                                ]
                            )
                        )
                    )
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(AppText.get('cancel'), style: TextStyle(fontSize: 16, color: textColor))),
              ElevatedButton(onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final qty = double.tryParse(qtyController.text) ?? 1.0;
                  final data = {'name': nameController.text.trim(), 'expirationDate': Timestamp.fromDate(selectedDate), 'category': selectedCategory, 'quantity': qty, 'unit': selectedUnit};
                  if (isEditing) {
                    await collection.doc(productToEdit.id).update(data);
                    cancelNotification(productToEdit.id.hashCode);
                  } else {
                    await collection.add({...data, 'addedDate': Timestamp.now()});
                  }
                  Navigator.pop(context);
                }
              }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(isEditing ? AppText.get('save') : AppText.get('add'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))
            ],
          );
        });
      },
    );
  }

  // ==========================================
  // ДІАЛОГ "З'ЇДЕНО" (КОНСЬЮМ)
  // ==========================================
  static void showConsumeDialog({
    required BuildContext context,
    required Product product,
    required CollectionReference collection,
    required Function(String, String) recordHistory,
    required VoidCallback onDeleteForever,
  }) {
    final TextEditingController consumeController = TextEditingController();
    bool isPcs = product.unit == 'pcs';
    final dialogBg = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final inputFill = Theme.of(context).scaffoldBackgroundColor;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text(AppText.get('action_eaten'), textAlign: TextAlign.center, style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("${product.quantity} ${AppText.get('u_${product.unit}') ?? product.unit}", style: TextStyle(fontSize: 14, color: textColor?.withValues(alpha: 0.7))),
            const SizedBox(height: 10),
            TextField(
              controller: consumeController,
              keyboardType: TextInputType.numberWithOptions(decimal: !isPcs),
              inputFormatters: isPcs ? [FilteringTextInputFormatter.digitsOnly] : [],
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                  hintText: "???",
                  filled: true,
                  fillColor: inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppText.get('cancel'))),
          ElevatedButton(
            onPressed: () {
              double consumed;
              if (isPcs) {
                consumed = int.tryParse(consumeController.text)?.toDouble() ?? 0;
              } else {
                consumed = double.tryParse(consumeController.text.replaceAll(',', '.')) ?? 0;
              }
              if (consumed <= 0) return;

              if (consumed > product.quantity) {
                SnackbarUtils.showError(context, AppText.get('err_eat_too_much'));
                return;
              }

              if (consumed == product.quantity) {
                onDeleteForever();
              } else {
                double newQty = product.quantity - consumed;
                newQty = (newQty * 100).round() / 100;
                collection.doc(product.id).update({'quantity': newQty});
              }

              recordHistory(product.name, 'eaten');
              Navigator.pop(ctx);
              SnackbarUtils.showSuccess(context, "😋 ${AppText.get('action_eaten')}");
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: Text(AppText.get('save')),
          ),
        ],
      ),
    );
  }
}