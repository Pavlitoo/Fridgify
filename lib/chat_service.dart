import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Генерація ID для приватного чату
  String getDmChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return "${ids[0]}_${ids[1]}";
  }

  // Отримання повідомлень (Stream)
  Stream<QuerySnapshot> getMessages(String chatId, {bool isDirect = false}) {
    CollectionReference ref = isDirect
        ? _firestore.collection('chats').doc(chatId).collection('messages')
        : _firestore.collection('households').doc(chatId).collection('messages');

    return ref.orderBy('timestamp', descending: true).snapshots();
  }

  // 🔥 ОСЬ ЦЕЙ МЕТОД БУВ ВІДСУТНІЙ (Виправляє помилку в ProfileScreen)
  Stream<int> getUnreadCountStream(String householdId) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(0);

    return _firestore
        .collection('households')
        .doc(householdId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(50) // Перевіряємо останні 50 повідомлень для економії
        .snapshots()
        .map((snapshot) {
      int count = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final readBy = List.from(data['readBy'] ?? []);
        if (!readBy.contains(uid)) {
          count++;
        }
      }
      return count;
    });
  }

  // Позначити як прочитане
  Future<void> markAsRead(String chatId, {bool isDirect = false}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final ref = isDirect
        ? _firestore.collection('chats').doc(chatId).collection('messages')
        : _firestore.collection('households').doc(chatId).collection('messages');

    final snapshot = await ref.limit(20).get();
    final batch = _firestore.batch();
    bool needCommit = false;

    for (var doc in snapshot.docs) {
      final readBy = List.from(doc['readBy'] ?? []);
      if (!readBy.contains(uid)) {
        batch.update(doc.reference, {
          'readBy': FieldValue.arrayUnion([uid])
        });
        needCommit = true;
      }
    }

    if (needCommit) await batch.commit();
  }

  // Отримати аватарку поточного юзера (приватний метод)
  Future<String?> _getCurrentUserAvatar() async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return null;
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data()?['avatar_base64'];
    } catch (e) {
      return null;
    }
  }

  // Відправка тексту
  Future<void> sendMessage(String chatId, String text, {bool isDirect = false, String? replyToText, String? replyToSender}) async {
    final user = _auth.currentUser!;
    final avatar = await _getCurrentUserAvatar();

    final ref = isDirect
        ? _firestore.collection('chats').doc(chatId).collection('messages')
        : _firestore.collection('households').doc(chatId).collection('messages');

    await ref.add({
      'text': text,
      'senderId': user.uid,
      'senderName': user.displayName ?? 'User',
      'senderAvatar': avatar,
      'timestamp': FieldValue.serverTimestamp(),
      'readBy': [user.uid],
      'likes': [],
      'replyToText': replyToText,
      'replyToSender': replyToSender,
    });
  }

  // Лайк повідомлення
  Future<void> toggleLikeMessage(String chatId, String msgId, bool isLiked, {bool isDirect = false}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final ref = isDirect
        ? _firestore.collection('chats').doc(chatId).collection('messages').doc(msgId)
        : _firestore.collection('households').doc(chatId).collection('messages').doc(msgId);

    if (isLiked) {
      await ref.update({'likes': FieldValue.arrayRemove([uid])});
    } else {
      await ref.update({'likes': FieldValue.arrayUnion([uid])});
    }
  }

  // Редагування
  Future<void> editMessage(String chatId, String msgId, String newText, {bool isDirect = false}) async {
    final ref = isDirect
        ? _firestore.collection('chats').doc(chatId).collection('messages').doc(msgId)
        : _firestore.collection('households').doc(chatId).collection('messages').doc(msgId);

    await ref.update({'text': newText, 'isEdited': true});
  }

  // Видалення
  Future<void> deleteMessage(String chatId, String msgId, {bool isDirect = false}) async {
    final ref = isDirect
        ? _firestore.collection('chats').doc(chatId).collection('messages').doc(msgId)
        : _firestore.collection('households').doc(chatId).collection('messages').doc(msgId);
    await ref.delete();
  }

  // Відправка фото
  Future<void> sendImage(String chatId, File imageFile, {bool isDirect = false}) async {
    try {
      List<int> imageBytes = await imageFile.readAsBytes();
      String base64Image = base64Encode(imageBytes);
      final user = _auth.currentUser!;
      final avatar = await _getCurrentUserAvatar();

      final ref = isDirect
          ? _firestore.collection('chats').doc(chatId).collection('messages')
          : _firestore.collection('households').doc(chatId).collection('messages');

      await ref.add({
        'imageBase64': base64Image,
        'senderId': user.uid,
        'senderName': user.displayName ?? 'User',
        'senderAvatar': avatar,
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [user.uid],
        'likes': [],
      });
    } catch (e) {
      print("Error sending image: $e");
    }
  }

  // Відправка голосового
  Future<void> sendVoice(String chatId, String path, {bool isDirect = false}) async {
    try {
      File file = File(path);
      List<int> audioBytes = await file.readAsBytes();
      String base64Audio = base64Encode(audioBytes);

      final user = _auth.currentUser!;
      final avatar = await _getCurrentUserAvatar();

      final ref = isDirect
          ? _firestore.collection('chats').doc(chatId).collection('messages')
          : _firestore.collection('households').doc(chatId).collection('messages');

      await ref.add({
        'audioBase64': base64Audio,
        'senderId': user.uid,
        'senderName': user.displayName ?? 'User',
        'senderAvatar': avatar,
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [user.uid],
        'likes': [],
      });
    } catch (e) {
      print("Error sending voice: $e");
    }
  }
}