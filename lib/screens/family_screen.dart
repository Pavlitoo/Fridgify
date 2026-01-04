import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../translations.dart';
import '../household_service.dart';
import '../chat_service.dart';
import '../chat_screen.dart';
import '../global.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  final HouseholdService _householdService = HouseholdService();
  final ChatService _chatService = ChatService();

  bool _isLoading = true;
  String? _householdId;
  String? _inviteCode;
  String? _adminId;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _loadFamilyData();
  }

  Future<void> _loadFamilyData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final userData = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      _householdId = userData.data()?['householdId'];

      if (_householdId != null) {
        final householdData = await FirebaseFirestore.instance.collection('households').doc(_householdId).get();
        if (householdData.exists) {
          _inviteCode = householdData.data()?['inviteCode'];
          _adminId = householdData.data()?['adminId'];

          final membersSnap = await FirebaseFirestore.instance.collection('users').where('householdId', isEqualTo: _householdId).get();
          _members = membersSnap.docs.map((d) => {
            'uid': d.id,
            'name': d.data()['displayName'] ?? 'User',
            'email': d.data()['email'],
            'avatar': d.data()['avatar_base64'],
          }).toList();
        } else {
          _householdId = null;
        }
      }
    } catch (e) { /* ignore */ }
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _createFamily() async {
    setState(() => _isLoading = true);
    await _householdService.createHousehold("Сім'я ${user.displayName ?? 'User'}");
    await _loadFamilyData();
  }

  Future<void> _joinFamily() async {
    final controller = TextEditingController();
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text("Введіть код сім'ї"), // Можна теж додати в переклад
      content: TextField(controller: controller, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(hintText: "Код (6 символів)", border: OutlineInputBorder())),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppText.get('cancel'))),
        ElevatedButton(onPressed: () async {
          Navigator.pop(ctx);
          setState(() => _isLoading = true);
          try {
            await _householdService.requestToJoin(controller.text.trim().toUpperCase());
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OK"), backgroundColor: Colors.green));
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
          }
          setState(() => _isLoading = false);
        }, child: Text(AppText.get('fam_join'))),
      ],
    ));
  }

  Future<void> _leaveFamily() async {
    if (_householdId == null) return;
    bool? confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
        title: Text(AppText.get('fam_leave') + "?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppText.get('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppText.get('fam_leave'), style: const TextStyle(color: Colors.red))),
        ]
    ));
    if (confirm == true) {
      setState(() => _isLoading = true);
      await _householdService.leaveHousehold();
      await _loadFamilyData();
    }
  }

  Future<void> _removeMember(String uid) async {
    bool? confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
      title: Text(AppText.get('no_delete') + "?"),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppText.get('cancel'))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppText.get('no_delete'), style: const TextStyle(color: Colors.red))),
      ],
    ));
    if (confirm == true && _householdId != null) {
      await _householdService.removeMember(_householdId!, uid);
      _loadFamilyData();
    }
  }

  Future<void> _handleRequest(String userId, bool accept) async {
    if (_householdId == null) return;
    try {
      if (accept) {
        await _householdService.acceptRequest(_householdId!, userId);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("OK"), backgroundColor: Colors.green));
        _loadFamilyData();
      } else {
        await _householdService.rejectRequest(_householdId!, userId);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted"), backgroundColor: Colors.red));
      }
    } catch (e) { /* ignore */ }
  }

  void _copyCode() {
    if (_inviteCode != null) {
      Clipboard.setData(ClipboardData(text: _inviteCode!));
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copied!")));
    }
  }

  void _openChat() {
    if (_householdId != null) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: _householdId!, chatTitle: AppText.get('chat_title'))));
    }
  }

  void _openDm(String memberId, String memberName) {
    if (memberId == user.uid) return;
    String dmChatId = _chatService.getDmChatId(user.uid, memberId);
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: dmChatId, isDirect: true, chatTitle: memberName)));
  }

  Widget _buildSmartAvatar(String? base64, String? uid) {
    if (base64 != null && base64.isNotEmpty) {
      try {
        return ClipOval(child: Image.memory(base64Decode(base64), fit: BoxFit.cover, width: 40, height: 40));
      } catch (e) { return const Icon(Icons.person, color: Colors.grey); }
    }
    if (uid != null) {
      return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
          builder: (context, snapshot) {
            if (snapshot.hasData && snapshot.data != null) {
              final d = snapshot.data!.data() as Map<String, dynamic>?;
              final live = d?['avatar_base64'];
              if (live != null) {
                try {
                  return ClipOval(child: Image.memory(base64Decode(live), fit: BoxFit.cover, width: 40, height: 40));
                } catch (e) { return const Icon(Icons.person, color: Colors.grey); }
              }
            }
            return const Icon(Icons.person, color: Colors.grey);
          }
      );
    }
    return const Icon(Icons.person, color: Colors.grey);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, lang, child) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final textColor = Theme.of(context).textTheme.bodyLarge?.color;
          final cardColor = Theme.of(context).cardColor;
          final bool isAdmin = _adminId == user.uid;

          final requestBgColor = isDark ? const Color(0xFF2E2E2E) : Colors.orange.shade50;
          final requestBorderColor = isDark ? Colors.orangeAccent : Colors.orange.shade200;
          final requestTextColor = isDark ? Colors.orangeAccent : Colors.deepOrange;

          if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

          if (_householdId == null) {
            return Scaffold(
              backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
              appBar: AppBar(title: Text(AppText.get('family_settings')), centerTitle: true, backgroundColor: Colors.transparent, elevation: 0),
              body: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: Colors.green.shade100, shape: BoxShape.circle), child: Icon(Icons.family_restroom_rounded, size: 80, color: Colors.green.shade700)),
                    const SizedBox(height: 30),
                    // Тут можна додати переклад, якщо хочеш
                    const Text("Об'єднайтеся з родиною!", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    const Text("Створіть спільний простір для продуктів та списку покупок.", style: TextStyle(fontSize: 16, color: Colors.grey), textAlign: TextAlign.center),
                    const SizedBox(height: 40),

                    SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(onPressed: _createFamily, icon: const Icon(Icons.add_circle_outline, color: Colors.white), label: Text(AppText.get('fam_create'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
                    const SizedBox(height: 16),
                    SizedBox(width: double.infinity, height: 55, child: OutlinedButton.icon(onPressed: _joinFamily, icon: const Icon(Icons.login), label: Text(AppText.get('fam_join'), style: const TextStyle(fontSize: 18)), style: OutlinedButton.styleFrom(foregroundColor: isDark ? Colors.white : Colors.black87, side: BorderSide(color: isDark ? Colors.white54 : Colors.grey.shade400), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
                  ],
                ),
              ),
            );
          }

          return Scaffold(
            backgroundColor: isDark ? null : Colors.green.shade50,
            appBar: AppBar(title: Text(AppText.get('family_settings')), centerTitle: true, backgroundColor: isDark ? null : Colors.green.shade100, actions: [IconButton(onPressed: _leaveFamily, icon: const Icon(Icons.exit_to_app, color: Colors.red))]),
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (isAdmin)
                    StreamBuilder<QuerySnapshot>(
                      stream: _householdService.getRequestsStream(_householdId!),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const SizedBox.shrink();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: requestBgColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: requestBorderColor)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 👇 ВИПРАВЛЕНО: ТЕКСТ ІЗ ПЕРЕКЛАДУ
                              Text(AppText.get('fam_requests'), style: TextStyle(fontWeight: FontWeight.bold, color: requestTextColor)),
                              const SizedBox(height: 10),
                              ...snapshot.data!.docs.map((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(radius: 20, backgroundColor: Colors.grey.shade300, child: _buildSmartAvatar(data['avatar'], data['uid'])),
                                  title: Text(data['name'] ?? "Unknown", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.check_circle, color: Colors.green, size: 32), onPressed: () => _handleRequest(data['uid'], true)), IconButton(icon: const Icon(Icons.cancel, color: Colors.red, size: 32), onPressed: () => _handleRequest(data['uid'], false))]),
                                );
                              }),
                            ],
                          ),
                        );
                      },
                    ),

                  ElevatedButton.icon(onPressed: _openChat, icon: const Icon(Icons.chat_bubble_outline), label: Text(AppText.get('chat_title')), style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)))),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                    child: Column(children: [Text(AppText.get('fam_code'), style: const TextStyle(fontSize: 14, color: Colors.grey)), const SizedBox(height: 10), GestureDetector(onTap: _copyCode, child: Container(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.green.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green.shade200)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(_inviteCode ?? "ERROR", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 2)), const SizedBox(width: 10), const Icon(Icons.copy, color: Colors.green)]))), const SizedBox(height: 10), Text(AppText.get('fam_copy'), style: const TextStyle(fontSize: 12, color: Colors.grey))]),
                  ),

                  const SizedBox(height: 25),
                  Align(alignment: Alignment.centerLeft, child: Text("${AppText.get('fam_members')} (${_members.length})", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor))),
                  const SizedBox(height: 10),

                  ..._members.map((m) {
                    bool isMe = m['uid'] == user.uid;
                    bool isMemberAdmin = m['uid'] == _adminId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)]),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(radius: 24, backgroundColor: isMemberAdmin ? Colors.orange.shade100 : Colors.green.shade100, child: _buildSmartAvatar(m['avatar'], m['uid'])),
                        title: Row(children: [
                          // 👇 ВИПРАВЛЕНО: ТЕКСТ "Я" ІЗ ПЕРЕКЛАДУ
                          Text(m['name'] + (isMe ? AppText.get('fam_me') : ""), style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal, fontSize: 16, color: textColor)),
                          if (isMemberAdmin) const Padding(padding: EdgeInsets.only(left: 5), child: Icon(Icons.star, color: Colors.orange, size: 16))
                        ]),
                        subtitle: Text(isMemberAdmin ? AppText.get('fam_admin') : AppText.get('fam_member'), style: TextStyle(color: isMemberAdmin ? Colors.orange : Colors.grey, fontSize: 12, fontWeight: isMemberAdmin ? FontWeight.bold : FontWeight.normal)),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [if (!isMe) IconButton(icon: const Icon(Icons.message, color: Colors.blueAccent), onPressed: () => _openDm(m['uid'], m['name'])), if (isAdmin && !isMe) IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _removeMember(m['uid']))]),
                      ),
                    );
                  }).toList(),

                  const SizedBox(height: 20),
                  TextButton.icon(onPressed: _leaveFamily, icon: const Icon(Icons.exit_to_app, color: Colors.red), label: Text(AppText.get('fam_leave'), style: const TextStyle(color: Colors.red, fontSize: 16))),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          );
        }
    );
  }
}