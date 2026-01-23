import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Для копіювання
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../translations.dart';
import '../household_service.dart';
import '../chat_service.dart';
import '../chat_screen.dart';
import '../global.dart';
import '../utils/snackbar_utils.dart';
import '../error_handler.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final user = FirebaseAuth.instance.currentUser!;
  final ChatService _chatService = ChatService();
  final HouseholdService _householdService = HouseholdService();

  String? _householdId;
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _syncUserProfile(); // 🔥 Оновлюємо профіль у базі при вході
    _loadFamilyData();
  }

  // 🔥 СИНХРОНІЗАЦІЯ: Щоб ім'я в базі точно співпадало з профілем
  Future<void> _syncUserProfile() async {
    if (user.displayName != null && user.displayName != 'User') {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'displayName': user.displayName,
          'email': user.email,
          'photoURL': user.photoURL
        }, SetOptions(merge: true));
      } catch (e) {
        // Тихо ігноруємо помилки фонового оновлення
      }
    }
  }

  Future<void> _loadFamilyData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

      if (userDoc.exists && userDoc.data() != null && userDoc.data()!.containsKey('householdId')) {
        setState(() {
          _householdId = userDoc.data()!['householdId'];
        });
        await _checkAdminStatus();
      } else {
        setState(() {
          _householdId = null;
          _isAdmin = false;
        });
      }
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, ErrorHandler.getMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _checkAdminStatus() async {
    if (_householdId == null) return;
    try {
      final houseDoc = await FirebaseFirestore.instance.collection('households').doc(_householdId).get();
      if (houseDoc.exists) {
        final adminId = houseDoc.data()?['adminId'];
        if (mounted) setState(() => _isAdmin = adminId == user.uid);
      }
    } catch (e) {
      debugPrint("Error checking admin: $e");
    }
  }

  Future<void> _createFamily() async {
    showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final houseRef = FirebaseFirestore.instance.collection('households').doc();
      String inviteCode = houseRef.id.substring(0, 6).toUpperCase();

      await houseRef.set({
        'adminId': user.uid,
        'members': [user.uid],
        'requests': [],
        'createdAt': Timestamp.now(),
        'inviteCode': inviteCode,
      });

      // Оновлюємо дані користувача
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'householdId': houseRef.id,
        'displayName': user.displayName ?? 'User',
        'email': user.email,
        'photoURL': user.photoURL,
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pop(context);
        await _loadFamilyData();
        SnackbarUtils.showSuccess(context, "Сім'ю створено! 🏠");
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        SnackbarUtils.showError(context, ErrorHandler.getMessage(e));
      }
    }
  }

  Future<void> _joinFamily() async {
    final controller = TextEditingController();
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(AppText.get('fam_join')),
          content: TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                  hintText: "CODE",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true
              )
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppText.get('cancel'))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () async {
                  Navigator.pop(ctx);
                  final code = controller.text.trim().toUpperCase();
                  if (code.isEmpty) return;

                  try {
                    // Оновлюємо дані перед запитом
                    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
                      'uid': user.uid,
                      'displayName': user.displayName ?? 'User',
                      'email': user.email,
                      'photoURL': user.photoURL,
                    }, SetOptions(merge: true));

                    final query = await FirebaseFirestore.instance
                        .collection('households')
                        .where('inviteCode', isEqualTo: code)
                        .limit(1)
                        .get();

                    if (query.docs.isEmpty) {
                      throw "Сім'ю з таким кодом не знайдено";
                    }

                    final houseDoc = query.docs.first;
                    final members = List<String>.from(houseDoc.data()['members'] ?? []);
                    final requests = List<String>.from(houseDoc.data()['requests'] ?? []);

                    if (members.contains(user.uid)) {
                      throw "Ви вже у цій сім'ї";
                    }
                    if (requests.contains(user.uid)) {
                      throw "Ви вже подали запит";
                    }

                    await houseDoc.reference.update({
                      'requests': FieldValue.arrayUnion([user.uid])
                    });

                    if (mounted) SnackbarUtils.showSuccess(context, AppText.get('req_sent'));
                  } catch (e) {
                    if (mounted) SnackbarUtils.showError(context, ErrorHandler.getMessage(e));
                  }
                },
                child: Text(AppText.get('fam_join'))
            ),
          ],
        )
    );
  }

  Future<void> _handleRequest(String householdId, String userId, bool accept) async {
    try {
      final batch = FirebaseFirestore.instance.batch();
      final houseRef = FirebaseFirestore.instance.collection('households').doc(householdId);
      final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

      if (accept) {
        batch.update(houseRef, {
          'members': FieldValue.arrayUnion([userId]),
          'requests': FieldValue.arrayRemove([userId])
        });

        batch.set(userRef, {
          'householdId': householdId
        }, SetOptions(merge: true));

      } else {
        batch.update(houseRef, {
          'requests': FieldValue.arrayRemove([userId])
        });
      }

      await batch.commit();

      if (mounted) {
        if (accept) {
          SnackbarUtils.showSuccess(context, "Користувача додано! 🎉");
        } else {
          SnackbarUtils.showWarning(context, "Запит відхилено");
        }
      }
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, ErrorHandler.getMessage(e));
    }
  }

  Future<void> _leaveFamily() async {
    if (_householdId == null) return;

    bool? confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("${AppText.get('fam_leave')}?"),
        content: const Text("Ви впевнені, що хочете вийти?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppText.get('cancel'))),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppText.get('fam_leave'))
          ),
        ]
    ));

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        final batch = FirebaseFirestore.instance.batch();
        final houseRef = FirebaseFirestore.instance.collection('households').doc(_householdId);
        final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

        batch.update(houseRef, {
          'members': FieldValue.arrayRemove([user.uid])
        });

        batch.update(userRef, {
          'householdId': FieldValue.delete()
        });

        await batch.commit();

        await _loadFamilyData();
        if(mounted) SnackbarUtils.showSuccess(context, "Ви покинули сім'ю 👋");

      } catch (e) {
        if(mounted) SnackbarUtils.showError(context, ErrorHandler.getMessage(e));
      } finally {
        if(mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _removeMember(String householdId, String uid, String name) async {
    bool? confirm = await showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text("${AppText.get('dialog_delete_title')} $name?"),
      content: Text(AppText.get('dialog_delete_content')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppText.get('btn_no'))),
        ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppText.get('btn_yes'))
        ),
      ],
    ));

    if (confirm == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        final houseRef = FirebaseFirestore.instance.collection('households').doc(householdId);
        final targetUserRef = FirebaseFirestore.instance.collection('users').doc(uid);

        batch.update(houseRef, { 'members': FieldValue.arrayRemove([uid]) });
        batch.update(targetUserRef, { 'householdId': FieldValue.delete() });

        await batch.commit();
        if(mounted) SnackbarUtils.showSuccess(context, "Учасника видалено");
      } catch (e) {
        if(mounted) SnackbarUtils.showError(context, ErrorHandler.getMessage(e));
      }
    }
  }

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    SnackbarUtils.showSuccess(context, AppText.get('msg_code_copied'));
  }

  void _openDm(String memberId, String memberName) {
    if (memberId == user.uid) return;
    String dmChatId = _chatService.getDmChatId(user.uid, memberId);
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: dmChatId, isDirect: true, chatTitle: memberName)));
  }

  Widget _buildSmartAvatar(String? base64, String? photoUrl, double radius) {
    if (base64 != null && base64.isNotEmpty) {
      try {
        return CircleAvatar(radius: radius, backgroundImage: MemoryImage(base64Decode(base64)));
      } catch (e) {
        return CircleAvatar(radius: radius, child: const Icon(Icons.person));
      }
    }
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: NetworkImage(photoUrl));
    }
    return CircleAvatar(radius: radius, child: const Icon(Icons.person));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = Theme.of(context).scaffoldBackgroundColor;
        final textColor = Theme.of(context).textTheme.bodyLarge?.color;
        final cardColor = Theme.of(context).cardColor;
        final codeBgColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF1F8E9);

        if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        if (_householdId == null) {
          return Scaffold(
            backgroundColor: bgColor,
            appBar: AppBar(title: Text(AppText.get('family_settings'), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)), centerTitle: true, backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: textColor)),
            body: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(padding: const EdgeInsets.all(35), decoration: BoxDecoration(color: Colors.green.shade100, shape: BoxShape.circle), child: Icon(Icons.family_restroom_rounded, size: 90, color: Colors.green.shade600)),
                  const SizedBox(height: 30),
                  Text(
                    AppText.get('fam_welcome_title'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    AppText.get('fam_welcome_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 50),
                  SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(onPressed: _createFamily, icon: const Icon(Icons.add, color: Colors.white), label: Text(AppText.get('fam_create'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
                  const SizedBox(height: 20),
                  SizedBox(width: double.infinity, height: 55, child: OutlinedButton.icon(onPressed: _joinFamily, icon: const Icon(Icons.link, color: Colors.green), label: Text(AppText.get('fam_join'), style: const TextStyle(fontSize: 18, color: Colors.green)), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.green, width: 2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))))),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
              title: Text(AppText.get('family_settings'), style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              centerTitle: true,
              backgroundColor: bgColor,
              elevation: 0,
              iconTheme: IconThemeData(color: textColor),
              actions: [
                IconButton(onPressed: _leaveFamily, icon: const Icon(Icons.logout, color: Colors.red), tooltip: AppText.get('fam_leave'))
              ]
          ),
          body: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('households').doc(_householdId).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasData && !snapshot.data!.exists) {
                FirebaseFirestore.instance.collection('users').doc(user.uid).update({'householdId': FieldValue.delete()});
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

              final hData = snapshot.data!.data() as Map<String, dynamic>;
              final List<dynamic> requests = hData['requests'] ?? [];
              final String inviteCode = hData['inviteCode'] ?? "???";
              final String adminId = hData['adminId'];

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').where('householdId', isEqualTo: _householdId).snapshots(),
                builder: (ctx, membersSnap) {
                  if (!membersSnap.hasData) return const Center(child: CircularProgressIndicator());

                  final membersList = membersSnap.data!.docs.map((d) {
                    final data = d.data() as Map<String, dynamic>;
                    String name = data['displayName'] ?? 'User';

                    // 🔥 ФІКС ІМЕНІ: Якщо це я, і в базі 'User', але в Auth є ім'я - беремо з Auth
                    if (d.id == user.uid) {
                      if (user.displayName != null && user.displayName!.isNotEmpty) {
                        name = user.displayName!;
                      }
                    }

                    return {
                      'uid': d.id,
                      'name': name,
                      'avatar': data['avatar_base64'],
                      'photoURL': data['photoURL'],
                    };
                  }).toList();

                  membersList.sort((a, b) => (a['uid'] == adminId) ? -1 : 1);

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        if (_isAdmin && requests.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: isDark ? Colors.orange.withOpacity(0.1) : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.orange.shade200)
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.notifications_active, color: Colors.deepOrange),
                                  const SizedBox(width: 10),
                                  Text(AppText.get('fam_requests'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange)),
                                ]),
                                const SizedBox(height: 10),
                                ...requests.map((uid) => FutureBuilder<DocumentSnapshot>(
                                  future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
                                  builder: (context, snap) {
                                    String name = "Unknown";
                                    String? avatar;
                                    String? photoUrl;

                                    if (snap.hasData && snap.data!.exists) {
                                      final uData = snap.data!.data() as Map<String, dynamic>?;
                                      name = uData?['displayName'] ?? "User";
                                      avatar = uData?['avatar_base64'];
                                      photoUrl = uData?['photoURL'];
                                    }

                                    return Card(
                                      color: cardColor,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      child: ListTile(
                                        leading: _buildSmartAvatar(avatar, photoUrl, 20),
                                        title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                                        subtitle: Text(AppText.get('fam_wants_join'), style: const TextStyle(fontSize: 12)),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () => _handleRequest(_householdId!, uid, true)),
                                            IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => _handleRequest(_householdId!, uid, false)),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                )),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        SizedBox(
                          width: double.infinity,
                          height: 60,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(chatId: _householdId!, chatTitle: AppText.get('chat_title')))),
                            icon: const Icon(Icons.chat_bubble, color: Colors.white),
                            label: Text(AppText.get('chat_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                          ),
                        ),
                        const SizedBox(height: 30),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                          child: Column(children: [
                            Text(AppText.get('fam_code'), style: const TextStyle(color: Colors.grey)),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => _copyCode(inviteCode),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 10),
                                decoration: BoxDecoration(color: codeBgColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green.withOpacity(0.3))),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Text(inviteCode, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 2)),
                                  const SizedBox(width: 10),
                                  const Icon(Icons.copy, color: Colors.green)
                                ]),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(AppText.get('fam_copy'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ]),
                        ),

                        const SizedBox(height: 30),
                        Text("${AppText.get('fam_members')} (${membersList.length})", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 15),

                        ...membersList.map((m) {
                          String uid = m['uid'];
                          String name = m['name'];
                          String? avatar = m['avatar'];
                          String? photoURL = m['photoURL'];

                          bool isMe = uid == user.uid;
                          bool isMemberAdmin = uid == adminId;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: isMemberAdmin ? Border.all(color: Colors.amber.withOpacity(0.5), width: 1.5) : null,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)]
                            ),
                            child: ListTile(
                              leading: _buildSmartAvatar(avatar, photoURL, 24),
                              title: Row(children: [
                                Flexible(child: Text(name, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: textColor))),
                                if (isMe) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(6)), child: Text(AppText.get('fam_you_tag'), style: TextStyle(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold))),
                              ]),
                              subtitle: Text(isMemberAdmin ? AppText.get('fam_admin') : AppText.get('fam_member'), style: TextStyle(color: isMemberAdmin ? Colors.orange : Colors.grey, fontSize: 12, fontWeight: isMemberAdmin ? FontWeight.bold : FontWeight.normal)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isMe) IconButton(icon: CircleAvatar(radius: 18, backgroundColor: Colors.blue.withOpacity(0.1), child: const Icon(Icons.message, size: 18, color: Colors.blue)), onPressed: () => _openDm(uid, name)),
                                  if (_isAdmin && !isMe) IconButton(icon: CircleAvatar(radius: 18, backgroundColor: Colors.red.withOpacity(0.1), child: const Icon(Icons.delete, size: 18, color: Colors.red)), onPressed: () => _removeMember(_householdId!, uid, name)),
                                ],
                              ),
                            ),
                          );
                        }).toList(),

                        const SizedBox(height: 50),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}