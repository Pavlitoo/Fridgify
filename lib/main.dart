import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'firebase_options.dart';
import 'product_model.dart';
import 'profile_screen.dart'; // Наш профіль
import 'translations.dart'; // Наш переклад

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
    // Огортаємо весь додаток, щоб він реагував на зміну мови
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Smart Fridge',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light),
            useMaterial3: true,
          ),
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (snapshot.hasData) return const HomeScreen();
              return const AuthScreen();
            },
          ),
        );
      },
    );
  }
}

// --- ЕКРАН ВХОДУ (ГРАДІЄНТ І КРАСА) ---
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

  Future<void> signInWithGoogle() async {
    setState(() => isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) { setState(() => isLoading = false); return; }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) { _showError("Error: $e"); } finally { if (mounted) setState(() => isLoading = false); }
  }

  Future<void> signInWithFacebook() async {
    setState(() => isLoading = true);
    try {
      final LoginResult result = await FacebookAuth.instance.login();
      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        final credential = FacebookAuthProvider.credential(accessToken.tokenString);
        await FirebaseAuth.instance.signInWithCredential(credential);
      }
    } catch (e) { _showError("Error: $e"); } finally { if (mounted) setState(() => isLoading = false); }
  }

  Future<void> signInWithGitHub() async {
    setState(() => isLoading = true);
    try {
      GithubAuthProvider githubProvider = GithubAuthProvider();
      await FirebaseAuth.instance.signInWithProvider(githubProvider);
    } catch (e) { _showError("Error: $e"); } finally { if (mounted) setState(() => isLoading = false); }
  }

  Future<void> submitAuthForm() async {
    setState(() => isLoading = true);
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
      } else {
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
        if (nameController.text.isNotEmpty) { await userCredential.user!.updateDisplayName(nameController.text.trim()); }
      }
    } on FirebaseAuthException catch (e) { _showError(e.message ?? "Error"); } finally { if (mounted) setState(() => isLoading = false); }
  }

  void _showError(String message) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red)); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.green.shade50, Colors.white])),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.kitchen, size: 100, color: Colors.green.shade700),
                const SizedBox(height: 20),
                Text(
                  isLogin ? AppText.get('login_title') : AppText.get('signup_title'),
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green.shade900),
                ),
                const SizedBox(height: 10),
                Text(AppText.get('kitchen_helper'), style: const TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 40),

                if (!isLogin) ...[
                  _buildTextField(nameController, AppText.get('name_field'), Icons.person),
                  const SizedBox(height: 16),
                ],
                _buildTextField(emailController, 'Email', Icons.email, isEmail: true),
                const SizedBox(height: 16),
                _buildTextField(passwordController, AppText.get('password_field'), Icons.lock, isPassword: true),
                const SizedBox(height: 24),

                if (isLoading)
                  const CircularProgressIndicator()
                else
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: submitAuthForm,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 3),
                        child: Text(isLogin ? AppText.get('login_btn') : AppText.get('signup_btn'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () => setState(() => isLogin = !isLogin),
                        child: Text(
                          isLogin ? AppText.get('no_account') : AppText.get('has_account'),
                          style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 30),
                Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.all(8.0), child: Text(AppText.get('or'))), const Expanded(child: Divider())]),
                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _socialButton(icon: FontAwesomeIcons.google, color: Colors.red, onTap: signInWithGoogle),
                    const SizedBox(width: 25),
                    _socialButton(icon: FontAwesomeIcons.facebook, color: Colors.blue.shade800, onTap: signInWithFacebook),
                    const SizedBox(width: 25),
                    _socialButton(icon: FontAwesomeIcons.github, color: Colors.black, onTap: signInWithGitHub),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPassword = false, bool isEmail = false}) {
    return TextField(
      controller: controller, obscureText: isPassword, keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: Colors.green.shade700), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
    );
  }

  Widget _socialButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(50),
      child: Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 2))], border: Border.all(color: Colors.grey.shade200)), child: Center(child: FaIcon(icon, color: color, size: 28))),
    );
  }
}

