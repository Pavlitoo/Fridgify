import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  // Singleton pattern to access the service globally
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Initialization (runs on app start)
  Future<void> init() async {
    tz.initializeTimeZones(); // Initialize time zones

    // Android settings (using default app icon)
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    // Request permission for Android 13+
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Function: Schedule a notification
  Future<void> scheduleNotification(int id, String productName, DateTime expirationDate) async {
    // Notify 1 day before expiration
    final scheduledDate = expirationDate.subtract(const Duration(days: 1));

    // If date has passed, don't schedule
    if (scheduledDate.isBefore(DateTime.now())) return;

    // Set time to 9:00 AM
    final notificationTime = DateTime(
        scheduledDate.year,
        scheduledDate.month,
        scheduledDate.day,
        9, 0, 0
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      '⚠️ Product expiring!',
      'Expiration date for "$productName" is tomorrow. Use it soon!',
      tz.TZDateTime.from(notificationTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'expiry_channel', // Channel ID
          'Product Expiry Reminders', // Channel Name
          channelDescription: 'Notifies when products are about to expire',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Exact timing even in doze mode
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // Function: Cancel notification (when deleting product)
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }
}