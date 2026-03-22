import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'translations.dart';
import 'notification_service.dart';
// 🔥 ІМПОРТ CHATPUSHSERVICE ВИДАЛЕНО
import 'subscription_service.dart';
import 'global.dart';

import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/no_internet_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
int globalTabIndex = 0;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrapper());
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

class AppBootstrapper extends StatefulWidget {
  const AppBootstrapper({Key? key}) : super(key: key);

  @override
  State<AppBootstrapper> createState() => _AppBootstrapperState();
}

class _AppBootstrapperState extends State<AppBootstrapper> {
  bool _isCoreInitialized = false;
  bool _hasInternet = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _startApp();
  }

  Future<void> _startApp() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final bool isDark = prefs.getBool('is_dark_mode') ?? false;
      final String savedLang = prefs.getString('language') ?? 'English';

      themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
      languageNotifier.value = savedLang;
    } catch (e) {
      debugPrint("Prefs error: $e");
    }

    bool hasRealInternet = false;
    try {
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 4));
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        hasRealInternet = true;
      }
    } catch (_) {
      hasRealInternet = false;
    }

    if (!mounted) return;

    if (!hasRealInternet) {
      setState(() { _hasInternet = false; _isLoading = false; });
      return;
    }

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

    try {
      await NotificationService.init(navigatorKey);
      // 🔥 ВИКЛИК CHATPUSHSERVICE.INIT ВИДАЛЕНО
      await SubscriptionService().init();
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        await MobileAds.instance.initialize();
      }
    } catch (e) {
      debugPrint("Services init error: $e");
    }

    await Future.delayed(const Duration(milliseconds: 800));

    if (mounted) {
      setState(() { _hasInternet = true; _isCoreInitialized = true; _isLoading = false; });

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future.delayed(const Duration(milliseconds: 1000));
        try {
          final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
          if (initialMessage != null) {
            debugPrint("🔥 Запущено з пуша: ${initialMessage.data}");
          }
        } catch (e) {
          debugPrint("Помилка обробки initialMessage: $e");
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.green.shade50,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/logo.png', width: 150, errorBuilder: (context, error, stackTrace) => const Icon(Icons.kitchen, size: 80, color: Colors.green)),
                const SizedBox(height: 40),
                SizedBox(width: 200, height: 6, child: ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(backgroundColor: Colors.green.withValues(alpha: 0.2), valueColor: const AlwaysStoppedAnimation<Color>(Colors.green)))),
              ],
            ),
          ),
        ),
      );
    }

    if (!_hasInternet) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: themeNotifier.value,
        theme: ThemeData(scaffoldBackgroundColor: Colors.green.shade50),
        darkTheme: ThemeData(scaffoldBackgroundColor: const Color(0xFF121212)),
        home: NoInternetScreen(onRetry: _startApp),
      );
    }

    if (_isCoreInitialized) return const SmartFridgeApp();
    return const SizedBox();
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
                navigatorKey: navigatorKey,
                themeMode: currentTheme,

                // СВІТЛА ТЕМА
                theme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.light, surface: Colors.white),
                  useMaterial3: true,
                  scaffoldBackgroundColor: Colors.green.shade50,
                  canvasColor: Colors.green.shade50,
                  pageTransitionsTheme: const PageTransitionsTheme(
                    builders: {
                      TargetPlatform.android: ZoomPageTransitionsBuilder(allowEnterRouteSnapshotting: false),
                      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                    },
                  ),
                  appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFC8E6C9), elevation: 0, centerTitle: true, titleTextStyle: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold), iconTheme: IconThemeData(color: Colors.black)),
                  fontFamily: 'Roboto',
                  cardColor: Colors.white,
                  textTheme: const TextTheme(bodyLarge: TextStyle(color: Colors.black), bodyMedium: TextStyle(color: Colors.black87)),
                  navigationBarTheme: NavigationBarThemeData(labelBehavior: NavigationDestinationLabelBehavior.alwaysHide, height: 60, backgroundColor: Colors.white, indicatorColor: Colors.green.shade100, iconTheme: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? const IconThemeData(size: 28) : const IconThemeData(size: 26))),
                ),

                // ТЕМНА ТЕМА
                darkTheme: ThemeData(
                  colorScheme: ColorScheme.fromSeed(seedColor: Colors.green, brightness: Brightness.dark, surface: const Color(0xFF1E1E1E), primary: Colors.green),
                  useMaterial3: true,
                  scaffoldBackgroundColor: const Color(0xFF121212),
                  canvasColor: const Color(0xFF121212),
                  pageTransitionsTheme: const PageTransitionsTheme(
                    builders: {
                      TargetPlatform.android: ZoomPageTransitionsBuilder(allowEnterRouteSnapshotting: false),
                      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                    },
                  ),
                  appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E1E1E), elevation: 0, centerTitle: true, titleTextStyle: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold), iconTheme: IconThemeData(color: Colors.white)),
                  cardColor: const Color(0xFF1E1E1E),
                  fontFamily: 'Roboto',
                  textTheme: const TextTheme(bodyLarge: TextStyle(color: Colors.white), bodyMedium: TextStyle(color: Colors.white70)),
                  navigationBarTheme: NavigationBarThemeData(labelBehavior: NavigationDestinationLabelBehavior.alwaysHide, height: 60, backgroundColor: const Color(0xFF1E1E1E), indicatorColor: Colors.green.shade700, iconTheme: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? const IconThemeData(color: Colors.white, size: 28) : const IconThemeData(color: Colors.white70, size: 26))),
                ),

                locale: getAppLocale(lang),
                localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
                supportedLocales: const [Locale('en', 'US'), Locale('uk', 'UA'), Locale('es', 'ES'), Locale('fr', 'FR'), Locale('de', 'DE')],

                home: StreamBuilder<User?>(
                  stream: FirebaseAuth.instance.authStateChanges(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
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