// --- ГОЛОВНИЙ ЕКРАН З НАВІГАЦІЄЮ ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  static const List<Widget> _pages = <Widget>[
    FridgeContent(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        backgroundColor: Colors.green.shade50,
        indicatorColor: Colors.green.shade200,
        destinations: <Widget>[
          NavigationDestination(selectedIcon: const Icon(Icons.kitchen), icon: const Icon(Icons.kitchen_outlined), label: AppText.get('my_fridge')),
          NavigationDestination(selectedIcon: const Icon(Icons.person), icon: const Icon(Icons.person_outline), label: AppText.get('my_profile')),
        ],
      ),
    );
  }
}

// --- ВМІСТ ХОЛОДИЛЬНИКА ---
class FridgeContent extends StatefulWidget {
  const FridgeContent({super.key});
  @override
  State<FridgeContent> createState() => _FridgeContentState();
}

class _FridgeContentState extends State<FridgeContent> {
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              backgroundColor: Colors.white, surfaceTintColor: Colors.white, contentPadding: const EdgeInsets.all(24),
              title: Text(
                isEditing ? AppText.get('edit_product') : AppText.get('add_product'),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24), textAlign: TextAlign.center,
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController, style: const TextStyle(fontSize: 18),
                        decoration: InputDecoration(labelText: AppText.get('product_name'), hintText: 'Milk, Eggs...', prefixIcon: Icon(Icons.fastfood, color: Colors.green.shade700), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
                        autofocus: true,
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(AppText.get('days_valid'), style: const TextStyle(fontSize: 16, color: Colors.grey)),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(12)), child: Text("$daysToExpire", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade800, fontSize: 16))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(trackHeight: 8.0, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12.0), overlayShape: const RoundSliderOverlayShape(overlayRadius: 24.0), activeTrackColor: Colors.green, inactiveTrackColor: Colors.green.shade100, thumbColor: Colors.green.shade800),
                        child: Slider(value: daysToExpire.toDouble(), min: 1, max: 30, divisions: 29, onChanged: (val) => setDialogState(() => daysToExpire = val.toInt())),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(AppText.get('cancel'), style: const TextStyle(fontSize: 16, color: Colors.grey))),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isNotEmpty) {
                      final data = {'name': nameController.text.trim(), 'expirationDate': Timestamp.fromDate(DateTime.now().add(Duration(days: daysToExpire)))};
                      final collection = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products');
                      isEditing ? await collection.doc(productToEdit.id).update(data) : await collection.add({...data, 'addedDate': Timestamp.now()});
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(isEditing ? AppText.get('save') : AppText.get('add'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
      appBar: AppBar(backgroundColor: Colors.green.shade100, title: Text(AppText.get('my_fridge'), style: const TextStyle(fontWeight: FontWeight.bold)), centerTitle: true, elevation: 0),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products').orderBy('expirationDate').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.kitchen_outlined, size: 80, color: Colors.green.shade300), const SizedBox(height: 20), Text(AppText.get('empty_fridge'), style: const TextStyle(fontSize: 20, color: Colors.grey))]));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final product = Product.fromFirestore(docs[index]);
              Color statusColor = product.daysLeft < 3 ? Colors.red : (product.daysLeft < 7 ? Colors.orange : Colors.green);

              return Card(
                elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), margin: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: () => _showProductDialog(productToEdit: product),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                      leading: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(Icons.fastfood, color: statusColor, size: 28)),
                      title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      subtitle: Padding(padding: const EdgeInsets.only(top: 6.0), child: Row(children: [Icon(Icons.timer_outlined, size: 16, color: statusColor), const SizedBox(width: 4), Text("${AppText.get('days_left')} ${product.daysLeft}", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold))])),
                      trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey), onPressed: () => FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products').doc(product.id).delete()),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductDialog(),
        label: Text(AppText.get('add_product'), style: const TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
      ),
    );
  }
}