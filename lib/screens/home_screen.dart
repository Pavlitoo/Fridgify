import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../translations.dart';
import '../main.dart'; // Щоб мати доступ до globalTabIndex
import '../household_service.dart';
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

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _loadInitialSettings();
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
      backgroundColor: Theme.of(context).cardColor,
      title: const Text("Вступ у сім'ю 🏠"),
      content: Text("Знайдено код запрошення:\n$code\n\nБажаєте приєднатися?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppText.get('cancel'))),
        ElevatedButton(onPressed: () { Navigator.pop(ctx); HouseholdService().requestToJoin(code).then((_) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppText.get('req_sent')), backgroundColor: Colors.blue)); }).catchError((e) { ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Помилка: $e"), backgroundColor: Colors.red)); }); }, child: const Text("Приєднатися"))
      ],
    ));
  }

  Future<void> _loadInitialSettings() async {
    // ... (старий код)
  }

  @override
  void dispose() { _linkSubscription?.cancel(); super.dispose(); }

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