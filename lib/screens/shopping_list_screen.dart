import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../translations.dart';
import '../global.dart';

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
    return (householdId != null)
        ? FirebaseFirestore.instance.collection('households').doc(householdId).collection('shopping_list')
        : FirebaseFirestore.instance.collection('users').doc(user.uid).collection('shopping_list');
  }

  CollectionReference _getFridgeCollection(String? householdId) {
    return (householdId != null)
        ? FirebaseFirestore.instance.collection('households').doc(householdId).collection('products')
        : FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products');
  }

  void _addItem(CollectionReference collection) {
    if (_itemController.text.isNotEmpty) {
      collection.add({
        'name': _itemController.text.trim(),
        'quantity': double.tryParse(_qtyController.text) ?? 1.0,
        'unit': _selectedUnit,
        'isBought': false,
        'addedDate': Timestamp.now(),
      });
      _itemController.clear();
      _qtyController.text = '1';
    }
  }

  void _deleteItem(DocumentSnapshot doc) {
    doc.reference.delete();
  }

  void _toggleBought(DocumentSnapshot doc) {
    doc.reference.update({'isBought': !doc['isBought']});
  }

  Future<void> _moveToFridge(DocumentSnapshot doc, String? householdId) async {
    final data = doc.data() as Map<String, dynamic>;
    final fridge = _getFridgeCollection(householdId);

    await fridge.add({
      'name': data['name'],
      'quantity': data['quantity'],
      'unit': data['unit'],
      'category': 'other',
      'expirationDate': Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
      'addedDate': Timestamp.now(),
    });

    await doc.reference.delete();
    if(mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppText.get('add')} -> ${AppText.get('my_fridge')} ❄️"), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, lang, child) {
          final textColor = Theme.of(context).textTheme.bodyLarge?.color;
          final cardColor = Theme.of(context).cardColor;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final inputFill = isDark ? const Color(0xFF2C2C2C) : Colors.white;

          return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, userSnap) {
                if (!userSnap.hasData && userSnap.connectionState == ConnectionState.waiting) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }

                final householdId = userSnap.data?.data() != null ? (userSnap.data!.data() as Map)['householdId'] : null;
                final collection = _getListCollection(householdId);

                return Scaffold(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  appBar: AppBar(title: Text(AppText.get('shopping_title')), backgroundColor: Theme.of(context).appBarTheme.backgroundColor, centerTitle: true),
                  body: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 5))]),
                        child: Column(
                          children: [
                            TextField(
                              controller: _itemController,
                              style: TextStyle(color: textColor),
                              decoration: InputDecoration(hintText: AppText.get('shopping_hint'), hintStyle: TextStyle(color: Colors.grey.shade400), prefixIcon: const Icon(Icons.add_shopping_cart, color: Colors.green), filled: true, fillColor: isDark ? Colors.black12 : Colors.green.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(flex: 2, child: TextField(controller: _qtyController, keyboardType: TextInputType.number, style: TextStyle(color: textColor), textAlign: TextAlign.center, decoration: InputDecoration(hintText: "1", filled: true, fillColor: isDark ? Colors.black12 : Colors.green.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 10)))),
                                const SizedBox(width: 8),
                                Container(padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: isDark ? Colors.black12 : Colors.green.shade50, borderRadius: BorderRadius.circular(12)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: _selectedUnit, dropdownColor: cardColor, icon: const Icon(Icons.arrow_drop_down, color: Colors.green), style: TextStyle(color: textColor, fontWeight: FontWeight.bold), items: ['pcs', 'kg', 'g', 'l', 'ml'].map((u) => DropdownMenuItem(value: u, child: Text(AppText.get('u_$u')))).toList(), onChanged: (v) => setState(() => _selectedUnit = v!)))),
                                const SizedBox(width: 10),
                                SizedBox(width: 50, height: 50, child: ElevatedButton(onPressed: () => _addItem(collection), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 2), child: const Icon(Icons.add, size: 28)))
                              ],
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: StreamBuilder<QuerySnapshot>(
                          stream: collection.orderBy('addedDate', descending: true).snapshots(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) return const Center(child: Text("Error"));
                            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                            final docs = List<DocumentSnapshot>.from(snapshot.data!.docs);

                            if (docs.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(25),
                                      decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
                                      child: Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.green.shade300),
                                    ),
                                    const SizedBox(height: 20),
                                    Text(AppText.get('list_empty'), style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    Text(AppText.get('list_empty_sub'), style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
                                  ],
                                ),
                              );
                            }

                            docs.sort((a, b) {
                              bool boughtA = (a.data() as Map)['isBought'] ?? false;
                              bool boughtB = (b.data() as Map)['isBought'] ?? false;
                              if (boughtA && !boughtB) return 1;
                              if (!boughtA && boughtB) return -1;
                              return 0;
                            });

                            return ListView.builder(
                              itemCount: docs.length,
                              padding: const EdgeInsets.all(16),
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                bool isBought = data['isBought'] ?? false;
                                String qtyStr = "${data['quantity'] ?? 1} ${AppText.get('u_${data['unit'] ?? 'pcs'}')}";

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Dismissible(
                                    key: Key(doc.id),
                                    background: Container(alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 20), decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.delete, color: Colors.white)),
                                    secondaryBackground: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), decoration: BoxDecoration(color: Colors.green, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.kitchen, color: Colors.white)),
                                    confirmDismiss: (direction) async {
                                      if (direction == DismissDirection.startToEnd) { // Свайп вправо (Видалити)
                                        _deleteItem(doc);
                                        return true;
                                      } else { // Свайп вліво (В холодильник)
                                        await _moveToFridge(doc, householdId);
                                        return false;
                                      }
                                    },
                                    child: Card(
                                      color: cardColor,
                                      margin: EdgeInsets.zero,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                      child: ListTile(
                                        onTap: () => _toggleBought(doc),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                                        title: Text(data['name'], style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, color: isBought ? Colors.grey : textColor, decoration: isBought ? TextDecoration.lineThrough : null)),
                                        trailing: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(color: isBought ? Colors.grey.shade200 : Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                                            child: Text(qtyStr, style: TextStyle(fontWeight: FontWeight.bold, color: isBought ? Colors.grey : Colors.green.shade700, fontSize: 14))
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
              }
          );
        }
    );
  }
}