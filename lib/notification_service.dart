import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'dart:io';
import 'translations.dart';
import 'global.dart';

// 👇 Перевір шляхи, якщо щось підсвітить червоним
import '../screens/family_screen.dart';
import '../screens/home_screen.dart';
import 'chat_screen.dart'; // Або '../utils/chat_screen.dart' залежно від структури папок

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;
        if (payload != null) {
          _navigateLocally(payload);
        }
      },
    );

    if (Platform.isAndroid) {
      try {
        final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        await androidImplementation?.requestNotificationsPermission();
      } catch (e) {
        debugPrint("Помилка дозволів: $e");
      }
    }
  }

  static void _navigateLocally(String payload) {
    if (navigatorKey.currentState == null) return;

    String type = payload;
    String chatId = '';

    // Розбиваємо payload "type|chatId"
    if (payload.contains('|')) {
      final parts = payload.split('|');
      type = parts[0];
      if (parts.length > 1) chatId = parts[1];
    }

    debugPrint("🧭 Навігація Local: type=$type, chatId=$chatId");

    if (type == 'family_chat') {
      navigatorKey.currentState!.push(
          MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chatId,
                isDirect: false,
                // 🔥 ВИПРАВЛЕНО: Тепер береться переклад, а не хардкод
                chatTitle: AppText.get('chat_title'),
              )
          )
      );
    }
    else if (type == 'private_chat') {
      navigatorKey.currentState!.push(
          MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatId: chatId,
                isDirect: true,
              )
          )
      );
    }
    else if (type == 'fridge') {
      navigatorKey.currentState!.push(
          MaterialPageRoute(builder: (context) => const HomeScreen())
      );
    }
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'Важливі сповіщення',
      channelDescription: 'Сповіщення про чати та продукти',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF4CAF50),
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _notifications.show(id, title, body, details, payload: payload);
  }

  // --- Методи для продуктів ---
  static Future<void> showInstantNotification(String title, String body) async {
    await showNotification(
      id: DateTime.now().millisecond,
      title: title,
      body: body,
      payload: 'fridge',
    );
  }

  static Future<void> scheduleNotification(int id, String productName, DateTime expirationDate) async {
    final DateTime warningDate = expirationDate.subtract(const Duration(days: 2));
    final scheduledTime = DateTime(
        warningDate.year, warningDate.month, warningDate.day, 10, 0, 0
    );

    if (scheduledTime.isBefore(DateTime.now())) return;

    try {
      await _notifications.zonedSchedule(
        id,
        AppText.get('notif_warn_title'),
        '$productName ${AppText.get('notif_warn_body')}',
        tz.TZDateTime.from(scheduledTime, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder_channel',
            'Нагадування',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        // 🔥 ВИПРАВЛЕНО ТУТ: Використовуємо 'inexact', щоб уникнути помилки PlatformException
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,

        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'fridge',
      );
    } catch (e) {
      debugPrint("Помилка планування: $e");
    }
  }

  static Future<void> cancelNotification(int id) async {
    await _notifications.cancel(id);
  }

  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}