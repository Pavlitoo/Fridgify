import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'dart:io';
import 'translations.dart'; // 👇 ОБОВ'ЯЗКОВО додай цей імпорт

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

    await _notifications.initialize(settings);

    if (Platform.isAndroid) {
      final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }
  }

  // Миттєве сповіщення
  static Future<void> showInstantNotification(String title, String body) async {
    // 🔥 Використовуємо переклад для назви каналу (не критично, але приємно)
    String channelName = AppText.get('notif_instant_title');
    String channelDesc = AppText.get('notif_instant_body');

    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'expired_channel',
      channelName,
      channelDescription: channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      color: const Color(0xFFFF0000),
    );

    NotificationDetails details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecond,
      title, // Титул і боді ми передаємо при виклику, вони вже можуть бути перекладені ззовні
      body,
      details,
    );
  }

  // Заплановане сповіщення
  static Future<void> scheduleNotification(int id, String productName, DateTime expirationDate) async {
    final DateTime warningDate = expirationDate.subtract(const Duration(days: 2));

    final scheduledTime = DateTime(
        warningDate.year,
        warningDate.month,
        warningDate.day,
        10, 0, 0
    );

    if (scheduledTime.isBefore(DateTime.now())) return;

    // 🔥 БЕРЕМО ПЕРЕКЛАД
    String title = AppText.get('notif_warn_title'); // "З'їж мене! ⏰"
    String bodySuffix = AppText.get('notif_warn_body'); // "закінчується через 2 дні!"
    String fullBody = '$productName $bodySuffix';

    String channelName = AppText.get('notif_channel_name');
    String channelDesc = AppText.get('notif_channel_desc');

    try {
      await _notifications.zonedSchedule(
        id,
        title,     // Перекладений заголовок
        fullBody,  // Перекладений текст з назвою продукту
        tz.TZDateTime.from(scheduledTime, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder_channel',
            channelName,
            channelDescription: channelDesc,
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
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