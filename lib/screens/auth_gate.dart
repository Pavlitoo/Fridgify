import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'auth_screen.dart';
import '../auth_service.dart';
import '../translations.dart';
import '../utils/snackbar_utils.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  User? user;
  Timer? timer;
  bool isEmailVerified = false;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  void _checkAuthStatus() {
    FirebaseAuth.instance.authStateChanges().listen((User? currentUser) {
      if (mounted) {
        setState(() {
          user = currentUser;
          isEmailVerified = currentUser?.emailVerified ?? false;
        });
      }

      if (currentUser != null && !isEmailVerified && currentUser.providerData.every((p) => p.providerId == 'password')) {
        timer = Timer.periodic(const Duration(seconds: 3), (_) => checkEmailVerified());
      } else {
        timer?.cancel();
      }
    });
  }

  Future<void> checkEmailVerified() async {
    await FirebaseAuth.instance.currentUser?.reload();

    if (mounted) {
      setState(() {
        isEmailVerified = FirebaseAuth.instance.currentUser?.emailVerified ?? false;
      });
    }

    if (isEmailVerified) {
      timer?.cancel();
      if (mounted) {
        SnackbarUtils.showSuccess(context, AppText.get('msg_email_verified'));
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const AuthScreen();
    }

    if (!isEmailVerified && user!.providerData.every((p) => p.providerId == 'password')) {
      return _buildVerificationScreen(context);
    }

    return const HomeScreen();
  }

  Widget _buildVerificationScreen(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(AppText.get('verify_email_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
            tooltip: AppText.get('btn_logout'),
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.mark_email_unread_outlined, size: 80, color: Colors.orange),
              ),
              const SizedBox(height: 32),

              Text(
                AppText.get('verify_email_title'),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              Text(
                "${AppText.get('verify_email_desc')} ${user?.email ?? ''}",
                style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: checkEmailVerified,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: Text(AppText.get('btn_i_verified'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    AuthService().resendVerificationEmail();
                    SnackbarUtils.showSuccess(context, AppText.get('msg_email_resent'));
                  },
                  icon: const Icon(Icons.send),
                  label: Text(AppText.get('btn_resend_email'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    side: BorderSide(color: Colors.grey.shade400),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}