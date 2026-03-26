import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../translations.dart';
import '../global.dart';
import '../error_handler.dart';
import '../utils/snackbar_utils.dart';

class CategoryData {
  final String id;
  final IconData icon;
  final Color color;
  final String labelKey;
  CategoryData(this.id, this.icon, this.color, this.labelKey);
}

final List<CategoryData> appCategories = [
  CategoryData('other', Icons.fastfood, Colors.grey, 'cat_other'),
  CategoryData('meat', Icons.set_meal, Colors.red, 'cat_meat'),
  CategoryData('veg', Icons.eco, Colors.green, 'cat_veg'),
  CategoryData('fruit', Icons.apple, Colors.orange, 'cat_fruit'),
  CategoryData('dairy', Icons.egg, Colors.blueGrey, 'cat_dairy'),
  CategoryData('bakery', Icons.breakfast_dining, Colors.brown, 'cat_bakery'),
  CategoryData('sweet', Icons.cake, Colors.pink, 'cat_sweet'),
  CategoryData('drink', Icons.local_drink, Colors.blue, 'cat_drink'),
];

Locale getAppLocale(String langName) {
  switch (langName) {
    case 'Українська': return const Locale('uk', 'UA');
    case 'Español': return const Locale('es', 'ES');
    case 'Français': return const Locale('fr', 'FR');
    case 'Deutsch': return const Locale('de', 'DE');
    default: return const Locale('en', 'US');
  }
}

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _qtyController = TextEditingController(text: '1');
  String _selectedUnit = 'pcs';

  // --- ДОПОМІЖНА ЛОГІКА ДЛЯ ЗЛИТТЯ ПРОДУКТІВ ---
  bool _isSameProduct(String name1, String name2) {
    String n1 = name1.toLowerCase().trim().replaceAll(RegExp(r'[^\w\sа-яА-ЯіІїЇєЄ]'), '');
    String n2 = name2.toLowerCase().trim().replaceAll(RegExp(r'[^\w\sа-яА-ЯіІїЇєЄ]'), '');
    if (n1.isEmpty || n2.isEmpty) return false;
    return n1 == n2 || n1.contains(n2) || n2.contains(n1);
  }
  String _getUnitType(String unit) {
    if (unit == 'g' || unit == 'kg') return 'weight';
    if (unit == 'ml' || unit == 'l') return 'volume';
    return 'count';
  }
  double _getBaseQty(double qty, String unit) {
    if (unit == 'kg' || unit == 'l') return qty * 1000;
    return qty;
  }
  Map<String, dynamic> _formatQtyAndUnit(double baseQty, String type) {
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

  CollectionReference _getListCollection(String? householdId) {
    if (householdId != null) return FirebaseFirestore.instance.collection('households').doc(householdId).collection('shopping_list');
    return FirebaseFirestore.instance.collection('users').doc(user.uid).collection('shopping_list');
  }

  CollectionReference _getFridgeCollection(String? householdId) {
    if (householdId != null) return FirebaseFirestore.instance.collection('households').doc(householdId).collection('products');
    return FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products');
  }

  // 🔥 ЗЛИТТЯ ПРИ ДОДАВАННІ В СПИСОК ПОКУПОК
  Future<void> _addItem(CollectionReference collection) async {
    if (_itemController.text.trim().isEmpty) return;
    final newName = _itemController.text.trim();
    final newQty = double.tryParse(_qtyController.text.replaceAll(',', '.')) ?? 1.0;
    final newUnit = _selectedUnit;

    try {
      final existingDocs = await collection.get();
      QueryDocumentSnapshot? matchDoc;

      for (var doc in existingDocs.docs) {
        final d = doc.data() as Map<String, dynamic>;
        if (_isSameProduct(d['name'], newName) && _getUnitType(d['unit']) == _getUnitType(newUnit)) {
          matchDoc = doc; break;
        }
      }

      if (matchDoc != null) {
        final matchData = matchDoc.data() as Map<String, dynamic>;
        final baseExt = _getBaseQty((matchData['quantity'] as num).toDouble(), matchData['unit']);
        final baseNew = _getBaseQty(newQty, newUnit);
        final formatted = _formatQtyAndUnit(baseExt + baseNew, _getUnitType(newUnit));

        await collection.doc(matchDoc.id).update({
          'quantity': formatted['qty'],
          'unit': formatted['unit']
        });
      } else {
        await collection.add({
          'name': newName,
          'quantity': newQty,
          'unit': newUnit,
          'isBought': false,
          'addedDate': Timestamp.now(),
        });
      }

      _itemController.clear();
      _qtyController.text = '1';
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, ErrorHandler.getMessage(e));
    }
  }

  Future<bool> _showBuyDialog(String docId, Map<String, dynamic> data, String? householdId) async {
    final nameController = TextEditingController(text: data['name']);
    final qtyController = TextEditingController(text: data['quantity'].toString());
    String selectedUnit = data['unit'] ?? 'pcs';
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    String selectedCategory = 'other';

    bool isAddedToFridge = false;

    Widget buildDateChip(int days, DateTime currentDate, Function(DateTime) onSelect) {
      final targetDate = DateTime.now().add(Duration(days: days));
      final isSelected = targetDate.year == currentDate.year && targetDate.month == currentDate.month && targetDate.day == currentDate.day;
      return ActionChip(
        label: Text("+$days ${AppText.get('u_days')}", style: TextStyle(color: isSelected ? Colors.white : Colors.grey.shade700, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        backgroundColor: isSelected ? Colors.green : Colors.grey.shade200, padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
        onPressed: () => onSelect(targetDate),
      );
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          String formattedDate = "${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}";
          final dialogBg = Theme.of(context).cardColor;
          final textColor = Theme.of(context).textTheme.bodyLarge?.color;
          final inputFill = Theme.of(context).scaffoldBackgroundColor;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            backgroundColor: dialogBg,
            contentPadding: const EdgeInsets.all(24),
            title: Text(AppText.get('add_product'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: textColor), textAlign: TextAlign.center),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, style: TextStyle(fontSize: 18, color: textColor), decoration: InputDecoration(hintText: AppText.get('product_name'), hintStyle: const TextStyle(color: Colors.grey), prefixIcon: const Icon(Icons.edit, color: Colors.green), filled: true, fillColor: inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(child: TextField(controller: qtyController, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: textColor), decoration: InputDecoration(hintText: AppText.get('quantity'), hintStyle: const TextStyle(color: Colors.grey), filled: true, fillColor: inputFill, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)))),
                      const SizedBox(width: 12),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(16)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(dropdownColor: dialogBg, value: selectedUnit, style: TextStyle(color: textColor), onChanged: (val) => setDialogState(() => selectedUnit = val!), items: ['pcs', 'kg', 'g', 'l', 'ml'].map((unit) { return DropdownMenuItem(value: unit, child: Text(AppText.get('u_$unit'), style: TextStyle(color: textColor))); }).toList())))
                    ]),
                    const SizedBox(height: 24),
                    Text(AppText.get('category_label'), style: TextStyle(color: textColor?.withOpacity(0.7), fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 10, children: appCategories.map((cat) { final isSelected = selectedCategory == cat.id; return InkWell(onTap: () => setDialogState(() => selectedCategory = cat.id), child: Column(mainAxisSize: MainAxisSize.min, children: [AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isSelected ? cat.color : inputFill, shape: BoxShape.circle, boxShadow: isSelected ? [BoxShadow(color: cat.color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : []), child: Icon(cat.icon, color: isSelected ? Colors.white : Colors.grey, size: 28)), const SizedBox(height: 4), Text(AppText.get(cat.labelKey), style: TextStyle(fontSize: 10, color: isSelected ? cat.color : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))])); }).toList()),
                    const SizedBox(height: 24),

                    Align(alignment: Alignment.centerLeft, child: Text(AppText.get('days_valid'), style: TextStyle(color: textColor?.withOpacity(0.7), fontWeight: FontWeight.bold))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        buildDateChip(3, selectedDate, (d) => setDialogState(() => selectedDate = d)),
                        buildDateChip(7, selectedDate, (d) => setDialogState(() => selectedDate = d)),
                        buildDateChip(14, selectedDate, (d) => setDialogState(() => selectedDate = d)),
                        buildDateChip(30, selectedDate, (d) => setDialogState(() => selectedDate = d)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365 * 10)), locale: getAppLocale(languageNotifier.value));
                          if (picked != null && picked != selectedDate) {
                            setDialogState(() { selectedDate = picked; });
                          }
                        },
                        child: Container(
                            width: double.infinity,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(color: Colors.green.shade50.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green)),
                            child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_today, size: 18, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16))
                                ]
                            )
                        )
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () { Navigator.pop(context); },
                  child: Text(AppText.get('cancel'), style: TextStyle(fontSize: 16, color: textColor))
              ),
              ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      final newName = nameController.text.trim();
                      final qty = double.tryParse(qtyController.text.replaceAll(',', '.')) ?? 1.0;
                      final fridgeCol = _getFridgeCollection(householdId);

                      // 🔥 ЗЛИТТЯ ПРИ ПЕРЕМІЩЕННІ В ХОЛОДИЛЬНИК
                      final existingDocs = await fridgeCol.get();
                      QueryDocumentSnapshot? matchDoc;
                      for (var doc in existingDocs.docs) {
                        final d = doc.data() as Map<String, dynamic>;
                        if (d['category'] != 'trash' && _isSameProduct(d['name'], newName) && _getUnitType(d['unit']) == _getUnitType(selectedUnit)) {
                          matchDoc = doc; break;
                        }
                      }

                      if (matchDoc != null) {
                        final matchData = matchDoc.data() as Map<String, dynamic>;
                        final baseExt = _getBaseQty((matchData['quantity'] as num).toDouble(), matchData['unit']);
                        final baseNew = _getBaseQty(qty, selectedUnit);
                        final formatted = _formatQtyAndUnit(baseExt + baseNew, _getUnitType(selectedUnit));

                        DateTime existingDate = (matchData['expirationDate'] as Timestamp).toDate();
                        DateTime finalDate = selectedDate.isAfter(existingDate) ? selectedDate : existingDate;

                        await fridgeCol.doc(matchDoc.id).update({
                          'quantity': formatted['qty'],
                          'unit': formatted['unit'],
                          'expirationDate': Timestamp.fromDate(finalDate)
                        });
                      } else {
                        await fridgeCol.add({
                          'name': newName,
                          'expirationDate': Timestamp.fromDate(selectedDate),
                          'category': selectedCategory,
                          'quantity': qty,
                          'unit': selectedUnit,
                          'addedDate': Timestamp.now()
                        });
                      }

                      final listCol = _getListCollection(householdId);
                      await listCol.doc(docId).delete();

                      isAddedToFridge = true;
                      if (mounted) {
                        Navigator.pop(context);
                        SnackbarUtils.showSuccess(context, "✅ ${newName} -> ${AppText.get('my_fridge')}");
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(AppText.get('save'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))
              )
            ],
          );
        });
      },
    );

    return isAddedToFridge;
  }

  void _deleteItem(String docId, CollectionReference collection, String name) {
    collection.doc(docId).delete();
    if (mounted) {
      SnackbarUtils.showWarning(context, "🗑 $name ${AppText.get('status_deleted')}");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
      builder: (context, userSnap) {
        final householdId = userSnap.data?.data() != null
            ? (userSnap.data!.data() as Map)['householdId']
            : null;

        final collection = _getListCollection(householdId);

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            title: Text(AppText.get('shopping_title'), style: const TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: isDark ? Colors.grey[900] : Colors.green.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))),
                child: Column(
                  children: [
                    TextField(
                      controller: _itemController, style: TextStyle(color: textColor),
                      decoration: InputDecoration(hintText: AppText.get('shopping_hint'), prefixIcon: const Icon(Icons.add_shopping_cart, color: Colors.green), filled: true, fillColor: cardColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: _qtyController, keyboardType: const TextInputType.numberWithOptions(decimal: true), textAlign: TextAlign.center, style: TextStyle(color: textColor), decoration: InputDecoration(filled: true, fillColor: cardColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)))),
                        const SizedBox(width: 10),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _selectedUnit, dropdownColor: cardColor, style: TextStyle(color: textColor), onChanged: (val) => setState(() => _selectedUnit = val!), items: ['pcs', 'kg', 'g', 'l', 'ml'].map((u) => DropdownMenuItem(value: u, child: Text(AppText.get('u_$u')))).toList()))),
                        const SizedBox(width: 10),
                        FloatingActionButton.small(onPressed: () => _addItem(collection), backgroundColor: Colors.green, foregroundColor: Colors.white, elevation: 2, child: const Icon(Icons.add))
                      ],
                    )
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: collection.orderBy('addedDate', descending: true).snapshots(),
                  builder: (ctx, snapshot) {
                    if (snapshot.hasError) {
                      if (snapshot.error.toString().contains('permission-denied')) {
                        WidgetsBinding.instance.addPostFrameCallback((_) { FirebaseFirestore.instance.collection('users').doc(user.uid).update({'householdId': FieldValue.delete()}); });
                      }
                      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, size: 60, color: Colors.orange), const SizedBox(height: 10), Text(ErrorHandler.getMessage(snapshot.error!), style: const TextStyle(color: Colors.grey))]));
                    }

                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey.shade300), const SizedBox(height: 10), Text(AppText.get('list_empty'), style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold)), Text(AppText.get('list_empty_sub'), style: TextStyle(fontSize: 14, color: Colors.grey.shade400))]));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (ctx, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        final docId = docs[i].id;

                        return Dismissible(
                          key: Key(docId),
                          direction: DismissDirection.horizontal,
                          background: Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(15)), alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), child: Row(children: [const Icon(Icons.kitchen, color: Colors.white, size: 30), const SizedBox(width: 10), Text(AppText.get('my_fridge'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])),
                          secondaryBackground: Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(15)), alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [Text(AppText.get('btn_delete_forever'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), const SizedBox(width: 10), const Icon(Icons.delete_outline, color: Colors.white, size: 30)])),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.startToEnd) return await _showBuyDialog(docId, data, householdId);
                            else return true;
                          },
                          onDismissed: (direction) {
                            if (direction == DismissDirection.endToStart) _deleteItem(docId, collection, data['name']);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
                            child: ListTile(
                              leading: Icon(Icons.shopping_bag_outlined, color: isDark ? Colors.grey : Colors.grey.shade400),
                              title: Text(data['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                              trailing: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100, borderRadius: BorderRadius.circular(8)), child: Text("${data['quantity']} ${AppText.get('u_${data['unit']}')}", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600))),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}