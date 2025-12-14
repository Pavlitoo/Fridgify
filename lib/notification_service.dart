import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  // Робимо так, щоб цей сервіс був один на весь додаток (Singleton)
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Ініціалізація (запускається при старті додатку)
  Future<void> init() async {
    tz.initializeTimeZones(); // Налаштування часових поясів

    // Налаштування для Android (використовуємо стандартну іконку)
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Просимо дозвіл на сповіщення (для Android 13+)
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Функція: Запланувати нагадування
  Future<void> scheduleNotification(int id, String productName, DateTime expirationDate) async {
    // Нагадуємо за 1 день до закінчення терміну
    final scheduledDate = expirationDate.subtract(const Duration(days: 1));

    // Якщо дата вже пройшла — не ставимо нагадування
    if (scheduledDate.isBefore(DateTime.now())) return;

    // Ставимо час на 9:00 ранку
    final notificationTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        9, 0, 0
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      '⚠️ Продукт псується!',
      'Термін придатності "$productName" спливає завтра. Час використати!',
      tz.TZDateTime.from(notificationTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'expiry_channel', // ID каналу
          'Нагадування про продукти', // Назва каналу
          channelDescription: 'Сповіщає, коли продукти псуються',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Точний час навіть у сплячому режимі
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Функція: Скасувати нагадування (коли видаляєш продукт)
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}