import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 🆕 IMPORT

import 'firebase_options.dart';
import 'product_model.dart';
import 'profile_screen.dart';
import 'translations.dart';
import 'notification_service.dart';
import 'shopping_list_screen.dart';
import 'ai_service.dart'; // 🆕 IMPORT

// ----------------------------------------

// Helper class for Categories
class CategoryData {
  final String id;
  final IconData icon;
  final Color color;
  final String labelKey;

  CategoryData(this.id, this.icon, this.color, this.labelKey);
}

// List of all categories
final List<CategoryData> appCategories = [
  CategoryData('other', Icons.fastfood, Colors.grey, 'cat_other'),
  CategoryData('meat', Icons.set_meal, Colors.red, 'cat_meat'),
  CategoryData('veg', Icons.eco, Colors.green, 'cat_veg'),
  CategoryData('fruit', Icons.emoji_food_beverage, Colors.orange, 'cat_fruit'),
  CategoryData('dairy', Icons.egg, Colors.blueGrey, 'cat_dairy'),
  CategoryData('bakery', Icons.breakfast_dining, Colors.brown, 'cat_bakery'),
  CategoryData('sweet', Icons.cake, Colors.pink, 'cat_sweet'),
  CategoryData('drink', Icons.local_drink, Colors.blue, 'cat_drink'),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 👇 Load environment variables (API Keys)
  await dotenv.load(fileName: ".env");

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().init();
  runApp(const SmartFridgeApp());
}

class SmartFridgeApp extends StatelessWidget {
  const SmartFridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Smart Fridge',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light),
            useMaterial3: true,
            fontFamily: 'Roboto',
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

// --- AUTH SCREEN ---
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
    } catch (e) { if(mounted) _showError("Error: $e"); } finally { if (mounted) setState(() => isLoading = false); }
  }

  Future<void> signInWithGitHub() async {
    setState(() => isLoading = true);
    try {
      GithubAuthProvider githubProvider = GithubAuthProvider();
      await FirebaseAuth.instance.signInWithProvider(githubProvider);
    } catch (e) { if (mounted) _showError("Error: $e"); } finally { if (mounted) setState(() => isLoading = false); }
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
    } on FirebaseAuthException catch (e) { if(mounted) _showError(e.message ?? "Error"); } finally { if (mounted) setState(() => isLoading = false); }
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
              children: [
                Image.asset('assets/logo.png', height: 120),
                const SizedBox(height: 20),
                Text(isLogin ? AppText.get('login_title') : AppText.get('signup_title'), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                const SizedBox(height: 40),
                if (!isLogin) ...[ _buildTextField(nameController, AppText.get('name_field'), Icons.person), const SizedBox(height: 16) ],
                _buildTextField(emailController, 'Email', Icons.email, isEmail: true),
                const SizedBox(height: 16),
                _buildTextField(passwordController, AppText.get('password_field'), Icons.lock, isPassword: true),
                const SizedBox(height: 24),
                if (isLoading) const CircularProgressIndicator() else Column(children: [
                  ElevatedButton(onPressed: submitAuthForm, style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 3), child: Text(isLogin ? AppText.get('login_btn') : AppText.get('signup_btn'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  const SizedBox(height: 10),
                  TextButton(onPressed: () => setState(() => isLogin = !isLogin), child: Text(isLogin ? AppText.get('no_account') : AppText.get('has_account'), style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 30),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [_socialButton(icon: FontAwesomeIcons.google, color: Colors.red, onTap: signInWithGoogle), const SizedBox(width: 30), _socialButton(icon: FontAwesomeIcons.github, color: Colors.black, onTap: signInWithGitHub)]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {bool isPassword = false, bool isEmail = false}) {
    return TextField(controller: controller, obscureText: isPassword, keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text, decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, color: Colors.green.shade700), filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)));
  }

  Widget _socialButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(50), child: Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 2))], border: Border.all(color: Colors.grey.shade200)), child: Center(child: FaIcon(icon, color: color, size: 28))));
  }
}

// --- HOME SCREEN ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  static const List<Widget> _pages = <Widget>[
    FridgeContent(),
    ShoppingListScreen(),
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
          NavigationDestination(selectedIcon: const Icon(Icons.shopping_cart), icon: const Icon(Icons.shopping_cart_outlined), label: AppText.get('shopping_list')),
          NavigationDestination(selectedIcon: const Icon(Icons.person), icon: const Icon(Icons.person_outline), label: AppText.get('my_profile')),
        ],
      ),
    );
  }
}

