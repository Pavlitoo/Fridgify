import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HouseholdService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- СТВОРЕННЯ ---
  Future<void> createHousehold(String name) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("User not logged in");

    final batch = _firestore.batch();
    final householdRef = _firestore.collection('households').doc();
    String inviteCode = _generateInviteCode();

    batch.set(householdRef, {
      'name': name,
      'adminId': user.uid,
      'inviteCode': inviteCode,
      'createdAt': FieldValue.serverTimestamp(),
      'members': [user.uid],
    });

    final userRef = _firestore.collection('users').doc(user.uid);
    batch.set(userRef, {
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName ?? 'User',
      'householdId': householdRef.id,
    }, SetOptions(merge: true));

    await batch.commit();
  }

  // --- ВСТУПИТИ (ЗАПИТ) ---
  Future<void> requestToJoin(String code) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // 1. Шукаємо сім'ю
    final snapshot = await _firestore.collection('households').where('inviteCode', isEqualTo: code).limit(1).get();

    if (snapshot.docs.isEmpty) {
      throw Exception("Невірний код. Сім'ю не знайдено.");
    }

    final householdDoc = snapshot.docs.first;
    final householdId = householdDoc.id;
    List members = List.from(householdDoc.data()['members'] ?? []);

    // 2. Якщо вже там
    if (members.contains(user.uid)) {
      // Якщо юзер в списку, але у нього немає householdId, фіксимо це:
      await _firestore.collection('users').doc(user.uid).update({'householdId': householdId});
      throw Exception("Ви вже в цій сім'ї.");
    }

    // 3. Створюємо запит
    await householdDoc.reference.collection('requests').doc(user.uid).set({
      'uid': user.uid,
      'name': user.displayName ?? 'User',
      'email': user.email,
      'avatar': null,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --- ПРИЙНЯТИ (АДМІН) ---
  Future<void> acceptRequest(String householdId, String userId) async {
    final batch = _firestore.batch();

    batch.update(_firestore.collection('households').doc(householdId), {
      'members': FieldValue.arrayUnion([userId])
    });

    batch.update(_firestore.collection('users').doc(userId), {
      'householdId': householdId
    });

    batch.delete(_firestore.collection('households').doc(householdId).collection('requests').doc(userId));

    await batch.commit();
  }

  // --- ВІДХИЛИТИ (АДМІН) ---
  Future<void> rejectRequest(String householdId, String userId) async {
    await _firestore.collection('households').doc(householdId).collection('requests').doc(userId).delete();
  }

  // --- ВИЙТИ (САМОСТІЙНО) ---
  Future<void> leaveHousehold() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final householdId = userDoc.data()?['householdId'];

    if (householdId != null) {
      final batch = _firestore.batch();

      batch.update(_firestore.collection('households').doc(householdId), {
        'members': FieldValue.arrayRemove([user.uid])
      });

      batch.update(_firestore.collection('users').doc(user.uid), {
        'householdId': FieldValue.delete()
      });

      await batch.commit();
    }
  }

  // --- ВИДАЛИТИ УЧАСНИКА (ФУНКЦІЯ АДМІНА) ---
  Future<void> removeMember(String householdId, String memberId) async {
    final batch = _firestore.batch();

    // Видаляємо зі списку сім'ї
    batch.update(_firestore.collection('households').doc(householdId), {
      'members': FieldValue.arrayRemove([memberId])
    });

    // Видаляємо ID сім'ї у користувача
    batch.update(_firestore.collection('users').doc(memberId), {
      'householdId': FieldValue.delete()
    });

    await batch.commit();
  }

  Stream<QuerySnapshot> getRequestsStream(String householdId) {
    return _firestore.collection('households').doc(householdId).collection('requests').snapshots();
  }

  String _generateInviteCode() {
    const chars = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(6, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }
}