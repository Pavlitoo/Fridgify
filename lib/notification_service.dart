import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'translations.dart';
import 'screens/home_screen.dart';
import 'chat_screen.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("Фонове повідомлення Firebase: ${message.messageId}");
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static GlobalKey<NavigatorState>? _navigatorKey;

  static Future<void> init(GlobalKey<NavigatorState> navKey) async {
    _navigatorKey = navKey;
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      settings: initSettings,
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

    await _fcm.requestPermission(alert: true, badge: true, sound: true);
    await _saveDeviceToken();
    _fcm.onTokenRefresh.listen(_saveDeviceToken);

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 🔥 ВИДАЛЕНО РАННІЙ ВИКЛИК getInitialMessage() - Тепер це робить main.dart!

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      handleFirebaseNotificationClick(message);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showForegroundNotification(message);
    });

    await scheduleEveningRetentionNotification();
  }

  // ===========================================================================
  // НАВІГАЦІЯ ДЛЯ ЛОКАЛЬНИХ ПУШІВ
  // ===========================================================================
  static void _navigateLocally(String payload) {
    if (_navigatorKey?.currentState == null) return;

    _navigatorKey!.currentState!.popUntil((route) => route.isFirst);

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
    } else if (type == 'fridge' || type == 'recipes') {
      _navigatorKey!.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
      );
    } else if (type.startsWith('chat_')) {
      final parts = type.split('_');
      if (parts.length >= 3) {
        final rChatId = parts[1];
        final rType = parts[2];
        _navigatorKey!.currentState!.push(MaterialPageRoute(
            builder: (context) => ChatScreen(chatId: rChatId, isDirect: rType == 'private_chat')));
      }
    }
  }

  // ===========================================================================
  // 🔥 НАВІГАЦІЯ ДЛЯ СЕРВЕРНИХ ПУШІВ (ТЕПЕР ПУБЛІЧНА)
  // ===========================================================================
  static void handleFirebaseNotificationClick(RemoteMessage message) {
    if (_navigatorKey?.currentState == null) {
      debugPrint("❌ Навігатор ще не готовий!");
      return;
    }

    _navigatorKey!.currentState!.popUntil((route) => route.isFirst);

    // Зчитуємо payload, який ми передали з сервера (index.js або з Firestore)
    final String? payload = message.data['payload'];
    final String type = message.data['type'] ?? '';

    // Перехід у холодильник або рецепти (Ранкові / Вечірні пуші)
    if (payload == 'fridge' || payload == 'recipes' || type == 'recipes') {
      _navigatorKey!.currentState!.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
      );
      return;
    }

    // Перехід у чати
    if (message.data.containsKey('chatId')) {
      final String chatId = message.data['chatId'];
      final bool isDirect = type == 'private_chat';

      _navigatorKey!.currentState!.push(
        MaterialPageRoute(
          builder: (_) => ChatScreen(chatId: chatId, isDirect: isDirect, chatTitle: message.notification?.title ?? "Чат"),
        ),
      );
    }
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    await _notifications.show(
      id: message.hashCode,
      title: message.notification?.title,
      body: message.notification?.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails('high_importance_channel', 'Важливі сповіщення', importance: Importance.max, priority: Priority.high, icon: '@mipmap/ic_launcher'),
      ),
      payload: message.data['payload'] ?? (message.data['chatId'] != null ? 'chat_${message.data['chatId']}_${message.data['type']}' : null),
    );
  }

  static Future<void> _saveDeviceToken([String? providedToken]) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      String? token = providedToken ?? await _fcm.getToken();
      if (token != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({'fcmToken': token});
      }
    } catch (e) { debugPrint("Token error: $e"); }
  }



  static Future<void> _scheduleSingle({required int id, required String title, required String body, required DateTime date}) async {
    try {
      await _notifications.zonedSchedule(id: id, title: title, body: "Треба з'їсти: $body", scheduledDate: tz.TZDateTime.from(date, tz.local), notificationDetails: const NotificationDetails(android: AndroidNotificationDetails('reminder_channel', 'Нагадування про продукти', importance: Importance.max, priority: Priority.high)), androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, payload: 'fridge');
    } catch (e) { debugPrint("Schedule error: $e"); }
  }

  static Future<void> cancelForProduct(String productId) async {
    await _notifications.cancel(id: ('${productId}_warn').hashCode);
    await _notifications.cancel(id: ('${productId}_urgent').hashCode);
  }

  static Future<void> scheduleEveningRetentionNotification() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, 17, 0);
    if (scheduledDate.isBefore(now)) scheduledDate = scheduledDate.add(const Duration(days: 1));
    try {
      await _notifications.zonedSchedule(id: 999, title: 'Час готувати вечерю! 🍳', body: 'Загляньте у додаток — ми підберемо крутий рецепт з того, що є у вас вдома!', scheduledDate: scheduledDate, notificationDetails: const NotificationDetails(android: AndroidNotificationDetails('daily_retention_channel', 'Поради на вечір', importance: Importance.high, priority: Priority.high)), androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle, matchDateTimeComponents: DateTimeComponents.time, payload: 'recipes');
    } catch (e) { debugPrint("Evening schedule error: $e"); }
  }

  static Future<void> showNotification({required int id, required String title, required String body, String? payload}) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails('high_importance_channel', 'Важливі сповіщення', importance: Importance.max, priority: Priority.high, color: Color(0xFF4CAF50));
    await _notifications.show(id: id, title: title, body: body, notificationDetails: const NotificationDetails(android: androidDetails), payload: payload);
  }

  static Future<void> cancelNotification(int id) async => await _notifications.cancel(id: id);
  static Future<void> cancelAll() async => await _notifications.cancelAll();
}