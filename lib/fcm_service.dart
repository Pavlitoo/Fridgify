import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_service.dart';
import 'global.dart';
import '../translations.dart'; // ✅ Додано імпорт перекладів

// 👇 Імпорти
import '../screens/family_screen.dart';
import '../screens/home_screen.dart';
import 'chat_screen.dart';

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

    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        _handleMessage(message);
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleMessage(message);
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
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
    Future.delayed(const Duration(milliseconds: 500), () {
      final String type = message.data['type'] ?? '';
      final String chatId = message.data['chatId'] ?? '';

      debugPrint("🧭 Навігація FCM: type=$type, chatId=$chatId");

      if (navigatorKey.currentState == null) return;

      if (type == 'family_chat') {
        navigatorKey.currentState!.push(
            MaterialPageRoute(
                builder: (context) => ChatScreen(
                  chatId: chatId,
                  isDirect: false,
                  chatTitle: AppText.get('chat_title'), // ✅ Перекладений заголовок
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
    });
  }
}