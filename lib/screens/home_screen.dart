import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../translations.dart';
import '../main.dart';
import '../household_service.dart';
import '../notification_service.dart';
import '../product_model.dart';
import 'shopping_list_screen.dart';
import 'profile_screen.dart';
import 'fridge_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = globalTabIndex;
  static const List<Widget> _pages = [FridgeContent(), ShoppingListScreen(), ProfileScreen()];

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<QuerySnapshot>? _productSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _loadInitialSettings();
    _initNotificationsAndCheckFridge();
  }

  Future<void> _initNotificationsAndCheckFridge() async {
    await NotificationService.init();
    _startListeningToFridge();
  }

  void _startListeningToFridge() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance.collection('users').doc(user.uid).get().then((doc) {
      if (!mounted) return;

      String? householdId;
      if (doc.exists && doc.data() != null) {
        householdId = (doc.data() as Map)['householdId'];
      }

      final collectionRef = householdId != null
          ? FirebaseFirestore.instance.collection('households').doc(householdId).collection('products')
          : FirebaseFirestore.instance.collection('users').doc(user.uid).collection('products');

      // 🔥 СЛУХАЄМО ЗМІНИ ТА ПЛАНУЄМО СПОВІЩЕННЯ
      _productSubscription = collectionRef.snapshots().listen((snapshot) {
        _scheduleAllNotifications(snapshot.docs);
      });
    });
  }

  // 🔥 ГОЛОВНА МАГІЯ ТУТ (ВИПРАВЛЕНО НА ПЕРЕКЛАД)
  void _scheduleAllNotifications(List<QueryDocumentSnapshot> docs) async {
    // 1. Спочатку скасовуємо всі старі, щоб не було дублів
    await NotificationService.cancelAll();

    int expiringCount = 0;
    String expiringNames = "";

    for (var doc in docs) {
      final product = Product.fromFirestore(doc);

      if (product.category == 'trash') continue;

      // 2. Якщо продукт ще свіжий, плануємо йому сповіщення на майбутнє
      await NotificationService.scheduleNotification(
          product.id.hashCode,
          product.name,
          product.expirationDate
      );

      // 3. Якщо продукт ВЖЕ зіпсувався або ось-ось (сьогодні-завтра), показуємо сповіщення зараз
      if (product.daysLeft <= 1 && product.daysLeft >= 0) {
        expiringCount++;
        if (expiringCount <= 3) expiringNames += "${product.name}, ";
      }
    }

    // Якщо є критичні продукти прямо зараз — кажемо про це
    if (expiringCount > 0) {
      if (expiringNames.endsWith(", ")) {
        expiringNames = expiringNames.substring(0, expiringNames.length - 2);
      }

      // ✅ ТУТ БУЛА ПОМИЛКА: Тепер беремо текст з перекладу!
      NotificationService.showInstantNotification(
          AppText.get('notif_batch_title'), // "Увага! Продукти псуються" (перекладене)
          "${AppText.get('notif_batch_body')} $expiringNames" // "Треба з'їсти: ..." (перекладене)
      );
    }
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    final Uri? initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) _handleLink(initialUri);
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) => _handleLink(uri));
  }

  void _handleLink(Uri uri) {
    if (uri.scheme == 'fridgify' && uri.host == 'invite') {
      final code = uri.queryParameters['code'];
      if (code != null) _showJoinDialog(code);
    }
  }

  void _showJoinDialog(String code) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: Theme.of(context).cardTheme.color,
      title: Text(AppText.get('fam_welcome_title')), // Використовуємо переклад
      content: Text("${AppText.get('fam_join')}: $code\n\n?"), // Спрощений переклад для діалогу
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppText.get('cancel'))),
        ElevatedButton(onPressed: () {
          Navigator.pop(ctx);
          HouseholdService().requestToJoin(code).then((_) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppText.get('req_sent')), backgroundColor: Colors.blue));
          }).catchError((e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${AppText.get('err_general')}: $e"), backgroundColor: Colors.red));
          });
        }, child: Text(AppText.get('fam_join')))
      ],
    ));
  }

  Future<void> _loadInitialSettings() async {
    // ...
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _productSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) { setState(() => _selectedIndex = i); globalTabIndex = i; },
        backgroundColor: null,
        destinations: <Widget>[
          NavigationDestination(selectedIcon: const Icon(Icons.kitchen), icon: const Icon(Icons.kitchen_outlined), label: ""),
          NavigationDestination(selectedIcon: const Icon(Icons.shopping_cart), icon: const Icon(Icons.shopping_cart_outlined), label: ""),
          NavigationDestination(selectedIcon: const Icon(Icons.person), icon: const Icon(Icons.person_outline), label: ""),
        ],
      ),
    );
  }
}