import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Вхід Firebase
import 'package:google_sign_in/google_sign_in.dart'; // Вхід Google
import 'firebase_options.dart';

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
      // Перевіряємо: якщо юзер вже зайшов - показуємо Холодильник, якщо ні - Екран входу
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return const FridgeScreen(); // Головний екран
          }
          return const AuthScreen(); // Екран входу
        },
      ),
    );
  }
}

// --- ЕКРАН ВХОДУ ---
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  // Функція входу через Google
  Future<void> signInWithGoogle() async {
    try {
      // 1. Запускаємо вікно вибору акаунту Google
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // Якщо користувач закрив вікно

      // 2. Отримуємо ключі доступу
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Створюємо "квиток" для Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Заходимо у Firebase
      await FirebaseAuth.instance.signInWithCredential(credential);
      print("Успішний вхід: ${googleUser.displayName}");

    } catch (e) {
      print("Помилка входу: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Smart Fridge Login')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.kitchen, size: 100, color: Colors.green.shade600),
            const SizedBox(height: 20),
            const Text('Smart Fridge', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: signInWithGoogle, // Викликаємо нашу функцію
              icon: const Icon(Icons.login),
              label: const Text('Увійти через Google'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(250, 50)),
            ),
          ],
        ),
      ),
    );
  }
}

// --- ГОЛОВНИЙ ЕКРАН (ХОЛОДИЛЬНИК) ---
class FridgeScreen extends StatelessWidget {
  const FridgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Отримуємо дані поточного користувача
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Мій Холодильник'),
        backgroundColor: Colors.green.shade100,
        actions: [
          // Кнопка виходу
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Показуємо фото користувача
            if (user?.photoURL != null)
              CircleAvatar(
                backgroundImage: NetworkImage(user!.photoURL!),
                radius: 40,
              ),
            const SizedBox(height: 20),
            Text(
              'Привіт, ${user?.displayName}!',
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 10),
            const Text('Тут буде список твоїх продуктів', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}