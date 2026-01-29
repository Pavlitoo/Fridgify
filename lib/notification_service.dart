import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'dart:io';
import 'translations.dart'; // Переконайся, що шлях правильний
import '../screens/home_screen.dart';
import 'chat_screen.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static GlobalKey<NavigatorState>? _navigatorKey;

  static Future<void> init(GlobalKey<NavigatorState> navKey) async {
    _navigatorKey = navKey;
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
      final androidImplementation = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidImplementation?.requestNotificationsPermission();
    }
  }

  static void _navigateLocally(String payload) {
    if (_navigatorKey?.currentState == null) return;

    String type = payload;
    String chatId = '';

    if (payload.contains('|')) {
      final parts = payload.split('|');
      type = parts[0];
      if (parts.length > 1) chatId = parts[1];
    }

    if (type == 'family_chat') {
      _navigatorKey!.currentState!.push(MaterialPageRoute(
          builder: (context) => ChatScreen(chatId: chatId, isDirect: false, chatTitle: AppText.get('chat_title'))));
    } else if (type == 'private_chat') {
      _navigatorKey!.currentState!.push(MaterialPageRoute(
          builder: (context) => ChatScreen(chatId: chatId, isDirect: true)));
    } else if (type == 'fridge') {
      // 🔥 Перехід на головний екран (Холодильник) при кліку
      _navigatorKey!.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
      );
    }
  }

  // --- 🔥 НОВА ПОТУЖНА ЛОГІКА ПЛАНУВАННЯ 🔥 ---
  // Планує серію нагадувань: "Завтра зіпсується" і "Сьогодні зіпсується"
  static Future<void> scheduleExpiryNotifications({
    required String productId,
    required String productName,
    required DateTime expirationDate,
  }) async {
    final now = DateTime.now();

    // 1. Нагадування "ЗАВТРА зіпсується" (за 1 день до)
    final DateTime warnDate = expirationDate.subtract(const Duration(days: 1));
    // Ставимо на 10:00 ранку
    final scheduledWarn = DateTime(warnDate.year, warnDate.month, warnDate.day, 10, 0, 0);

    if (scheduledWarn.isAfter(now)) {
      await _scheduleSingle(
        id: ('${productId}_warn').hashCode, // Унікальний ID для попередження
        title: AppText.get('notif_warn_title'), // "Увага! Завтра зіпсується"
        body: '$productName',
        date: scheduledWarn,
      );
    }

    // 2. Нагадування "СЬОГОДНІ зіпсується" (в день X)
    final scheduledUrgent = DateTime(expirationDate.year, expirationDate.month, expirationDate.day, 10, 0, 0);

    if (scheduledUrgent.isAfter(now)) {
      await _scheduleSingle(
        id: ('${productId}_urgent').hashCode, // Унікальний ID для термінового
        title: AppText.get('notif_instant_title'), // "Увага! Сьогодні псується"
        body: '$productName',
        date: scheduledUrgent,
      );
    }
  }

  // Допоміжний приватний метод для власне планування
  static Future<void> _scheduleSingle({
    required int id,
    required String title,
    required String body,
    required DateTime date,
  }) async {
    try {
      await _notifications.zonedSchedule(
        id,
        title,
        "${AppText.get('notif_warn_body')} $body", // "Треба з'їсти: Банан"
        tz.TZDateTime.from(date, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'reminder_channel',
            'Нагадування про продукти',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'fridge', // Щоб відкривався холодильник
      );
      debugPrint("📅 Заплановано ($id): $title - $body на $date");
    } catch (e) {
      debugPrint("❌ Помилка планування: $e");
    }
  }

  // Очищення ВСІХ нагадувань для конкретного продукту (якщо з'їли)
  static Future<void> cancelForProduct(String productId) async {
    await _notifications.cancel(('${productId}_warn').hashCode);
    await _notifications.cancel(('${productId}_urgent').hashCode);
  }

  // Миттєве повідомлення (зведення)
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'Важливі сповіщення',
      importance: Importance.max,
      priority: Priority.high,
      color: Color(0xFF4CAF50),
    );
    const NotificationDetails details = NotificationDetails(android: androidDetails);
    await _notifications.show(id, title, body, details, payload: payload);
  }

  static Future<void> cancelNotification(int id) async => await _notifications.cancel(id);
  static Future<void> cancelAll() async => await _notifications.cancelAll();
}