import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🔥 Обов'язково для обробки помилок
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../auth_service.dart';
import '../utils/snackbar_utils.dart';
import '../error_handler.dart';
import '../translations.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService(); // Твій сервіс

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  bool _isPasswordVisible = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // 📧 ВХІД / РЕЄСТРАЦІЯ (З ОНОВЛЕНОЮ ОБРОБКОЮ ПОМИЛОК)
  // ---------------------------------------------------------------------------
  Future<void> _authenticate() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    // Базові перевірки
    if (email.isEmpty || password.isEmpty) {
      SnackbarUtils.showWarning(context, AppText.get('err_fill_all'));
      return;
    }

    if (password.length < 6) { // Виправив на 6, бо Firebase мінімум 6
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
        // 🔥 ВХІД через твій сервіс
        await _authService.signInWithEmail(email, password);
        if (mounted) SnackbarUtils.showSuccess(context, AppText.get('msg_welcome'));
      } else {
        // 🔥 РЕЄСТРАЦІЯ через твій сервіс
        await _authService.signUpWithEmail(email, password, name);
        if (mounted) SnackbarUtils.showSuccess(context, AppText.get('msg_account_created'));
      }

      // Якщо успіх — нічого не робимо, StreamBuilder сам оновить екран

    } on FirebaseAuthException catch (e) {
      // 🔥🔥🔥 ОСЬ ТУТ МАГІЯ: Перехоплюємо коди Firebase і даємо переклад
      String errorMessage = AppText.get('err_general');

      switch (e.code) {
        case 'invalid-credential': // Головна помилка (невірний логін/пароль)
        case 'user-not-found':
        case 'wrong-password':
          errorMessage = AppText.get('err_login_bad');
          break;
        case 'email-already-in-use':
          errorMessage = AppText.get('err_user_exists');
          break;
        case 'invalid-email':
          errorMessage = AppText.get('err_email_bad');
          break;
        case 'weak-password':
          errorMessage = AppText.get('err_pass_weak');
          break;
        case 'too-many-requests':
          errorMessage = AppText.get('err_too_many_requests');
          break;
      }

      if (mounted) {
        SnackbarUtils.showError(context, errorMessage);
      }
    } catch (e) {
      // Інші помилки
      if (mounted) {
        SnackbarUtils.showError(context, ErrorHandler.getMessage(e));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // 🔑 СКИНУТИ ПАРОЛЬ
  // ---------------------------------------------------------------------------
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
      await _authService.resetPassword(email);
      if (mounted) {
        SnackbarUtils.showSuccess(context, AppText.get('msg_email_sent'));
      }
    } catch (e) {
      if (mounted) {
        SnackbarUtils.showError(context, ErrorHandler.getMessage(e));
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 🔵 GOOGLE SIGN IN
  // ---------------------------------------------------------------------------
  Future<void> _googleSignInFunc() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        SnackbarUtils.showSuccess(context, AppText.get('msg_welcome'));
      }
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, ErrorHandler.getMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------------------------------------------------------------------------
  // ⚫ GITHUB SIGN IN
  // ---------------------------------------------------------------------------
  Future<void> _githubSignInFunc() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.signInWithGitHub(context);
      if (user != null && mounted) {
        SnackbarUtils.showSuccess(context, AppText.get('msg_welcome'));
      }
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

              // Поле Ім'я (тільки для реєстрації)
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

              // Поле Email
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

              // Поле Пароль
              TextField(
                controller: _passwordController,
                obscureText: !_isPasswordVisible,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: AppText.get('password_field'),
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  suffixIcon: IconButton(
                    icon: Icon(
                        _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                        color: Colors.grey
                    ),
                    onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                  ),
                ),
              ),

              // Кнопка "Забули пароль?" (ТІЛЬКИ ПРИ ВХОДІ)
              if (_isLogin)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    child: Text(AppText.get('forgot_pass'), style: const TextStyle(color: Colors.grey)),
                  ),
                ),

              const SizedBox(height: 20),

              // Кнопка Входу/Реєстрації
              ElevatedButton(
                onPressed: _isLoading ? null : _authenticate,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 4,
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                    _isLogin ? AppText.get('login_btn') : AppText.get('signup_btn'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
              ),

              const SizedBox(height: 20),

              // Перемикач "Вже є акаунт?"
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                      _isLogin ? AppText.get('no_account') : AppText.get('has_account'),
                      style: TextStyle(color: textColor)
                  ),
                  const SizedBox(width: 5),
                  GestureDetector(
                    onTap: () => setState(() {
                      _isLogin = !_isLogin;
                      _emailController.clear();
                      _passwordController.clear();
                      _nameController.clear();
                    }),
                    child: Text(
                      _isLogin ? AppText.get('create_one') : AppText.get('enter_one'),
                      style: TextStyle(color: Colors.green.shade600, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // Розділювач
              Row(children: [
                const Expanded(child: Divider()),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(AppText.get('or_continue'), style: const TextStyle(color: Colors.grey))),
                const Expanded(child: Divider())
              ]),

              const SizedBox(height: 20),

              // Соц. мережі
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
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
            ]
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}