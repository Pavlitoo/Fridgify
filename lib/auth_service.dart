import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ===========================================================================
  // 🚪 ВИХІД (LOGOUT)
  // ===========================================================================
  Future<void> signOut() async {
    try {
      if (await _googleSignIn.isSignedIn()) {
        await _googleSignIn.disconnect();
      } else {
        await _googleSignIn.signOut();
      }
      await _auth.signOut();
      debugPrint("✅ Вихід успішний");
    } catch (e) {
      debugPrint("❌ Помилка при виході: $e");
    }
  }

  // ===========================================================================
  // 🕵️ РОЗУМНА ПЕРЕВІРКА ПОШТИ (SMART LOGIN)
  // ===========================================================================
  Future<List<String>> checkEmailProviders(String email) async {
    try {
      return await _auth.fetchSignInMethodsForEmail(email);
    } catch (e) {
      debugPrint("❌ Помилка перевірки пошти: $e");
      return [];
    }
  }

  // ===========================================================================
  // 🔵 ВХІД ЧЕРЕЗ GOOGLE ТА GITHUB
  // ===========================================================================
  Future<User?> signInWithGoogle() async {
    try {
      try { await _googleSignIn.signOut(); } catch (_) {}

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      if (userCredential.user != null) await _saveUserToFirestore(userCredential.user!);

      return userCredential.user;
    } catch (e) {
      debugPrint("❌ Помилка Google Sign-In: $e");
      rethrow;
    }
  }

  Future<User?> signInWithGitHub(BuildContext context) async {
    try {
      final OAuthProvider githubProvider = OAuthProvider('github.com');
      final UserCredential userCredential = await _auth.signInWithProvider(githubProvider);

      if (userCredential.user != null) await _saveUserToFirestore(userCredential.user!);
      return userCredential.user;
    } catch (e) {
      debugPrint("❌ Помилка GitHub Sign-In: $e");
      rethrow;
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

        // Відправляємо лист, але залишаємо юзера в системі для AuthGate
        if (!user.emailVerified) {
          await user.sendEmailVerification();
          debugPrint("📧 Лист верифікації надіслано!");
        }

        await _saveUserToFirestore(user, customName: name);
      }

      return user;
    } on FirebaseAuthException catch (e) {
      debugPrint("❌ Помилка реєстрації: ${e.code}");
      rethrow;
    }
  }

  // ===========================================================================
  // 🔑 СКИДАННЯ ПАРОЛЮ ТА ПЕРЕВІРКА СТАТУСУ
  // ===========================================================================
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  Future<void> resendVerificationEmail() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  // ===========================================================================
  // 💾 ЗБЕРЕЖЕННЯ ЮЗЕРА В FIRESTORE
  // ===========================================================================
  Future<void> _saveUserToFirestore(User user, {String? customName}) async {
    final userDoc = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnapshot = await userDoc.get();

    String displayEmail = user.email ?? 'Невідомо';

    if (!docSnapshot.exists) {
      await userDoc.set({
        'uid': user.uid,
        'email': displayEmail,
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
        if (user.photoURL != null) 'photoURL': user.photoURL,
      });
    }
  }
}