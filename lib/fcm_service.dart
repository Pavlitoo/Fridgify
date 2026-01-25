import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import 'global.dart';

// 👇 Перевір шляхи до файлів
import '../screens/family_screen.dart';
import '../screens/home_screen.dart';
import 'chat_screen.dart'; // Або '../screens/chat_screen.dart' (де він у тебе лежить)

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint("🌙 Фонове повідомлення: ${message.messageId}");
}

class FCMService {
  final _firebaseMessaging = FirebaseMessaging.instance;

  Future<void> init() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final fCMToken = await _firebaseMessaging.getToken();
    debugPrint('🔥 FCM Token: $fCMToken');
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && fCMToken != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': fCMToken});
    }

    // 1. Клік, коли додаток був ЗАКРИТИЙ
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleMessage(message);
      }
    });

    // 2. Клік, коли додаток був ЗГОРНУТИЙ
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessage(message);
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 3. Додаток ВІДКРИТИЙ (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        // Щоб не було подвійних сповіщень:
        // Тут ми показуємо локальне сповіщення (плашку), бо системне не приходить, коли додаток відкритий.

        String type = message.data['type'] ?? 'general';
        String chatId = message.data['chatId'] ?? '';
        String payload = "$type|$chatId";

        NotificationService.showNotification(
          id: message.hashCode,
          title: message.notification!.title ?? 'Сповіщення',
          body: message.notification!.body ?? '',
          payload: payload,
        );
      }
    });
  }

  void _handleMessage(RemoteMessage message) {
    // Затримка, щоб Flutter встиг завантажитись
    Future.delayed(const Duration(milliseconds: 500), () {
      final String type = message.data['type'] ?? '';
      final String chatId = message.data['chatId'] ?? '';

      debugPrint("🧭 Навігація FCM: type=$type, chatId=$chatId");

      if (navigatorKey.currentState == null) return;

      if (type == 'family_chat') {
        // 🔥 ВИПРАВЛЕНО: Відкриваємо ЧАТ, а не FamilyScreen
        navigatorKey.currentState!.push(
            MaterialPageRoute(
                builder: (context) => ChatScreen(
                  chatId: chatId,
                  isDirect: false, // Це сімейний чат
                  chatTitle: 'Сімейний чат',
                )
            )
        );
      }
      else if (type == 'private_chat') {
        navigatorKey.currentState!.push(
            MaterialPageRoute(
                builder: (context) => ChatScreen(
                  chatId: chatId,
                  isDirect: true, // Це особистий чат
                )
            )
        );
      }
      else if (type == 'fridge') {
        navigatorKey.currentState!.push(
            MaterialPageRoute(builder: (context) => const HomeScreen())
        );
      }
    });
  }
}