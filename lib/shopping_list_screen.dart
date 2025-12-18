import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'translations.dart';

class ShoppingListScreen extends StatefulWidget {
  const ShoppingListScreen({super.key});

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  final TextEditingController _controller = TextEditingController();

  // Додати товар
  Future<void> _addItem(String name) async {
    if (name.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shopping_list')
        .add({
      'name': name,
      'isBought': false,
      'addedDate': Timestamp.now(),
    });
    _controller.clear();
  }

  // Змінити статус (Куплено/Не куплено)
  Future<void> _toggleBought(String id, bool currentValue) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shopping_list')
        .doc(id)
        .update({'isBought': !currentValue});
  }

  // Видалити товар
  Future<void> _deleteItem(String id) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('shopping_list')
        .doc(id)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: Text(AppText.get('shopping_list'), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.green.shade100,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Поле вводу
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: AppText.get('add_item'),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      prefixIcon: const Icon(Icons.add_shopping_cart, color: Colors.green),
                    ),
                    onSubmitted: (val) => _addItem(val.trim()),
                  ),
                ),
                const SizedBox(width: 10),
                FloatingActionButton.small(
                  onPressed: () => _addItem(_controller.text.trim()),
                  backgroundColor: Colors.green,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
          ),

          // Список
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('shopping_list')
                  .orderBy('addedDate', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final docs = snapshot.data!.docs;

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_basket_outlined, size: 80, color: Colors.green.shade200),
                        const SizedBox(height: 10),
                        Text(AppText.get('empty_list'), style: const TextStyle(color: Colors.grey, fontSize: 18)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final id = docs[index].id;
                    final isBought = data['isBought'] ?? false;

                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      color: isBought ? Colors.grey.shade200 : Colors.white,
                      child: ListTile(
                        leading: Checkbox(
                          value: isBought,
                          activeColor: Colors.green,
                          shape: const CircleBorder(),
                          onChanged: (val) => _toggleBought(id, isBought),
                        ),
                        title: Text(
                          data['name'],
                          style: TextStyle(
                            fontSize: 18,
                            decoration: isBought ? TextDecoration.lineThrough : null,
                            color: isBought ? Colors.grey : Colors.black,
                          ),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _deleteItem(id),
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
}