// --- FRIDGE CONTENT ---
class FridgeContent extends StatefulWidget {
  const FridgeContent({super.key});
  @override
  State<FridgeContent> createState() => _FridgeContentState();
}

class _FridgeContentState extends State<FridgeContent> {
  final user = FirebaseAuth.instance.currentUser!;
  final Set<String> _selectedProductIds = {};
  final List<String> _selectedProductNames = [];
  String _selectedCategoryFilter = 'all';

  void _toggleSelection(String id, String name) {
    setState(() {
      if (_selectedProductIds.contains(id)) {
        _selectedProductIds.remove(id);
        _selectedProductNames.remove(name);
      } else {
        _selectedProductIds.add(id);
        _selectedProductNames.add(name);
      }
    });
  }

  Future<void> _logHistory(String action, String productName) async {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('history').add({
      'action': action,
      'product': productName,
      'date': Timestamp.now(),
    });
  }

  void _confirmDeleteOrMove(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppText.get('delete_title'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(AppText.get('delete_msg'), textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _actionButton(Icons.sentiment_very_satisfied, Colors.green, AppText.get('action_eaten'), () {
                _logHistory('eaten', product.name);
                _deleteProduct(product);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppText.get('action_eaten')}! +1 🌿"), backgroundColor: Colors.green));
              }),
              _actionButton(Icons.delete_forever, Colors.redAccent, AppText.get('action_wasted'), () {
                _logHistory('wasted', product.name);
                _deleteProduct(product);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppText.get('action_wasted')} 😞"), backgroundColor: Colors.redAccent));
              }),
              _actionButton(Icons.add_shopping_cart, Colors.blue, "List", () async {
                _logHistory('eaten', product.name);
                await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('shopping_list').add({
                  'name': product.name, 'isBought': false, 'addedDate': Timestamp.now(),
                });
                _deleteProduct(product);
                if(mounted) Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Moved to List! 🛒"), backgroundColor: Colors.blue));
              }),
            ],
          )
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, Color color, String label, VoidCallback onTap) {
    return Column(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: Icon(icon, color: color, size: 36), onPressed: onTap), Text(label, style: const TextStyle(fontSize: 12))]);
  }

  void _deleteProduct(Product product) {
    NotificationService().cancelNotification(product.id.hashCode);
    FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products').doc(product.id).delete();
  }

  // 👇 SEARCH RECIPES VIA AI
  Future<void> _searchRecipes() async {
    final ingredients = _selectedProductNames.join(', ');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(AppText.get('loading'), style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text("AI Chef працює... 👨‍🍳", style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final settings = userDoc.data()?['settings'] ?? {};

      final bool isVeg = settings['is_vegetarian'] ?? false;
      final bool isGluten = settings['is_gluten_free'] ?? false;
      final bool isQuick = settings['is_quick'] ?? false;

      String diet = "";
      if (isVeg) diet += "vegetarian, ";
      if (isGluten) diet += "gluten free, ";
      if (isQuick) diet += "quick meal";

      // CALL AI SERVICE
      final recipes = await AiRecipeService().getRecipes(
        ingredients: _selectedProductNames,
        userLanguage: languageNotifier.value,
        diet: diet,
      );

      Navigator.pop(context);

      if (recipes.isNotEmpty) {
        _showResults(recipes);
        setState(() { _selectedProductIds.clear(); _selectedProductNames.clear(); });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("AI не зміг придумати рецепт, спробуйте ще раз 🤔"), backgroundColor: Colors.orange));
      }
    } catch (e) {
      if(mounted && Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  void _showResults(List<Map<String, dynamic>> recipes) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
          builder: (_, controller) {
            return Column(children: [
              const SizedBox(height: 10), Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
              Padding(padding: const EdgeInsets.all(16.0), child: Text(AppText.get('recipe_title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green))),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = recipes[index];
                    final missingList = List<String>.from(recipe['missingIngredients'] ?? []);

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(recipe['emoji'] ?? '🍳', style: const TextStyle(fontSize: 40)),
                                const SizedBox(width: 12),
                                Expanded(child: Text(recipe['title'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(recipe['description'] ?? '', style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
                            const Divider(height: 20),

                            if (missingList.isNotEmpty) ...[
                              Text("${AppText.get('missed')} (${missingList.length})", style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Wrap(spacing: 6, children: missingList.map((ing) => Chip(label: Text(ing, style: const TextStyle(fontSize: 12)), backgroundColor: Colors.orange.shade50, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact)).toList()),
                              const SizedBox(height: 10),
                            ],

                            ExpansionTile(
                              title: const Text("Інструкція", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(recipe['instructions'] ?? 'No instructions', style: const TextStyle(fontSize: 14, height: 1.4)),
                                )
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]);
          },
        );
      },
    );
  }

  void _showProductDialog({Product? productToEdit}) {
    final nameController = TextEditingController(text: productToEdit?.name ?? '');
    int daysToExpire = productToEdit?.daysLeft ?? 7;
    if (daysToExpire < 1) daysToExpire = 1; if (daysToExpire > 30) daysToExpire = 30;
    final isEditing = productToEdit != null;
    String selectedCategory = productToEdit?.category ?? 'other';

    showDialog(context: context, builder: (context) { return StatefulBuilder(builder: (context, setDialogState) { return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)), backgroundColor: Colors.white, surfaceTintColor: Colors.white, contentPadding: const EdgeInsets.all(24),
        title: Text(isEditing ? AppText.get('edit_product') : AppText.get('add_product'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24), textAlign: TextAlign.center),
        content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: nameController, style: const TextStyle(fontSize: 18), decoration: InputDecoration(labelText: AppText.get('product_name'), prefixIcon: const Icon(Icons.edit, color: Colors.green), filled: true, fillColor: Colors.grey.shade50, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none)), autofocus: true),
          const SizedBox(height: 24),
          Text(AppText.get('category_label'), style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 10, children: appCategories.map((cat) {
            final isSelected = selectedCategory == cat.id;
            return InkWell(onTap: () => setDialogState(() => selectedCategory = cat.id), child: Column(mainAxisSize: MainAxisSize.min, children: [AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isSelected ? cat.color : Colors.grey.shade100, shape: BoxShape.circle, boxShadow: isSelected ? [BoxShadow(color: cat.color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : []), child: Icon(cat.icon, color: isSelected ? Colors.white : Colors.grey, size: 28)), const SizedBox(height: 4), Text(AppText.get(cat.labelKey), style: TextStyle(fontSize: 10, color: isSelected ? cat.color : Colors.grey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal))]));
          }).toList()),
          const SizedBox(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(AppText.get('days_valid'), style: const TextStyle(fontSize: 16, color: Colors.grey)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Text("$daysToExpire ${AppText.get('days_count')}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)))]),
          const SizedBox(height: 10),
          SliderTheme(data: SliderTheme.of(context).copyWith(activeTrackColor: Colors.green, inactiveTrackColor: Colors.green.shade100, trackShape: const RoundedRectSliderTrackShape(), trackHeight: 12.0, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 15.0), thumbColor: Colors.white, overlayColor: Colors.green.withAlpha(32), overlayShape: const RoundSliderOverlayShape(overlayRadius: 28.0), tickMarkShape: const RoundSliderTickMarkShape(), activeTickMarkColor: Colors.green.shade200, inactiveTickMarkColor: Colors.green.shade100, valueIndicatorShape: const PaddleSliderValueIndicatorShape(), valueIndicatorColor: Colors.green, valueIndicatorTextStyle: const TextStyle(color: Colors.white)), child: Slider(value: daysToExpire.toDouble(), min: 1, max: 30, divisions: 29, label: "$daysToExpire", onChanged: (val) => setDialogState(() => daysToExpire = val.toInt()))),
        ]))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(AppText.get('cancel'), style: const TextStyle(fontSize: 16))),
          ElevatedButton(onPressed: () async { if (nameController.text.isNotEmpty) {
            final expDate = DateTime.now().add(Duration(days: daysToExpire));
            final data = {'name': nameController.text.trim(), 'expirationDate': Timestamp.fromDate(expDate), 'category': selectedCategory};
            final collection = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products');
            if (isEditing) {
              await collection.doc(productToEdit.id).update(data);
              NotificationService().cancelNotification(productToEdit.id.hashCode);
              NotificationService().scheduleNotification(productToEdit.id.hashCode, nameController.text.trim(), expDate);
            } else {
              final docRef = await collection.add({...data, 'addedDate': Timestamp.now()});
              NotificationService().scheduleNotification(docRef.id.hashCode, nameController.text.trim(), expDate);
            }
            Navigator.pop(context);
          }}, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(isEditing ? AppText.get('save') : AppText.get('add'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
        ]);});});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(backgroundColor: Colors.green.shade100, title: Text(AppText.get('my_fridge'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24)), centerTitle: true, elevation: 0),
      body: Column(children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(children: [_filterChip('all', AppText.get('cat_all'), Icons.grid_view, Colors.black87), ...appCategories.map((cat) => _filterChip(cat.id, AppText.get(cat.labelKey), cat.icon, cat.color))])),
        Expanded(child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products').orderBy('expirationDate').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final allDocs = snapshot.data!.docs;
              final docs = _selectedCategoryFilter == 'all' ? allDocs : allDocs.where((doc) => (doc.data() as Map<String, dynamic>)['category'] == _selectedCategoryFilter).toList();
              if (docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.kitchen_outlined, size: 100, color: Colors.green.shade200), const SizedBox(height: 20), Text(AppText.get('empty_fridge'), style: const TextStyle(fontSize: 22, color: Colors.grey))]));
              return ListView.builder(padding: const EdgeInsets.all(16), itemCount: docs.length, itemBuilder: (context, index) {
                final product = Product.fromFirestore(docs[index]);
                final isSelected = _selectedProductIds.contains(product.id);
                Color statusColor = product.daysLeft < 3 ? Colors.red : (product.daysLeft < 7 ? Colors.orange : Colors.green);
                final catData = appCategories.firstWhere((c) => c.id == product.category, orElse: () => appCategories[0]);
                return SlideInAnimation(delay: index * 100, child: Card(color: isSelected ? Colors.green.shade100 : Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: isSelected ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none), elevation: isSelected ? 0 : 4, margin: const EdgeInsets.only(bottom: 16), child: InkWell(onTap: () => _toggleSelection(product.id, product.name), onLongPress: () => _showProductDialog(productToEdit: product), borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0), child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 16), leading: isSelected ? const Icon(Icons.check_circle, color: Colors.green, size: 36) : Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: catData.color.withOpacity(0.15), shape: BoxShape.circle), child: Icon(catData.icon, color: catData.color, size: 32)), title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)), subtitle: Padding(padding: const EdgeInsets.only(top: 6.0), child: Row(children: [Icon(Icons.timer_outlined, size: 18, color: statusColor), const SizedBox(width: 6), Text("${AppText.get('days_left')} ${product.daysLeft}", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16))])), trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 28), onPressed: () => _confirmDeleteOrMove(product)))))));
              });
            })),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _selectedProductIds.isNotEmpty ? _searchRecipes : () => _showProductDialog(), label: Text(_selectedProductIds.isNotEmpty ? AppText.get('cook_btn') : AppText.get('add_product'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), icon: Icon(_selectedProductIds.isNotEmpty ? Icons.restaurant_menu : Icons.add, size: 28), backgroundColor: _selectedProductIds.isNotEmpty ? Colors.deepOrange : Colors.green.shade600, foregroundColor: Colors.white, elevation: 4),
    );
  }

  Widget _filterChip(String id, String label, IconData icon, Color color) {
    final isSelected = _selectedCategoryFilter == id;
    return Padding(padding: const EdgeInsets.only(right: 10), child: InkWell(onTap: () => setState(() => _selectedCategoryFilter = id), borderRadius: BorderRadius.circular(20), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: isSelected ? color : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isSelected ? color : Colors.grey.shade300), boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 3))] : []), child: Row(children: [Icon(icon, size: 18, color: isSelected ? Colors.white : Colors.grey), const SizedBox(width: 8), Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))]))));
  }
}

// Animation
class SlideInAnimation extends StatefulWidget {
  final Widget child;
  final int delay;
  const SlideInAnimation({super.key, required this.child, required this.delay});
  @override
  State<SlideInAnimation> createState() => _SlideInAnimationState();
}
class _SlideInAnimationState extends State<SlideInAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnim;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 500), vsync: this);
    _offsetAnim = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    Future.delayed(Duration(milliseconds: widget.delay), () { if(mounted) _controller.forward(); });
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) { return FadeTransition(opacity: _controller, child: SlideTransition(position: _offsetAnim, child: widget.child)); }
}