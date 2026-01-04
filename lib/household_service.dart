import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HouseholdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> createHousehold(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    String inviteCode = _generateInviteCode();

    DocumentReference householdRef = await _firestore.collection('households').add({
      'name': name,
      'adminId': user.uid,
      'inviteCode': inviteCode,
      'createdAt': FieldValue.serverTimestamp(),
      'members': [user.uid],
    });

    await _firestore.collection('users').doc(user.uid).update({
      'householdId': householdRef.id,
    });

    return householdRef.id;
  }

  // 👇 ГОЛОВНИЙ ФІКС ТУТ
  Future<void> requestToJoin(String inviteCode) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final String? avatarBase64 = userDoc.data()?['avatar_base64'];

    final query = await _firestore.collection('households').where('inviteCode', isEqualTo: inviteCode).limit(1).get();

    if (query.docs.isEmpty) {
      throw Exception("Невірний код");
    }

    final householdDoc = query.docs.first;
    List members = List.from(householdDoc.data()['members'] ?? []);

    // Якщо ми вже в списку учасників
    if (members.contains(user.uid)) {
      // Перевіряємо, чи ми ДІЙСНО прив'язані до цієї сім'ї в нашому профілі
      if (userDoc.data()?['householdId'] == householdDoc.id) {
        throw Exception("Ви вже є учасником цієї сім'ї");
      } else {
        // АГА! Ми в списку, але у нас немає householdId (нас видалили "криво").
        // Виправляємо це: видаляємо себе зі списку учасників, щоб можна було зайти знову.
        await householdDoc.reference.update({
          'members': FieldValue.arrayRemove([user.uid])
        });
        // Тепер ми чисті і можемо подавати заявку далі.
      }
    }

    await householdDoc.reference.collection('requests').doc(user.uid).set({
      'uid': user.uid,
      'name': user.displayName ?? 'Unknown',
      'email': user.email,
      'avatar': avatarBase64,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> acceptRequest(String householdId, String userId) async {
    final householdRef = _firestore.collection('households').doc(householdId);

    await householdRef.update({
      'members': FieldValue.arrayUnion([userId])
    });

    await _firestore.collection('users').doc(userId).update({
      'householdId': householdId
    });

    await householdRef.collection('requests').doc(userId).delete();
  }

  Future<void> rejectRequest(String householdId, String userId) async {
    await _firestore.collection('households').doc(householdId).collection('requests').doc(userId).delete();
  }

  Future<void> leaveHousehold() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final householdId = userDoc.data()?['householdId'];

    if (householdId != null) {
      await _firestore.collection('households').doc(householdId).update({
        'members': FieldValue.arrayRemove([user.uid])
      });
      await _firestore.collection('users').doc(user.uid).update({
        'householdId': FieldValue.delete()
      });
    }
  }

  // 👇 ФУНКЦІЯ ПОВНОГО ВИДАЛЕННЯ (Для адміна)
  Future<void> removeMember(String householdId, String memberId) async {
    // 1. Видаляємо зі списку учасників сім'ї
    await _firestore.collection('households').doc(householdId).update({
      'members': FieldValue.arrayRemove([memberId])
    });
    // 2. Очищаємо ID сім'ї у користувача (щоб він знав, що його видалили)
    await _firestore.collection('users').doc(memberId).update({
      'householdId': FieldValue.delete()
    });
  }

  String _generateInviteCode() {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Stream<QuerySnapshot> getRequestsStream(String householdId) {
    return _firestore.collection('households').doc(householdId).collection('requests').snapshots();
  }
}