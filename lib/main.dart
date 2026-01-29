import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'translations.dart';
import 'notification_service.dart';
import 'fcm_service.dart';
import 'subscription_service.dart';
import 'global.dart'; // Якщо navigatorKey був тут, ми його перевизначимо в main для надійності

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

// 🔥 1. Глобальний ключ для навігації
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
int globalTabIndex = 0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("⚠️ Warning: .env file problem: $e");
  }

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🔥 2. Передаємо ключ у NotificationService
  await NotificationService.init(navigatorKey);
  await FCMService().init();
  await SubscriptionService().init();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await MobileAds.instance.initialize();
  }

  final prefs = await SharedPreferences.getInstance();
  final bool isDark = prefs.getBool('is_dark_mode') ?? false;
  final String savedLang = prefs.getString('language') ?? 'English';

  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  languageNotifier.value = savedLang;

  runApp(const SmartFridgeApp());
}

Locale getAppLocale(String langName) {
  switch (langName) {
    case 'Українська': return const Locale('uk', 'UA');
    case 'Español': return const Locale('es', 'ES');
    case 'Français': return const Locale('fr', 'FR');
    case 'Deutsch': return const Locale('de', 'DE');
    default: return const Locale('en', 'US');
  }
}

class SmartFridgeApp extends StatelessWidget {
  const SmartFridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        return ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, currentTheme, _) {
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'Fridgify',

                // 🔥 3. Прив'язуємо ключ до MaterialApp
                navigatorKey: navigatorKey,

                themeMode: currentTheme,
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light, surface: Colors.white),
                  useMaterial3: true,
                  scaffoldBackgroundColor: Colors.green.shade50,
                  appBarTheme: const AppBarTheme(
                      backgroundColor: Color(0xFFC8E6C9),
                      elevation: 0,
                      centerTitle: true,
                      titleTextStyle: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
                      iconTheme: IconThemeData(color: Colors.black)
                  ),
                  fontFamily: 'Roboto',
                  cardColor: Colors.white,
                  textTheme: const TextTheme(bodyLarge: TextStyle(color: Colors.black), bodyMedium: TextStyle(color: Colors.black87)),
                  navigationBarTheme: NavigationBarThemeData(
                      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                      height: 60,
                      backgroundColor: Colors.white,
                      indicatorColor: Colors.green.shade100,
                      iconTheme: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.selected) ? const IconThemeData(size: 28) : const IconThemeData(size: 26))
                  ),
                ),
                darkTheme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark, surface: const Color(0xFF1E1E1E), primary: Colors.green),
                  useMaterial3: true,
                  scaffoldBackgroundColor: const Color(0xFF121212),
                  appBarTheme: const AppBarTheme(
                      backgroundColor: Color(0xFF1E1E1E),
                      elevation: 0,
                      centerTitle: true,
                      titleTextStyle: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      iconTheme: IconThemeData(color: Colors.white)
                  ),
                  cardColor: const Color(0xFF1E1E1E),
                  fontFamily: 'Roboto',
                  textTheme: const TextTheme(bodyLarge: TextStyle(color: Colors.white), bodyMedium: TextStyle(color: Colors.white70)),
                  navigationBarTheme: NavigationBarThemeData(
                      labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
                      height: 60,
                      backgroundColor: const Color(0xFF1E1E1E),
                      indicatorColor: Colors.green.shade700,
                      iconTheme: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.selected) ? const IconThemeData(color: Colors.white, size: 28) : const IconThemeData(color: Colors.white70, size: 26))
                  ),
                ),

                locale: getAppLocale(lang),
                localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
                supportedLocales: const [Locale('en', 'US'), Locale('uk', 'UA'), Locale('es', 'ES'), Locale('fr', 'FR'), Locale('de', 'DE')],

                home: StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                    if (snapshot.hasData) return const HomeScreen();
                    return const AuthScreen();
                  },
                ),
              );
            }
        );
      },
    );
  }
}