import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../translations.dart' hide languageNotifier, themeNotifier;
import 'stats_screen.dart';
import 'faq_screen.dart';
// import '../notification_service.dart';
import 'family_screen.dart';
import '../chat_service.dart';
import '../subscription_service.dart';
import '../premium_screen.dart';
import '../global.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  bool _isPremium = false;
  bool _isLoadingData = true;
  String? _avatarBase64;
  String _displayName = "User";
  String? _householdId;
  Stream<int>? _unreadStream;
  final TextEditingController _nameController = TextEditingController();
  bool _isEditingName = false;
  bool _isLoadingImage = false;

  @override
  void initState() {
    super.initState();
    _displayName = user.displayName ?? "Гість";
    _nameController.text = _displayName;

    SubscriptionService().init().then((_) {
      _checkPremiumStatus();
    });

    _loadSettingsAndProfile();
  }

  Future<void> _checkPremiumStatus() async {
    bool status = SubscriptionService().isPremium;
    if(mounted) setState(() => _isPremium = status);
  }

  Future<void> _handlePremiumButton() async {
    if (_isPremium) {
      await SubscriptionService().openManagementPage();
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const PremiumScreen()));
      _checkPremiumStatus();
    }
  }

  Future<void> _loadSettingsAndProfile() async {
    setState(() => _isLoadingData = true);
    try {
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data()!;
        if (mounted) {
          setState(() {
            if (data.containsKey('avatar_base64')) _avatarBase64 = data['avatar_base64'];
            if (data.containsKey('displayName')) {
              _displayName = data['displayName'];
              _nameController.text = _displayName;
            }
            if (data.containsKey('householdId')) {
              _householdId = data['householdId'];
              _unreadStream = ChatService().getUnreadCountStream(_householdId!);
            }
            if (data.containsKey('settings')) {
              final settings = data['settings'] as Map<String, dynamic>;
              bool dbIsDark = settings['is_dark_mode'] ?? false;
              themeNotifier.value = dbIsDark ? ThemeMode.dark : ThemeMode.light;
              if (settings.containsKey('language')) languageNotifier.value = settings['language'];
            }
            _isLoadingData = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoadingData = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  Future<void> _pickAndSaveImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() => _isLoadingImage = true);
    try {
      Uint8List? compressedBytes = await FlutterImageCompress.compressWithFile(image.path, minWidth: 300, minHeight: 300, quality: 60);
      if (compressedBytes == null) throw "Error";
      String base64String = base64Encode(compressedBytes);
      setState(() => _avatarBase64 = base64String);
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'avatar_base64': base64String}, SetOptions(merge: true));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Помилка завантаження фото'), backgroundColor: Colors.red));
    } finally {
      setState(() => _isLoadingImage = false);
    }
  }

  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;
    setState(() { _displayName = newName; _isEditingName = false; });
    await user.updateDisplayName(newName);
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({'displayName': newName}, SetOptions(merge: true));
  }

  void _updateSettings(String key, dynamic value) {
    FirebaseFirestore.instance.collection('users').doc(user.uid).set({'settings': { key: value }}, SetOptions(merge: true));
  }

  void _toggleDarkMode(bool val) {
    themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
    _updateSettings('is_dark_mode', val);
  }

  Future<void> _openMyLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('GPS вимкнено. Увімкніть геолокацію.'), backgroundColor: Colors.orange));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) return;

    if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppText.get('searching_loc') ?? "Шукаю вашу локацію..."), backgroundColor: Colors.blue));

    try {
      // 👇 ВИПРАВЛЕНИЙ РЯДОК: Використовуємо 'desiredAccuracy' замість 'locationSettings'
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      final url = Uri.parse("https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}");

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not open maps';
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Помилка: $e'), backgroundColor: Colors.red));
    }
  }

  void _showLanguageDialog() {
    showModalBottomSheet(context: context, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => Container(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(AppText.get('select_lang'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 20), _langOpt("Українська", "🇺🇦"), _langOpt("English", "🇺🇸"), _langOpt("Español", "🇪🇸"), _langOpt("Français", "🇫🇷"), _langOpt("Deutsch", "🇩🇪")])));
  }

  Widget _langOpt(String lang, String flag) { return ListTile(leading: Text(flag, style: const TextStyle(fontSize: 24)), title: Text(lang), onTap: () { languageNotifier.value = lang; _updateSettings('language', lang); Navigator.pop(context); }); }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, currentLang, child) {
          final bool isRealDarkMode = Theme.of(context).brightness == Brightness.dark;
          final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
          final cardColor = Theme.of(context).cardTheme.color ?? (isRealDarkMode ? Colors.grey[800] : Colors.white);
          final dividerColor = Theme.of(context).dividerColor;
          const tilePadding = EdgeInsets.symmetric(horizontal: 24, vertical: 16);

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(title: Text(AppText.get('my_profile'), style: const TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Theme.of(context).appBarTheme.backgroundColor, centerTitle: true, actions: [IconButton(icon: const Icon(Icons.logout), onPressed: () => FirebaseAuth.instance.signOut())]),
            body: _isLoadingData ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
              child: Column(children: [
                const SizedBox(height: 30),

                Center(child: Stack(children: [Container(width: 120, height: 120, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.green, width: 3), color: Colors.green.shade100, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)]), child: ClipOval(child: _isLoadingImage ? const Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()) : _avatarBase64 != null ? Image.memory(base64Decode(_avatarBase64!), fit: BoxFit.cover, gaplessPlayback: true) : user.photoURL != null ? Image.network(user.photoURL!, fit: BoxFit.cover) : Icon(Icons.person, size: 70, color: Colors.green.shade400))), Positioned(bottom: 0, right: 0, child: InkWell(onTap: _pickAndSaveImage, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle), child: const Icon(Icons.camera_alt, color: Colors.white, size: 20))))])),

                const SizedBox(height: 15),

                if (_isEditingName) Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Row(children: [Expanded(child: TextField(controller: _nameController, textAlign: TextAlign.center, style: TextStyle(color: textColor, fontSize: 20, fontWeight: FontWeight.bold))), IconButton(icon: const Icon(Icons.check, color: Colors.green), onPressed: _updateName), IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => _isEditingName = false))])) else Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_displayName, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)), IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.grey), onPressed: () => setState(() => _isEditingName = true))]),

                if (user.email != null && user.email!.isNotEmpty) Text(user.email!, style: TextStyle(fontSize: 16, color: textColor.withOpacity(0.6))),
                const SizedBox(height: 30),

                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _handlePremiumButton,
                    icon: Icon(_isPremium ? Icons.check_circle : Icons.star, color: Colors.white),
                    label: Text(
                        _isPremium ? AppText.get('prem_active') : AppText.get('prem_btn_buy'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)
                    ),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _isPremium ? Colors.green : Colors.amber,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 6
                    ),
                  ),
                ),

                Container(margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10), width: double.infinity, child: ElevatedButton.icon(onPressed: _openMyLocation, icon: const Icon(Icons.location_on, color: Colors.white), label: Text(AppText.get('map_btn') ?? "My Location", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 4))),

                Container(margin: const EdgeInsets.fromLTRB(16, 20, 16, 40), padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(24), border: Border.all(color: dividerColor.withOpacity(0.05)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))]), child: Column(children: [

                  ListTile(contentPadding: tilePadding, leading: _buildIcon(Icons.pie_chart, Colors.purple), title: Text(AppText.get('stats_title'), style: _tileStyle(textColor)), trailing: _arrow(), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()))),
                  const Divider(height: 1),

                  ListTile(contentPadding: tilePadding, leading: _buildIcon(Icons.help_outline, Colors.teal), title: Text(AppText.get('faq_title'), style: _tileStyle(textColor)), trailing: _arrow(), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const FaqScreen()))),
                  const Divider(height: 1),

                  ListTile(
                      contentPadding: tilePadding,
                      leading: _buildIcon(Icons.people, Colors.pink),
                      title: Row(children: [Text(AppText.get('family_settings') ?? "My Family", style: _tileStyle(textColor)), if (!_isPremium) const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.lock, size: 16, color: Colors.grey))]),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (_householdId != null && _isPremium) StreamBuilder<int>(stream: _unreadStream, builder: (context, snap) { if (!snap.hasData || snap.data == 0) return const SizedBox(); return Container(margin: const EdgeInsets.only(right: 10), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)), child: Text(snap.data! > 99 ? "99+" : "${snap.data!}", style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))); }), _arrow()]),
                      onTap: () { if (!_isPremium) { _handlePremiumButton(); } else { Navigator.push(context, MaterialPageRoute(builder: (context) => const FamilyScreen())); } }
                  ),

                  const Divider(height: 1),
                  SwitchListTile(contentPadding: tilePadding, secondary: _buildIcon(Icons.dark_mode, Colors.deepPurple, bgColor: Colors.grey.shade200), title: Text(AppText.get('theme_dark') ?? "Dark Mode", style: _tileStyle(textColor)), value: isRealDarkMode, onChanged: _toggleDarkMode, activeColor: Colors.deepPurple),
                  const Divider(height: 1),
                  ListTile(contentPadding: tilePadding, leading: _buildIcon(Icons.language, Colors.blue), title: Text(AppText.get('language') ?? "Language", style: _tileStyle(textColor)), trailing: _arrow(), onTap: () => _showLanguageDialog()),
                ])),
              ]),
            ),
          );
        }
    );
  }

  Widget _buildIcon(IconData icon, Color color, {Color? bgColor}) { return Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: bgColor ?? color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 24)); }
  TextStyle _tileStyle(Color color) => TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: color);
  Widget _arrow() => const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: Colors.grey);
}