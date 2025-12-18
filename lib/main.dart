import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'firebase_options.dart';
import 'product_model.dart';
import 'profile_screen.dart';
import 'translations.dart';
import 'notification_service.dart';
import 'shopping_list_screen.dart';

// 👇 YOUR SPOONACULAR KEY
const String spoonacularApiKey = '0699d942fb5e4acaa71980cc7207cef0';
// ----------------------------------------

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize notifications
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

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      if(mounted) _showError("Error: $e");
    } finally {
      if(mounted) setState(() => isLoading = false);
    }
  }

  Future<void> signInWithGitHub() async {
    setState(() => isLoading = true);
    try {
      GithubAuthProvider githubProvider = GithubAuthProvider();
      await FirebaseAuth.instance.signInWithProvider(githubProvider);
    } catch (e) { if(mounted) _showError("Error: $e"); } finally { if(mounted) setState(() => isLoading = false); }
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
    } on FirebaseAuthException catch (e) { if(mounted) _showError(e.message ?? "Error"); } finally { if(mounted) setState(() => isLoading = false); }
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
                Icon(Icons.kitchen, size: 100, color: Colors.green.shade700),
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

  final Map<String, IconData> _categoryIcons = {
    'other': Icons.fastfood, 'meat': Icons.set_meal, 'veg': Icons.eco, 'fruit': Icons.emoji_food_beverage,
    'dairy': Icons.egg, 'bakery': Icons.breakfast_dining, 'sweet': Icons.cake, 'drink': Icons.local_drink,
  };
  final Map<String, Color> _categoryColors = {
    'other': Colors.grey, 'meat': Colors.red, 'veg': Colors.green, 'fruit': Colors.orange,
    'dairy': Colors.blueGrey, 'bakery': Colors.brown, 'sweet': Colors.pink, 'drink': Colors.blue,
  };

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

  // Confirm deletion or move to shopping list
  void _confirmDeleteOrMove(Product product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppText.get('delete_title'), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(AppText.get('delete_msg'), textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          // Just delete
          TextButton(
            onPressed: () {
              NotificationService().cancelNotification(product.id.hashCode);
              FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products').doc(product.id).delete();
              Navigator.pop(ctx);
            },
            child: Text(AppText.get('no_delete'), style: const TextStyle(color: Colors.grey)),
          ),
          // Move to list
          ElevatedButton.icon(
            onPressed: () async {
              // 1. Add to shopping list
              await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('shopping_list').add({
                'name': product.name,
                'isBought': false,
                'addedDate': Timestamp.now(),
              });
              // 2. Delete from fridge
              NotificationService().cancelNotification(product.id.hashCode);
              FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products').doc(product.id).delete();

              if(mounted) Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Moved to Shopping List! 🛒"), backgroundColor: Colors.green));
            },
            icon: const Icon(Icons.shopping_cart),
            label: Text(AppText.get('yes_list')),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  // SPOONACULAR SEARCH
  Future<void> _searchRecipes() async {
    final ingredients = _selectedProductNames.join(',');
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => Center(child: Card(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(), const SizedBox(height: 20), Text(AppText.get('loading'))])))));

    try {
      final uri = Uri.parse('https://api.spoonacular.com/recipes/findByIngredients?ingredients=$ingredients&number=10&ranking=1&apiKey=$spoonacularApiKey');
      final response = await http.get(uri);
      Navigator.pop(context);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _showResults(data);
        setState(() { _selectedProductIds.clear(); _selectedProductNames.clear(); });
      } else { throw Exception('API Error: ${response.statusCode}'); }
    } catch (e) {
      if(mounted && Navigator.canPop(context)) Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppText.get('error')}: $e"), backgroundColor: Colors.red));
    }
  }

  void _showResults(List<dynamic> recipes) {
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
                child: recipes.isEmpty
                    ? const Center(child: Text("Nothing found 😔"))
                    : ListView.builder(
                  controller: controller,
                  itemCount: recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = recipes[index];
                    final missedCount = recipe['missedIngredientCount'];
                    final List<dynamic> missedList = recipe['missedIngredients'] ?? [];
                    final String missedString = missedList.map((e) => e['originalName'] ?? e['name']).join(', ');

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      elevation: 3,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final id = recipe['id'];
                          final title = recipe['title'].toString().replaceAll(' ', '-');
                          final url = Uri.parse("https://spoonacular.com/recipes/$title-$id");
                          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open link")));
                          }
                        },
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(16)), child: Image.network(recipe['image'], height: 180, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c,e,s) => Container(height: 150, color: Colors.grey[300], child: const Icon(Icons.broken_image)))),
                          Padding(padding: const EdgeInsets.all(16.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(recipe['title'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            if (missedCount > 0) ...[
                              Text("${AppText.get('missed')} ($missedCount)", style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(missedString, style: TextStyle(color: Colors.grey[700], fontSize: 14))
                            ] else const Text("You have everything! ✅", style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 15),
                            SizedBox(width: double.infinity, child: ElevatedButton.icon(icon: const Icon(Icons.menu_book, color: Colors.white), label: const Text("Read Recipe", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () async {
                              final id = recipe['id']; final title = recipe['title'].toString().replaceAll(' ', '-'); final url = Uri.parse("https://spoonacular.com/recipes/$title-$id"); await launchUrl(url, mode: LaunchMode.externalApplication);
                            })),
                          ])),
                        ]),
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
          const Text("Category:", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 10, children: _categoryIcons.entries.map((entry) {
            final isSelected = selectedCategory == entry.key;
            return InkWell(onTap: () => setDialogState(() => selectedCategory = entry.key), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: isSelected ? _categoryColors[entry.key] : Colors.grey.shade100, shape: BoxShape.circle, boxShadow: isSelected ? [BoxShadow(color: _categoryColors[entry.key]!.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))] : []), child: Icon(entry.value, color: isSelected ? Colors.white : Colors.grey, size: 28)));
          }).toList()),
          const SizedBox(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(AppText.get('days_valid'), style: const TextStyle(fontSize: 16, color: Colors.grey)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Text("$daysToExpire days", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 18)))]),
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
              // Update notification
              NotificationService().cancelNotification(productToEdit.id.hashCode);
              NotificationService().scheduleNotification(productToEdit.id.hashCode, nameController.text.trim(), expDate);
            } else {
              final docRef = await collection.add({...data, 'addedDate': Timestamp.now()});
              // Schedule notification
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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products').orderBy('expirationDate').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.kitchen_outlined, size: 100, color: Colors.green.shade200), const SizedBox(height: 20), Text(AppText.get('empty_fridge'), style: const TextStyle(fontSize: 22, color: Colors.grey))]));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final product = Product.fromFirestore(docs[index]);
              final isSelected = _selectedProductIds.contains(product.id);
              Color statusColor = product.daysLeft < 3 ? Colors.red : (product.daysLeft < 7 ? Colors.orange : Colors.green);
              final iconData = _categoryIcons[product.category] ?? Icons.fastfood;
              final iconColor = _categoryColors[product.category] ?? Colors.green;

              return SlideInAnimation(
                delay: index * 100,
                child: Card(
                  color: isSelected ? Colors.green.shade100 : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: isSelected ? const BorderSide(color: Colors.green, width: 2) : BorderSide.none),
                  elevation: isSelected ? 0 : 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: InkWell(
                    onTap: () => _toggleSelection(product.id, product.name),
                    onLongPress: () => _showProductDialog(productToEdit: product),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        leading: isSelected
                            ? const Icon(Icons.check_circle, color: Colors.green, size: 36)
                            : Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: iconColor.withOpacity(0.15), shape: BoxShape.circle), child: Icon(iconData, color: iconColor, size: 32)),
                        title: Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                        subtitle: Padding(padding: const EdgeInsets.only(top: 6.0), child: Row(children: [Icon(Icons.timer_outlined, size: 18, color: statusColor), const SizedBox(width: 6), Text("${AppText.get('days_left')} ${product.daysLeft}", style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 16))])),
                        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 28), onPressed: () => _confirmDeleteOrMove(product)),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _selectedProductIds.isNotEmpty ? _searchRecipes : () => _showProductDialog(),
        label: Text(_selectedProductIds.isNotEmpty ? AppText.get('cook_btn') : AppText.get('add_product'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        icon: Icon(_selectedProductIds.isNotEmpty ? Icons.restaurant_menu : Icons.add, size: 28),
        backgroundColor: _selectedProductIds.isNotEmpty ? Colors.deepOrange : Colors.green.shade600,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }
}

// Animation Widget
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