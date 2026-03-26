import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // --- ГЕНЕРАЦІЯ ID ДЛЯ ПРИВАТНОГО ЧАТУ ---
  String getDmChatId(String userId1, String userId2) {
    List<String> ids = [userId1, userId2];
    ids.sort();
    return "${ids[0]}_${ids[1]}";
  }

  // --- ОТРИМАННЯ ПОВІДОМЛЕНЬ ---
  Stream<QuerySnapshot> getMessages(String chatId, {bool isDirect = false}) {
    CollectionReference ref = isDirect
        ? _firestore.collection('chats').doc(chatId).collection('messages')
        : _firestore.collection('households').doc(chatId).collection('messages');

    return ref.orderBy('timestamp', descending: true).snapshots();
  }

  // --- ОТРИМАННЯ МЕТАДАНИХ ЧАТУ ---
  Stream<DocumentSnapshot> getChatMetadataStream(String chatId, {bool isDirect = false}) {
    final ref = isDirect
        ? _firestore.collection('chats').doc(chatId)
        : _firestore.collection('households').doc(chatId);
    return ref.snapshots();
  }

  // --- УНІВЕРСАЛЬНИЙ ЛІЧИЛЬНИК НЕПРОЧИТАНИХ ---
  Stream<int> getUnreadCountForChatStream(String chatId, {bool isDirect = false}) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(0);

    final ref = isDirect
        ? _firestore.collection('chats').doc(chatId).collection('messages')
        : _firestore.collection('households').doc(chatId).collection('messages');

    return ref
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
      int count = 0;
      for (var doc in snapshot.docs) {
        if (doc.id == 'TYPING_INDICATOR') continue;
        final data = doc.data() as Map<String, dynamic>;
        final readBy = List.from(data['readBy'] ?? []);
        if (data['senderId'] != uid && !readBy.contains(uid)) {
          count++;
        }
      }
      return count;
    });
  }

  Stream<int> getUnreadCountStream(String householdId) {
    return getUnreadCountForChatStream(householdId, isDirect: false);
  }

  // 🔥 ЗБІЛЬШЕНО ЛІМІТ ДО 50 ДЛЯ НАДІЙНОСТІ
  Future<void> markAsRead(String chatId, {bool isDirect = false}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final ref = isDirect
        ? _firestore.collection('chats').doc(chatId).collection('messages')
        : _firestore.collection('households').doc(chatId).collection('messages');

    final snapshot = await ref.orderBy('timestamp', descending: true).limit(50).get();
    final batch = _firestore.batch();
    bool needCommit = false;

    for (var doc in snapshot.docs) {
      if (doc.id == 'TYPING_INDICATOR') continue;
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

  // --- СТАТУС "ПИШЕ ПОВІДОМЛЕННЯ..." ---
  Future<void> setTypingStatus(String chatId, bool isTyping, {bool isDirect = false}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final docRef = isDirect
        ? _firestore.collection('chats').doc(chatId).collection('messages').doc('TYPING_INDICATOR')
        : _firestore.collection('households').doc(chatId).collection('messages').doc('TYPING_INDICATOR');

    try {
      if (isTyping) {
        await docRef.set({'typing': FieldValue.arrayUnion([uid])}, SetOptions(merge: true));
      } else {
        await docRef.set({'typing': FieldValue.arrayRemove([uid])}, SetOptions(merge: true));
      }
    } catch (e) {}
  }

  // --- АВАТАРКА ЮЗЕРА ---
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

  // --- ЗАВАНТАЖУВАЧ У STORAGE ---
  Future<String?> _uploadFileToStorage(File file, String folderName) async {
    try {
      final uid = _auth.currentUser!.uid;
      final ext = file.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$uid.$ext';

      final ref = _storage.ref().child(folderName).child(fileName);
      final uploadTask = await ref.putFile(file);

      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print("Помилка завантаження файлу у Storage: $e");
      return null;
    }
  }

  Future<void> _updateLastMessageTime(String chatId, {bool isDirect = false}) async {
    final ref = isDirect
        ? _firestore.collection('chats').doc(chatId)
        : _firestore.collection('households').doc(chatId);

    Map<String, dynamic> updateData = {
      'lastTimestamp': FieldValue.serverTimestamp(),
    };

    if (isDirect) {
      updateData['participants'] = chatId.split('_');
    }

    await ref.set(updateData, SetOptions(merge: true));
  }

  // --- ВІДПРАВКА ТЕКСТУ ---
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

    await _updateLastMessageTime(chatId, isDirect: isDirect);
  }

  // --- ЛАЙК ПОВІДОМЛЕННЯ ---
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

  // --- РЕДАГУВАННЯ ---
  Future<void> editMessage(String chatId, String msgId, String newText, {bool isDirect = false}) async {
    final ref = isDirect
        ? _firestore.collection('chats').doc(chatId).collection('messages').doc(msgId)
        : _firestore.collection('households').doc(chatId).collection('messages').doc(msgId);

    await ref.update({'text': newText, 'isEdited': true});
  }

  // --- ВИДАЛЕННЯ ---
  Future<void> deleteMessage(String chatId, String msgId, {bool isDirect = false}) async {
    final docRef = isDirect
        ? _firestore.collection('chats').doc(chatId).collection('messages').doc(msgId)
        : _firestore.collection('households').doc(chatId).collection('messages').doc(msgId);

    try {
      final docSnap = await docRef.get();
      if (docSnap.exists) {
        final data = docSnap.data() as Map<String, dynamic>;
        final imageUrl = data['imageUrl'];
        final audioUrl = data['audioUrl'];
        final fileUrl = data['fileUrl'];

        if (imageUrl != null) await _storage.refFromURL(imageUrl).delete();
        if (audioUrl != null) await _storage.refFromURL(audioUrl).delete();
        if (fileUrl != null) await _storage.refFromURL(fileUrl).delete();
      }
      await docRef.delete();
    } catch (e) {}
  }

  // --- ВІДПРАВКА ФОТО ---
  Future<void> sendImage(String chatId, File imageFile, {bool isDirect = false}) async {
    try {
      final user = _auth.currentUser!;
      final avatar = await _getCurrentUserAvatar();

      final imageUrl = await _uploadFileToStorage(imageFile, 'chat_images');
      if (imageUrl == null) throw Exception("Не вдалося завантажити фото");

      final ref = isDirect
          ? _firestore.collection('chats').doc(chatId).collection('messages')
          : _firestore.collection('households').doc(chatId).collection('messages');

      await ref.add({
        'imageUrl': imageUrl,
        'senderId': user.uid,
        'senderName': user.displayName ?? 'User',
        'senderAvatar': avatar,
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [user.uid],
        'likes': [],
      });

      await _updateLastMessageTime(chatId, isDirect: isDirect);
    } catch (e) {}
  }

  // --- ВІДПРАВКА ГОЛОСОВОГО ---
  Future<void> sendVoice(String chatId, String path, {bool isDirect = false}) async {
    try {
      final user = _auth.currentUser!;
      final avatar = await _getCurrentUserAvatar();
      File audioFile = File(path);

      final audioUrl = await _uploadFileToStorage(audioFile, 'chat_audio');
      if (audioUrl == null) throw Exception("Не вдалося завантажити голосове повідомлення");

      final ref = isDirect
          ? _firestore.collection('chats').doc(chatId).collection('messages')
          : _firestore.collection('households').doc(chatId).collection('messages');

      await ref.add({
        'audioUrl': audioUrl,
        'senderId': user.uid,
        'senderName': user.displayName ?? 'User',
        'senderAvatar': avatar,
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [user.uid],
        'likes': [],
      });

      await _updateLastMessageTime(chatId, isDirect: isDirect);
    } catch (e) {}
  }

  // --- ВІДПРАВКА ФАЙЛУ ---
  Future<void> sendFile(String chatId, File file, String fileName, {bool isDirect = false}) async {
    try {
      final user = _auth.currentUser!;
      final avatar = await _getCurrentUserAvatar();

      final fileUrl = await _uploadFileToStorage(file, 'chat_files');
      if (fileUrl == null) throw Exception("Не вдалося завантажити файл");

      final ref = isDirect
          ? _firestore.collection('chats').doc(chatId).collection('messages')
          : _firestore.collection('households').doc(chatId).collection('messages');

      await ref.add({
        'fileUrl': fileUrl,
        'fileName': fileName,
        'senderId': user.uid,
        'senderName': user.displayName ?? 'User',
        'senderAvatar': avatar,
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [user.uid],
        'likes': [],
      });

      await _updateLastMessageTime(chatId, isDirect: isDirect);
    } catch (e) {}
  }
}