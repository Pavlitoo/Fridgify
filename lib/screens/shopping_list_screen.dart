import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../translations.dart';
import '../global.dart';
import '../error_handler.dart';
import '../utils/snackbar_utils.dart'; // ✅ Гарні повідомлення

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

  CollectionReference _getListCollection(String? householdId) {
    if (householdId != null) {
      return FirebaseFirestore.instance.collection('households').doc(householdId).collection('shopping_list');
    }
    return FirebaseFirestore.instance.collection('users').doc(user.uid).collection('shopping_list');
  }

  CollectionReference _getFridgeCollection(String? householdId) {
    if (householdId != null) {
      return FirebaseFirestore.instance.collection('households').doc(householdId).collection('products');
    }
    return FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products');
  }

  Future<void> _addItem(CollectionReference collection) async {
    if (_itemController.text.trim().isEmpty) return;
    try {
      await collection.add({
        'name': _itemController.text.trim(),
        'quantity': double.tryParse(_qtyController.text) ?? 1.0,
        'unit': _selectedUnit,
        'isBought': false,
        'addedDate': Timestamp.now(),
      });
      _itemController.clear();
      _qtyController.text = '1';
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, ErrorHandler.getMessage(e));
    }
  }

  Future<void> _buyItem(String docId, Map<String, dynamic> data, String? householdId) async {
    try {
      final fridgeCol = _getFridgeCollection(householdId);

      // Додаємо в холодильник
      await fridgeCol.add({
        'name': data['name'],
        'quantity': data['quantity'],
        'unit': data['unit'],
        'category': 'other', // Можна зробити автовизначення категорії, якщо треба
        'expirationDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
        'addedDate': Timestamp.now(),
      });

      // Видаляємо зі списку покупок
      final listCol = _getListCollection(householdId);
      await listCol.doc(docId).delete();

      if (mounted) {
        // ✅ Гарне повідомлення про покупку
        SnackbarUtils.showSuccess(context, "✅ ${data['name']} -> ${AppText.get('my_fridge')}");
      }
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, ErrorHandler.getMessage(e));
    }
  }

  void _deleteItem(String docId, CollectionReference collection, String name) {
    collection.doc(docId).delete();
    // ✅ Гарне повідомлення про видалення
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
              // Поле вводу
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[900] : Colors.green.shade50,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _itemController,
                      style: TextStyle(color: textColor),
                      decoration: InputDecoration(
                        hintText: AppText.get('shopping_hint'),
                        prefixIcon: const Icon(Icons.add_shopping_cart, color: Colors.green),
                        filled: true,
                        fillColor: cardColor,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _qtyController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: textColor),
                            decoration: InputDecoration(
                              filled: true, fillColor: cardColor,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedUnit,
                              dropdownColor: cardColor,
                              style: TextStyle(color: textColor),
                              onChanged: (val) => setState(() => _selectedUnit = val!),
                              items: ['pcs', 'kg', 'g', 'l', 'ml'].map((u) => DropdownMenuItem(value: u, child: Text(AppText.get('u_$u')))).toList(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FloatingActionButton.small(
                          onPressed: () => _addItem(collection),
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 2,
                          child: const Icon(Icons.add),
                        )
                      ],
                    )
                  ],
                ),
              ),

              // Список
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: collection.orderBy('addedDate', descending: true).snapshots(),
                  builder: (ctx, snapshot) {

                    if (snapshot.hasError) {
                      if (snapshot.error.toString().contains('permission-denied')) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                            'householdId': FieldValue.delete()
                          });
                        });
                      }

                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, size: 60, color: Colors.orange),
                            const SizedBox(height: 10),
                            Text(ErrorHandler.getMessage(snapshot.error!), style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    }

                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    final docs = snapshot.data!.docs;

                    if (docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.grey.shade300),
                            const SizedBox(height: 10),
                            Text(AppText.get('list_empty'), style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                            Text(AppText.get('list_empty_sub'), style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (ctx, i) {
                        final data = docs[i].data() as Map<String, dynamic>;
                        final docId = docs[i].id;

                        return Dismissible(
                          key: Key(docId),
                          // 🔥 ДОЗВОЛЯЄМО СВАЙП В ОБИДВІ СТОРОНИ
                          direction: DismissDirection.horizontal,

                          // Свайп вправо (Купити -> Холодильник)
                          background: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(15)),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            child: Row(
                              children: [
                                const Icon(Icons.kitchen, color: Colors.white, size: 30),
                                const SizedBox(width: 10),
                                Text(AppText.get('my_fridge'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                              ],
                            ),
                          ),

                          // Свайп вліво (Видалити)
                          secondaryBackground: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(color: Colors.red.shade400, borderRadius: BorderRadius.circular(15)),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text(AppText.get('btn_delete_forever'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 10),
                                const Icon(Icons.delete_outline, color: Colors.white, size: 30),
                              ],
                            ),
                          ),

                          onDismissed: (direction) {
                            if (direction == DismissDirection.startToEnd) {
                              // Свайп вправо -> Купити
                              _buyItem(docId, data, householdId);
                            } else {
                              // Свайп вліво -> Видалити
                              _deleteItem(docId, collection, data['name']);
                            }
                          },

                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(15),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: ListTile(
                              // 🔥 ЗАМІНИВ КРУЖЕЧОК НА ІКОНКУ ПОКУПКИ
                              leading: Icon(Icons.shopping_bag_outlined, color: isDark ? Colors.grey : Colors.grey.shade400),
                              title: Text(
                                  data['name'],
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                    color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8)
                                ),
                                child: Text(
                                  "${data['quantity']} ${AppText.get('u_${data['unit']}')}",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade600),
                                ),
                              ),
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