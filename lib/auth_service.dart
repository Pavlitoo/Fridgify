import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Стрім для відстеження стану (чи залогінений юзер)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Отримати поточного юзера
  User? get currentUser => _auth.currentUser;

  // ===========================================================================
  // 🚪 ВИХІД (LOGOUT)
  // ===========================================================================
  Future<void> signOut() async {
    try {
      // 1. Спочатку виходимо з Google плагіна ПРИМУСОВО
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.disconnect();
      } else {
        await _googleSignIn.signOut();
      }

      // 2. Виходимо з Firebase
      await _auth.signOut();

      debugPrint("✅ Вихід успішний (Session cleared)");
    } catch (e) {
      debugPrint("❌ Помилка при виході: $e");
    }
  }

  // ===========================================================================
  // 🔵 ВХІД ЧЕРЕЗ GOOGLE
  // ===========================================================================
  Future<User?> signInWithGoogle() async {
    try {
      // Страховка: очищаємо попередню сесію
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null; // Юзер скасував
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        await _saveUserToFirestore(user);
      }

      return user;
    } catch (e) {
      debugPrint("❌ Помилка Google Sign-In: $e");
      return null;
    }
  }

  // ===========================================================================
  // ⚫ ВХІД ЧЕРЕЗ GITHUB (ВИПРАВЛЕНО)
  // ===========================================================================
  Future<User?> signInWithGitHub(BuildContext context) async {
    try {
      // 🔥 ВИПРАВЛЕНО ТУТ: Використовуємо OAuthProvider замість GitHubAuthProvider
      final OAuthProvider githubProvider = OAuthProvider('github.com');

      // Вхід через провайдер
      final UserCredential userCredential = await _auth.signInWithProvider(githubProvider);
      final User? user = userCredential.user;

      if (user != null) {
        await _saveUserToFirestore(user);
      }

      return user;
    } catch (e) {
      debugPrint("❌ Помилка GitHub Sign-In: $e");
      return null;
    }
  }

  // ===========================================================================
  // 📧 EMAIL: ВХІД
  // ===========================================================================
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } catch (e) {
      debugPrint("❌ Помилка входу Email: $e");
      rethrow;
    }
  }

  // ===========================================================================
  // 📧 EMAIL: РЕЄСТРАЦІЯ
  // ===========================================================================
  Future<User?> signUpWithEmail(String email, String password, String name) async {
    try {
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = userCredential.user;

      if (user != null) {
        await user.updateDisplayName(name);
        await user.reload();
        await _saveUserToFirestore(user, customName: name);
      }

      return _auth.currentUser;
    } catch (e) {
      debugPrint("❌ Помилка реєстрації: $e");
      rethrow;
    }
  }

  // ===========================================================================
  // 🔑 СКИДАННЯ ПАРОЛЮ
  // ===========================================================================
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ===========================================================================
  // 💾 (Private) ЗБЕРЕЖЕННЯ ЮЗЕРА В FIRESTORE
  // ===========================================================================
  Future<void> _saveUserToFirestore(User user, {String? customName}) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    if (!docSnapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'email': user.email,
        'displayName': customName ?? user.displayName ?? 'User',
        'photoURL': user.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
        'lastLogin': FieldValue.serverTimestamp(),
        'householdId': null,
        'fcmToken': null,
      });
    } else {
      await userDoc.update({
        'lastLogin': FieldValue.serverTimestamp(),
      });
    }
  }
}