import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:app_links/app_links.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'translations.dart';
import 'notification_service.dart';
import 'subscription_service.dart';
import 'ad_service.dart';
// 👇 Тут живуть наші змінні
import 'global.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

int globalTabIndex = 0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService().init();
  await SubscriptionService().init();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await MobileAds.instance.initialize();
  }

  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  final prefs = await SharedPreferences.getInstance();
  final bool isDark = prefs.getBool('is_dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;

  final savedLang = prefs.getString('language');
  if (savedLang != null) {
    languageNotifier.value = savedLang;
  }

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
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light, surface: Colors.white),
                  useMaterial3: true,
                  scaffoldBackgroundColor: Colors.green.shade50,
                  appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFC8E6C9), elevation: 0, centerTitle: true, titleTextStyle: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold), iconTheme: IconThemeData(color: Colors.black)),
                  fontFamily: 'Roboto',
                  cardColor: Colors.white,
                  textTheme: const TextTheme(bodyLarge: TextStyle(color: Colors.black), bodyMedium: TextStyle(color: Colors.black87)),
                  navigationBarTheme: NavigationBarThemeData(labelBehavior: NavigationDestinationLabelBehavior.alwaysHide, height: 60, backgroundColor: Colors.white, indicatorColor: Colors.green.shade100, iconTheme: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.selected) ? const IconThemeData(size: 28) : const IconThemeData(size: 26))),
                ),
                darkTheme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark, surface: const Color(0xFF1E1E1E), primary: Colors.green),
                  useMaterial3: true,
                  scaffoldBackgroundColor: const Color(0xFF121212),
                  appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E1E1E), elevation: 0, centerTitle: true, titleTextStyle: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), iconTheme: IconThemeData(color: Colors.white)),
                  cardColor: const Color(0xFF1E1E1E),
                  fontFamily: 'Roboto',
                  textTheme: const TextTheme(bodyLarge: TextStyle(color: Colors.white), bodyMedium: TextStyle(color: Colors.white70)),
                  navigationBarTheme: NavigationBarThemeData(labelBehavior: NavigationDestinationLabelBehavior.alwaysHide, height: 60, backgroundColor: const Color(0xFF1E1E1E), indicatorColor: Colors.green.shade700, iconTheme: MaterialStateProperty.resolveWith((states) => states.contains(MaterialState.selected) ? const IconThemeData(color: Colors.white, size: 28) : const IconThemeData(color: Colors.white70, size: 26))),
                ),
                themeMode: currentTheme,
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