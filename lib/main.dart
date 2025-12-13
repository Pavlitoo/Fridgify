import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'product_model.dart'; // Переконайся, що цей файл існує в папці lib

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SmartFridgeApp());
}

class SmartFridgeApp extends StatelessWidget {
  const SmartFridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Fridge',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const FridgeScreen();
          }
          return const AuthScreen();
        },
      ),
    );
  }
}

// --- ЕКРАН ВХОДУ ---
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      print("Помилка входу: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.kitchen, size: 100, color: Colors.green.shade600),
            const SizedBox(height: 20),
            const Text('Smart Fridge', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: signInWithGoogle,
              icon: const Icon(Icons.login),
              label: const Text('Увійти через Google'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- ГОЛОВНИЙ ЕКРАН (ХОЛОДИЛЬНИК) ---
class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  final user = FirebaseAuth.instance.currentUser!;

  // Оновлена функція з працюючим повзунком
  void _addProduct() {
    final nameController = TextEditingController();
    int daysToExpire = 7; // Початкове значення

    showDialog(
      context: context,
      builder: (context) {
        // StatefulBuilder дозволяє оновлювати стан всередині діалогу
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Додати продукт'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Назва (напр. Молоко)'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 20),
                  // Показуємо вибрану кількість днів
                  Text(
                    "Придатний днів: $daysToExpire",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Slider(
                    value: daysToExpire.toDouble(),
                    min: 1,
                    max: 30,
                    divisions: 29,
                    label: "$daysToExpire",
                    activeColor: Colors.green,
                    onChanged: (val) {
                      // Тут використовуємо setDialogState замість setState
                      setDialogState(() {
                        daysToExpire = val.toInt();
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Скасувати'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('products')
                          .add({
                        'name': nameController.text,
                        'addedDate': Timestamp.now(),
                        'expirationDate': Timestamp.fromDate(
                          DateTime.now().add(Duration(days: daysToExpire)),
                        ),
                      });
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('Додати'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (user.photoURL != null)
              CircleAvatar(backgroundImage: NetworkImage(user.photoURL!), radius: 16),
            const SizedBox(width: 10),
            const Text('Мій Холодильник'),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut()),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('products')
            .orderBy('expirationDate')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text("Холодильник пустий! 🕸️\nДодай щось смачненьке."));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final product = Product.fromFirestore(docs[index]);

              Color statusColor = Colors.green;
              if (product.daysLeft < 3) statusColor = Colors.red;
              else if (product.daysLeft < 7) statusColor = Colors.orange;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withOpacity(0.2),
                    child: Icon(Icons.fastfood, color: statusColor),
                  ),
                  title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Залишилось днів: ${product.daysLeft}"),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.grey),
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .collection('products')
                          .doc(product.id)
                          .delete();
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProduct,
        child: const Icon(Icons.add),
      ),
    );
  }
}