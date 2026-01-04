import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../translations.dart'; // Зверни увагу на дві крапки (вихід з папки screens)

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  bool isLoading = false;
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final nameController = TextEditingController();

  void _handleAuthError(Object e) {
    String errorMsg = e.toString().toLowerCase();
    String friendlyMsg = AppText.get('unknown_error');
    if (errorMsg.contains('network')) friendlyMsg = "${AppText.get('no_internet')}\n${AppText.get('check_internet')}";
    else if (errorMsg.contains('user-not-found') || errorMsg.contains('wrong-password')) friendlyMsg = AppText.get('login_error');
    else if (errorMsg.contains('email-already-in-use')) friendlyMsg = AppText.get('email_taken');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyMsg), backgroundColor: Colors.red));
  }

  Future<void> submitAuthForm() async {
    setState(() => isLoading = true);
    try {
      if (isLogin) {
        await FirebaseAuth.instance.signInWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
      } else {
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: emailController.text.trim(), password: passwordController.text.trim());
        if (nameController.text.isNotEmpty) { await userCredential.user!.updateDisplayName(nameController.text.trim()); }
      }
    } catch (e) { if(mounted) _handleAuthError(e); } finally { if (mounted) setState(() => isLoading = false); }
  }

  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) { if(mounted) _handleAuthError(e); }
  }

  Future<void> signInWithGitHub() async {
    try {
      await FirebaseAuth.instance.signInWithProvider(GithubAuthProvider());
    } catch (e) { if (mounted) _handleAuthError(e); }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final primaryColor = isDark ? Colors.greenAccent : Theme.of(context).colorScheme.primary;
    final textColor = isDark ? Colors.white : Colors.black;
    final inputFill = isDark ? const Color(0xFF2C2C2C) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: Container(
        decoration: BoxDecoration(gradient: isDark ? null : LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.green.shade100, Colors.green.shade50])),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(children: [
              Image.asset('assets/logo.png', height: 120),
              const SizedBox(height: 20),
              Text(isLogin ? AppText.get('login_title') : AppText.get('signup_title'), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor)),
              const SizedBox(height: 40),
              if (!isLogin) ...[ _buildTextField(nameController, AppText.get('name_field'), Icons.person, inputFill, textColor), const SizedBox(height: 16) ],
              _buildTextField(emailController, 'Email', Icons.email, inputFill, textColor, isEmail: true),
              const SizedBox(height: 16),
              _buildTextField(passwordController, AppText.get('password_field'), Icons.lock, inputFill, textColor, isPassword: true),
              const SizedBox(height: 24),
              if (isLoading) const CircularProgressIndicator() else Column(children: [ElevatedButton(onPressed: submitAuthForm, style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade600, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 3), child: Text(isLogin ? AppText.get('login_btn') : AppText.get('signup_btn'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), const SizedBox(height: 10), TextButton(onPressed: () => setState(() => isLogin = !isLogin), child: Text(isLogin ? AppText.get('no_account') : AppText.get('has_account'), style: TextStyle(color: isDark ? Colors.white70 : Colors.green.shade800, fontWeight: FontWeight.bold)))]),
              const SizedBox(height: 30),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [_socialButton(icon: FontAwesomeIcons.google, color: Colors.red, onTap: signInWithGoogle, bgColor: inputFill), const SizedBox(width: 30), _socialButton(icon: FontAwesomeIcons.github, color: isDark ? Colors.white : Colors.black, onTap: signInWithGitHub, bgColor: inputFill)]),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, Color fillColor, Color textColor, {bool isPassword = false, bool isEmail = false}) {
    return TextField(controller: controller, obscureText: isPassword, keyboardType: isEmail ? TextInputType.emailAddress : TextInputType.text, style: TextStyle(color: textColor), decoration: InputDecoration(hintText: label, hintStyle: TextStyle(color: textColor.withOpacity(0.5)), prefixIcon: Icon(icon, color: Colors.green.shade700), filled: true, fillColor: fillColor, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)));
  }

  Widget _socialButton({required IconData icon, required Color color, required VoidCallback onTap, required Color bgColor}) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(50), child: Container(width: 60, height: 60, decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 2))], border: Border.all(color: Colors.grey.shade200)), child: Center(child: FaIcon(icon, color: color, size: 28))));
  }
}