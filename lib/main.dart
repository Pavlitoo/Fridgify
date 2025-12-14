import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Іконки
import 'firebase_options.dart';
import 'product_model.dart';

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light),
        useMaterial3: true,
        // (Прибрали проблемні налаштування themes)
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
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
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool isLoading = false;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  // --- GOOGLE LOGIN ---
  Future<void> signInWithGoogle() async {
    setState(() => isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      _showError("Помилка Google: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- GITHUB LOGIN (НОВЕ) ---
  Future<void> signInWithGitHub() async {
    setState(() => isLoading = true);
    try {
      // GitHub на Android відкриває вікно браузера для входу
      GithubAuthProvider githubProvider = GithubAuthProvider();
      await FirebaseAuth.instance.signInWithProvider(githubProvider);
    } catch (e) {
      _showError("Помилка GitHub: $e");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- EMAIL LOGIN ---
  Future<void> submitAuthForm() async {
    setState(() => isLoading = true);
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
      } else {
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
        if (nameController.text.isNotEmpty) {
          await userCredential.user!.updateDisplayName(nameController.text.trim());
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = "Помилка: ${e.message}";
      if (e.code == 'user-not-found') message = "Користувача не знайдено";
      else if (e.code == 'wrong-password') message = "Невірний пароль";
      else if (e.code == 'email-already-in-use') message = "Email вже зайнятий";
      else if (e.code == 'weak-password') message = "Пароль має бути мінімум 6 символів";
      _showError(message);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Colors.green.shade50, Colors.white],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.kitchen, size: 80, color: Colors.green.shade700),
                const SizedBox(height: 10),
                Text(
                  isLogin ? 'З поверненням!' : 'Створити акаунт',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                ),
                const SizedBox(height: 30),

                if (!isLogin) ...[
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: "Ваше Ім'я", prefixIcon: const Icon(Icons.person),
                      filled: true, fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email', prefixIcon: const Icon(Icons.email),
                    filled: true, fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Пароль', prefixIcon: const Icon(Icons.lock),
                    filled: true, fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 24),

                if (isLoading)
                  const CircularProgressIndicator()
                else
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: submitAuthForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(isLogin ? 'Увійти' : 'Зареєструватися', style: const TextStyle(fontSize: 18)),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => setState(() => isLogin = !isLogin),
                        child: Text(isLogin ? "Немає акаунту? Зареєструватися" : "Вже є акаунт? Увійти"),
                      ),
                    ],
                  ),

                const SizedBox(height: 20),
                const Row(children: [Expanded(child: Divider()), Padding(padding: EdgeInsets.all(8.0), child: Text("АБО")), Expanded(child: Divider())]),
                const SizedBox(height: 20),

                // --- КНОПКИ СОЦМЕРЕЖ ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Google
                    _socialButton(
                      icon: FontAwesomeIcons.google,
                      color: Colors.red,
                      onTap: signInWithGoogle,
                    ),
                    const SizedBox(width: 20),
                    // GitHub
                    _socialButton(
                      icon: FontAwesomeIcons.github,
                      color: Colors.black,
                      onTap: signInWithGitHub,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Дизайн круглої кнопки
  Widget _socialButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        width: 60, height: 60,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5, spreadRadius: 1)],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Center(child: FaIcon(icon, color: color, size: 30)),
      ),
    );
  }
}

// --- ГОЛОВНИЙ ЕКРАН ---
class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});
  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  final user = FirebaseAuth.instance.currentUser!;

  void _showProductDialog({Product? productToEdit}) {
    final nameController = TextEditingController(text: productToEdit?.name ?? '');
    int daysToExpire = productToEdit?.daysLeft ?? 7;
    if (daysToExpire < 1) daysToExpire = 1; if (daysToExpire > 30) daysToExpire = 30;
    final isEditing = productToEdit != null;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              contentPadding: const EdgeInsets.all(24),
              title: Text(isEditing ? 'Редагувати' : 'Додати продукт', style: const TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(
                          labelText: 'Назва продукту', hintText: 'напр. Молоко', prefixIcon: const Icon(Icons.fastfood),
                          filled: true, fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        ),
                        autofocus: true,
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Придатний днів:", style: TextStyle(fontSize: 16)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(10)),
                            child: Text("$daysToExpire днів", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 16)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(trackHeight: 8.0, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12.0), overlayShape: const RoundSliderOverlayShape(overlayRadius: 24.0)),
                        child: Slider(
                          value: daysToExpire.toDouble(), min: 1, max: 30, divisions: 29, activeColor: Colors.green,
                          onChanged: (val) => setDialogState(() => daysToExpire = val.toInt()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Скасувати', style: TextStyle(fontSize: 16))),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      final data = {
                        'name': nameController.text.trim(),
                        'expirationDate': Timestamp.fromDate(DateTime.now().add(Duration(days: daysToExpire))),
                      };
                      final collection = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products');
                      isEditing ? await collection.doc(productToEdit.id).update(data) : await collection.add({...data, 'addedDate': Timestamp.now()});
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12)),
                  child: Text(isEditing ? 'Зберегти' : 'Додати', style: const TextStyle(fontSize: 16)),
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
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        backgroundColor: Colors.green.shade100,
        title: Row(
          children: [
            if (user.photoURL != null) CircleAvatar(backgroundImage: NetworkImage(user.photoURL!), radius: 18)
            else CircleAvatar(backgroundColor: Colors.green.shade300, child: Text(user.displayName?[0].toUpperCase() ?? 'U', style: const TextStyle(color: Colors.white))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Мій Холодильник', style: TextStyle(fontSize: 16)),
              Text(user.displayName ?? 'Користувач', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ])),
          ],
        ),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products').orderBy('expirationDate').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.kitchen_outlined, size: 80, color: Colors.green.shade300), const SizedBox(height: 20), const Text("Холодильник пустий!", style: TextStyle(fontSize: 20))]));
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final product = Product.fromFirestore(docs[index]);
              Color statusColor = product.daysLeft < 3 ? Colors.red : (product.daysLeft < 7 ? Colors.orange : Colors.green);
              return Card(
                elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), margin: const EdgeInsets.symmetric(vertical: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _showProductDialog(productToEdit: product),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.fastfood, color: statusColor, size: 28)),
                      title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Padding(padding: const EdgeInsets.only(top: 8.0), child: Row(children: [Icon(Icons.timer_outlined, size: 16, color: statusColor), const SizedBox(width: 4), Text("Залишилось днів: ${product.daysLeft}", style: TextStyle(color: statusColor, fontWeight: FontWeight.w500))])),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey), onPressed: () => FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products').doc(product.id).delete()),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _showProductDialog(), label: const Text("Додати продукт"), icon: const Icon(Icons.add), backgroundColor: Colors.green.shade600, foregroundColor: Colors.white),
    );
  }
}