import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../translations.dart';
import '../main.dart';
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

  static const List<Widget> _pages = [
    FridgeContent(),
    ShoppingListScreen(),
    ProfileScreen()
  ];

  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
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
      title: Text(AppText.get('fam_welcome_title')),
      content: Text("${AppText.get('fam_join')}: $code?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppText.get('cancel'))),
        ElevatedButton(onPressed: () {
          Navigator.pop(ctx);
          HouseholdService().requestToJoin(code).then((_) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(AppText.get('req_sent')), backgroundColor: Colors.blue)
            );
          }).catchError((e) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("${AppText.get('err_general')}: $e"), backgroundColor: Colors.red)
            );
          });
        }, child: Text(AppText.get('fam_join')))
      ],
    ));
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🔥 ФІКС: Використовуємо IndexedStack для миттєвого перемикання без лагів
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) {
          setState(() => _selectedIndex = i);
          globalTabIndex = i;
        },
        // 🔥 ФІКС: Прибираємо зайві кольорові ефекти
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).navigationBarTheme.backgroundColor,
        destinations: const <Widget>[
          NavigationDestination(
              selectedIcon: Icon(Icons.kitchen),
              icon: Icon(Icons.kitchen_outlined),
              label: ""
          ),
          NavigationDestination(
              selectedIcon: Icon(Icons.shopping_cart),
              icon: Icon(Icons.shopping_cart_outlined),
              label: ""
          ),
          NavigationDestination(
              selectedIcon: Icon(Icons.person),
              icon: Icon(Icons.person_outline),
              label: ""
          ),
        ],
      ),
    );
  }
}