import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'translations.dart'; // IMPORTANT!

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && doc.data()!.containsKey('settings')) {
      final settings = doc.data()!['settings'] as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _notificationsEnabled = settings['push_enabled'] ?? false;
          if (settings.containsKey('language')) {
            languageNotifier.value = settings['language'];
          }
        });
      }
    }
  }

  void _updateSettings(String key, dynamic value) {
    FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'settings': { key: value }
    }, SetOptions(merge: true));
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    if (value) {
      NotificationSettings settings = await FirebaseMessaging.instance.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        _updateSettings('push_enabled', true);
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notifications enabled!"), backgroundColor: Colors.green));
      } else {
        setState(() => _notificationsEnabled = false);
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Permission denied in settings"), backgroundColor: Colors.red));
      }
    } else {
      _updateSettings('push_enabled', false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, currentLang, child) {
        return Scaffold(
          backgroundColor: Colors.green.shade50,
          appBar: AppBar(
            title: Text(AppText.get('my_profile'), style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.green.shade100,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 40),
                CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.green.shade300,
                  backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                  child: user.photoURL == null
                      ? Text(user.displayName?[0].toUpperCase() ?? 'U', style: const TextStyle(fontSize: 50, color: Colors.white))
                      : null,
                ),
                const SizedBox(height: 20),
                Text(user.displayName ?? 'User', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                Text(user.email ?? '', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                const SizedBox(height: 40),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5))]),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle), child: Icon(Icons.language, color: Colors.blue.shade700)),
                        title: Text(AppText.get('language'), style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(currentLang),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                        onTap: () => _showLanguageDialog(),
                      ),
                      Divider(height: 1, color: Colors.grey.shade100, indent: 60, endIndent: 20),
                      ListTile(
                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange.shade50, shape: BoxShape.circle), child: Icon(Icons.notifications_active, color: Colors.orange.shade700)),
                        title: Text(AppText.get('push_notif'), style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(AppText.get('push_desc')),
                        trailing: Switch(value: _notificationsEnabled, activeColor: Colors.green, onChanged: _toggleNotifications),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ElevatedButton.icon(
                    onPressed: () => FirebaseAuth.instance.signOut(),
                    icon: const Icon(Icons.logout, color: Colors.white),
                    label: Text(AppText.get('logout')),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLanguageDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select Language", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _languageOption("Українська", "🇺🇦"),
              _languageOption("English", "🇺🇸"),
              _languageOption("Español", "🇪🇸"),
              _languageOption("Français", "🇫🇷"),
            ],
          ),
        );
      },
    );
  }

  Widget _languageOption(String lang, String flag) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 24)),
      title: Text(lang),
      trailing: languageNotifier.value == lang ? const Icon(Icons.check, color: Colors.green) : null,
      onTap: () {
        languageNotifier.value = lang;
        _updateSettings('language', lang);
        Navigator.pop(context);
      },
    );
  }
}