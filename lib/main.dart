import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 👇 ОБОВ'ЯЗКОВО

import 'firebase_options.dart';
import 'translations.dart';
import 'notification_service.dart';
import 'subscription_service.dart';
import 'ad_service.dart';
import 'global.dart'; // Тут лежать themeNotifier

// 👇 Перевір назви своїх файлів
import 'screens/auth_screen.dart'; // Або login_screen.dart
import 'screens/home_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

int globalTabIndex = 0;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Завантаження .env (ігноруємо помилку, якщо файлу немає в релізі)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("⚠️ Warning: .env file problem: $e");
  }

  // 2. Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 3. Сервіси
  await NotificationService.init();
  await SubscriptionService().init();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await MobileAds.instance.initialize();
  }

  // 4. Сповіщення
  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // 🔥 5. ГОЛОВНЕ ВИПРАВЛЕННЯ: Читаємо тему з пам'яті ПЕРЕД запуском
  final prefs = await SharedPreferences.getInstance();

  // Читаємо тему (якщо немає запису, то false = світла)
  final bool isDark = prefs.getBool('is_dark_mode') ?? false;

  // Читаємо мову
  final String savedLang = prefs.getString('language') ?? 'English';

  // Встановлюємо глобальні змінні
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  languageNotifier.value = savedLang;

  // 6. Запускаємо додаток
  runApp(const SmartFridgeApp());
}

// Допоміжна функція для локалі
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
    // Слухаємо зміни мови
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        // Слухаємо зміни теми
        return ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, currentTheme, _) {
              return MaterialApp(
                debugShowCheckedModeBanner: false,
                title: 'Fridgify',

                // 👇 Підключаємо тему з notifyer'а
                themeMode: currentTheme,

                // Налаштування Світлої теми
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

                // Налаштування Темної теми
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
                    // Якщо файл входу називається login_screen.dart - зміни тут на LoginScreen()
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