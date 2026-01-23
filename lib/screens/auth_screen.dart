import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../utils/snackbar_utils.dart'; // ✅ Гарні повідомлення
import '../error_handler.dart'; // ✅ Обробка помилок
import '../translations.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _isPasswordVisible = false; // 🔥 Для кнопки "Око"

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      SnackbarUtils.showWarning(context, AppText.get('err_fill_all'));
      return;
    }

    // 🔥 Перевірка мінімальної довжини пароля
    if (password.length < 8) {
      SnackbarUtils.showWarning(context, AppText.get('err_min_pass_length'));
      return;
    }

    if (!_isLogin && name.isEmpty) {
      SnackbarUtils.showWarning(context, AppText.get('err_enter_name'));
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        await _auth.signInWithEmailAndPassword(email: email, password: password);
        // Успішний вхід -> можна показати повідомлення, але main.dart сам перекине
        if (mounted) SnackbarUtils.showSuccess(context, AppText.get('msg_welcome'));
      } else {
        UserCredential cred = await _auth.createUserWithEmailAndPassword(email: email, password: password);
        if (cred.user != null) {
          await cred.user!.updateDisplayName(name);
          await cred.user!.reload();
        }
        if (mounted) SnackbarUtils.showSuccess(context, AppText.get('msg_account_created'));
      }
    } catch (e) {
      if (mounted) {
        // 🔥 Використовуємо наш крутий ErrorHandler
        SnackbarUtils.showError(context, ErrorHandler.getMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      SnackbarUtils.showWarning(context, AppText.get('err_enter_email'));
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      SnackbarUtils.showWarning(context, AppText.get('err_invalid_email'));
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: email);
      if (mounted) {
        // 🔥 Повідомлення про відправку листа
        SnackbarUtils.showSuccess(context, AppText.get('msg_email_sent'));
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, ErrorHandler.getMessage(e));
      }
    }
  }

  Future<void> _googleSignInFunc() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // Користувач скасував вхід - це не помилка, просто виходимо
        return;
      }
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      await _auth.signInWithCredential(credential);
      if (mounted) SnackbarUtils.showSuccess(context, AppText.get('msg_welcome'));
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, ErrorHandler.getMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _githubSignInFunc() async {
    setState(() => _isLoading = true);
    try {
      OAuthProvider githubProvider = OAuthProvider('github.com');
      if (kIsWeb) {
        await _auth.signInWithPopup(githubProvider);
      } else {
        await _auth.signInWithProvider(githubProvider);
      }
      if (mounted) SnackbarUtils.showSuccess(context, AppText.get('msg_welcome'));
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, ErrorHandler.getMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.kitchen, size: 80, color: Colors.green.shade600),
              const SizedBox(height: 20),
              Text(
                _isLogin ? AppText.get('login_title') : AppText.get('signup_title'),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 30),

              if (!_isLogin) ...[
                TextField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    labelText: AppText.get('name_field'),
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: AppText.get('email_field'),
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // 🔥 Пароль з кнопкою "Око"
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible, // Змінюємо видимість
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: AppText.get('password_field'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
              ),

              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    child: Text(AppText.get('forgot_pass'), style: const TextStyle(color: Colors.grey)),
                  ),
                ),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _isLoading ? null : _authenticate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_isLogin ? AppText.get('login_btn') : AppText.get('signup_btn'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_isLogin ? AppText.get('no_account') : AppText.get('has_account'), style: TextStyle(color: textColor)),
                  const SizedBox(width: 5),
                  GestureDetector(
                    onTap: () => setState(() => _isLogin = !_isLogin),
                    child: Text(
                      _isLogin ? AppText.get('create_one') : AppText.get('enter_one'),
                      style: TextStyle(color: Colors.green.shade600, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),
              Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(AppText.get('or_continue'))), const Expanded(child: Divider())]),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialButton(
                      icon: FontAwesomeIcons.google,
                      color: Colors.red,
                      onTap: _googleSignInFunc
                  ),
                  const SizedBox(width: 20),
                  _socialButton(
                      icon: FontAwesomeIcons.github,
                      color: isDark ? Colors.white : Colors.black,
                      onTap: _githubSignInFunc
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _socialButton({required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: _isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          shape: BoxShape.circle,
          color: Theme.of(context).cardColor,
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}