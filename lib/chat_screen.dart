import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;

import '../chat_service.dart';
import '../translations.dart';
import '../credentials.dart'; // ✅ Імпорт файлу з ключами

class ChatScreen extends StatefulWidget {
  final String chatId;
  final bool isDirect;
  final String? chatTitle;

  const ChatScreen({super.key, required this.chatId, this.isDirect = false, this.chatTitle});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _msgController = TextEditingController();
  final ChatService _chatService = ChatService();
  final user = FirebaseAuth.instance.currentUser!;
  final ScrollController _scrollController = ScrollController();

  FlutterSoundRecorder? _recorder;
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _isRecording = false;
  bool _isTextEmpty = true;
  String? _playingMsgId;
  bool _isUploading = false;
  String? _editingMsgId;
  String? _recordedFilePath;

  Map<String, String>? _replyMessage;
  static final Map<String, Uint8List> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _chatService.markAsRead(widget.chatId, isDirect: widget.isDirect);
    _setupAudioSession();
    _msgController.addListener(() {
      setState(() { _isTextEmpty = _msgController.text.trim().isEmpty; });
    });
  }

  Future<void> _initRecorder() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
    await Permission.microphone.request();
  }

  Future<void> _setupAudioSession() async {
    try {
      await _audioPlayer.setAudioContext(AudioContext(
        android: AudioContextAndroid(isSpeakerphoneOn: true, stayAwake: true, contentType: AndroidContentType.music, usageType: AndroidUsageType.media, audioFocus: AndroidAudioFocus.gain),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.playAndRecord, options: {AVAudioSessionOptions.defaultToSpeaker, AVAudioSessionOptions.allowBluetooth}),
      ));
    } catch (e) { debugPrint("Audio err: $e"); }
  }

  @override
  void dispose() {
    _recorder?.closeRecorder();
    _audioPlayer.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    _chatService.markAsRead(widget.chatId, isDirect: widget.isDirect);
    super.dispose();
  }

  void _sendMessage() {
    String text = _msgController.text.trim();
    if (text.isEmpty) return;

    if (_editingMsgId != null) {
      _chatService.editMessage(widget.chatId, _editingMsgId!, text, isDirect: widget.isDirect);
      setState(() { _editingMsgId = null; });
    } else {
      String? replyToName = _replyMessage?['sender'];

      _chatService.sendMessage(widget.chatId, text, isDirect: widget.isDirect, replyToText: _replyMessage?['text'], replyToSender: _replyMessage?['sender']);

      // 🔥 Передаємо ім'я для push-сповіщення
      _notifyRecipients(text, replyToName: replyToName);

      setState(() => _replyMessage = null);
    }
    _msgController.clear();
  }

  void _showMessageDetails(BuildContext context, List<dynamic> readBy, List<dynamic> likes) {
    showModalBottomSheet(context: context, backgroundColor: Theme.of(context).cardTheme.color, isScrollControlled: true, builder: (ctx) {
      return DraggableScrollableSheet(initialChildSize: 0.5, expand: false, builder: (context, scrollController) {
        return DefaultTabController(length: 2, child: Column(children: [
          TabBar(tabs: [Tab(text: AppText.get('chat_viewed_by')), Tab(text: AppText.get('chat_liked_by'))]),
          Expanded(child: TabBarView(children: [_buildUserList(readBy, AppText.get('chat_no_views')), _buildUserList(likes, AppText.get('chat_no_likes'))]))
        ]));
      });
    },
    );
  }

  Widget _buildUserList(List<dynamic> userIds, String emptyText) {
    if (userIds.isEmpty) return Center(child: Text(emptyText));
    return ListView.builder(itemCount: userIds.length, itemBuilder: (context, index) {
      String uid = userIds[index];
      return FutureBuilder<DocumentSnapshot>(future: FirebaseFirestore.instance.collection('users').doc(uid).get(), builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const ListTile(leading: CircularProgressIndicator(), title: Text("..."));
        if (!snap.hasData) return const SizedBox();
        var data = snap.data!.data() as Map<String, dynamic>?;
        String name = data?['displayName'] ?? 'User';
        if (uid == user.uid) name += AppText.get('suffix_me');
        return ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(name));
      });
    },
    );
  }

  void _showMsgOptions(BuildContext context, DocumentSnapshot doc, bool isMe) {
    final data = doc.data() as Map<String, dynamic>;
    final bool hasText = data['text'] != null && data['text'].toString().isNotEmpty;
    final List<dynamic> readBy = data['readBy'] ?? [];
    final List<dynamic> likes = data['likes'] ?? [];

    showModalBottomSheet(context: context, backgroundColor: Theme.of(context).cardTheme.color, builder: (ctx) {
      return Wrap(children: [
        ListTile(leading: const Icon(Icons.reply, color: Colors.blue), title: Text(AppText.get('chat_reply')), onTap: () { Navigator.pop(ctx); setState(() { String txt = data['text'] ?? (data['audioBase64'] != null ? "Voice" : "Image"); _replyMessage = {'text': txt, 'sender': data['senderName'] ?? 'User'}; }); }),
        ListTile(leading: const Icon(Icons.info_outline, color: Colors.blue), title: Text(AppText.get('chat_info')), onTap: () { Navigator.pop(ctx); _showMessageDetails(context, readBy, likes); }),
        if (isMe && hasText) ListTile(leading: const Icon(Icons.edit, color: Colors.blue), title: Text(AppText.get('chat_edit')), onTap: () { Navigator.pop(ctx); setState(() { _editingMsgId = doc.id; _msgController.text = data['text']; }); }),
        if (isMe) ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: Text(AppText.get('chat_delete')), onTap: () { Navigator.pop(ctx); _confirmDelete(doc.id); }),
      ]);
    },
    );
  }

  void _confirmDelete(String msgId) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
        title: Text(AppText.get('dialog_delete_title')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppText.get('btn_no'))),
          TextButton(onPressed: () { Navigator.pop(ctx); _chatService.deleteMessage(widget.chatId, msgId, isDirect: widget.isDirect); }, child: Text(AppText.get('btn_yes'), style: const TextStyle(color: Colors.red)))
        ]
    ));
  }

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (image == null) return;
    setState(() => _isUploading = true);
    await _chatService.sendImage(widget.chatId, File(image.path), isDirect: widget.isDirect);
    _notifyRecipients("📷 Надіслав фото");
    setState(() => _isUploading = false);
  }

  Future<void> _startRecording() async {
    try {
      Directory tempDir = await getTemporaryDirectory();
      String path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
      await _recorder!.startRecorder(toFile: path);
      setState(() { _isRecording = true; _recordedFilePath = path; });
    } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mic Error"), backgroundColor: Colors.red)); }
  }

  Future<void> _stopRecording() async {
    await _recorder!.stopRecorder();
    setState(() => _isRecording = false);
    if (_recordedFilePath != null) {
      setState(() => _isUploading = true);
      await _chatService.sendVoice(widget.chatId, _recordedFilePath!, isDirect: widget.isDirect);
      _notifyRecipients("🎤 Голосове повідомлення");
      setState(() => _isUploading = false);
    }
  }

  Future<void> _playAudio(String base64Audio, String msgId) async {
    if (_playingMsgId == msgId) { await _audioPlayer.stop(); setState(() => _playingMsgId = null); return; }
    try {
      await _audioPlayer.stop();
      await _setupAudioSession();
      Uint8List bytes = base64Decode(base64Audio);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/audio_$msgId.m4a');
      await file.writeAsBytes(bytes);
      await _audioPlayer.play(DeviceFileSource(file.path));
      await _audioPlayer.setVolume(1.0);
      setState(() => _playingMsgId = msgId);
      _audioPlayer.onPlayerComplete.listen((_) => { if(mounted) setState(() => _playingMsgId = null) });
    } catch (e) { /* error */ }
  }

  Widget _buildSmartAvatar(Map<String, dynamic> data) {
    String senderId = data['senderId'];
    String? localAvatar = data['senderAvatar'];
    if (_imageCache.containsKey(senderId)) return CircleAvatar(backgroundImage: MemoryImage(_imageCache[senderId]!), radius: 18);
    if (localAvatar != null && localAvatar.isNotEmpty) {
      try {
        Uint8List bytes = base64Decode(localAvatar);
        _imageCache[senderId] = bytes;
        return CircleAvatar(backgroundImage: MemoryImage(bytes), radius: 18);
      } catch (e) { /* ignore */ }
    }
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(senderId).get(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          final liveAvatar = userData?['avatar_base64'];
          if (liveAvatar != null && liveAvatar.isNotEmpty) {
            try {
              Uint8List bytes = base64Decode(liveAvatar);
              _imageCache[senderId] = bytes;
              return CircleAvatar(backgroundImage: MemoryImage(bytes), radius: 18);
            } catch (e) { /* ignore */ }
          }
        }
        return const CircleAvatar(radius: 18, child: Icon(Icons.person, size: 20));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.chatTitle ?? AppText.get('chat_title'), style: TextStyle(fontSize: 18, color: textColor)),
          if (widget.isDirect) Text(AppText.get('chat_personal'), style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildChatBackground(isDark)),
          Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _chatService.getMessages(widget.chatId, isDirect: widget.isDirect),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    final docs = snapshot.data!.docs;
                    if (docs.isEmpty) return Center(child: Text(AppText.get('chat_no_messages'), style: TextStyle(color: Colors.grey.shade500)));

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20), itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        bool isMe = data['senderId'] == user.uid;
                        bool isSameUser = false;
                        if (index < docs.length - 1) { final prev = docs[index + 1].data() as Map<String, dynamic>; if (prev['senderId'] == data['senderId']) isSameUser = true; }
                        List<dynamic> likes = data['likes'] ?? [];
                        bool isLiked = likes.contains(user.uid);
                        return GestureDetector(
                          onLongPress: () => _showMsgOptions(context, docs[index], isMe),
                          // 🔥 ЛАЙК ПОВІДОМЛЕННЯ
                          onDoubleTap: () {
                            _chatService.toggleLikeMessage(widget.chatId, docs[index].id, isLiked, isDirect: widget.isDirect);
                            if (!isLiked && !isMe) {
                              _notifyLike(data['senderId'], data['text'] ?? 'повідомлення');
                            }
                          },
                          child: AnimatedContainer(duration: const Duration(milliseconds: 500), padding: const EdgeInsets.symmetric(vertical: 2), child: _buildMessageRow(data, isMe, docs[index].id, isSameUser, isDark)),
                        );
                      },
                    );
                  },
                ),
              ),
              if (_isUploading) const LinearProgressIndicator(color: Colors.green, minHeight: 2),
              _buildInputArea(isDark, textColor),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChatBackground(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF101010) : const Color(0xFFE5DDD5),
      child: Opacity(opacity: isDark ? 0.05 : 0.06, child: GridView.builder(physics: const NeverScrollableScrollPhysics(), itemCount: 100, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6), itemBuilder: (context, index) { List<IconData> icons = [Icons.lunch_dining, Icons.local_pizza, Icons.icecream, Icons.coffee, Icons.egg, Icons.apple]; return Icon(icons[index % icons.length], size: 32, color: isDark ? Colors.white : Colors.black); })),
    );
  }

  Widget _buildMessageRow(Map<String, dynamic> data, bool isMe, String msgId, bool isSameUser, bool isDark) {
    return Padding(
      padding: EdgeInsets.only(top: isSameUser ? 2 : 10),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(child: _buildBubble(data, isMe, msgId, isDark)),
        ],
      ),
    );
  }

  Widget _buildBubble(Map<String, dynamic> data, bool isMe, String msgId, bool isDark) {
    String time = data['timestamp'] != null ? DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate()) : "";
    Widget content;
    final bubbleTextColor = isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final bubbleColor = isMe ? const Color(0xFF00897B) : (isDark ? const Color(0xFF1F1F1F) : Colors.white);
    bool isEdited = data['isEdited'] == true;
    List<dynamic> readBy = data['readBy'] ?? [];
    bool isReadByOthers = readBy.any((id) => id != user.uid);
    List<dynamic> likes = data['likes'] ?? [];
    bool isLiked = likes.isNotEmpty;

    if (data['imageBase64'] != null) { content = GestureDetector(onTap: () => showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent, child: InteractiveViewer(child: Image.memory(base64Decode(data['imageBase64']))))), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(base64Decode(data['imageBase64']), height: 200, fit: BoxFit.cover, gaplessPlayback: true))); }
    else if (data['audioBase64'] != null) { bool isPlaying = _playingMsgId == msgId; content = Row(mainAxisSize: MainAxisSize.min, children: [GestureDetector(onTap: () => _playAudio(data['audioBase64'], msgId), child: CircleAvatar(radius: 20, backgroundColor: isMe ? Colors.green.shade900 : Colors.green, child: Icon(isPlaying ? Icons.stop : Icons.play_arrow, color: Colors.white))), const SizedBox(width: 10), Expanded(child: Container(height: 4, decoration: BoxDecoration(color: isMe ? Colors.white54 : Colors.grey.shade400, borderRadius: BorderRadius.circular(2)))), const SizedBox(width: 10), Text(isPlaying ? "Playing..." : "Voice", style: TextStyle(fontSize: 12, color: bubbleTextColor.withOpacity(0.7)))]); }
    else { content = Text(data['text'] ?? '', style: TextStyle(fontSize: 16, color: bubbleTextColor)); }

    Widget? replyWidget;
    if (data['replyToText'] != null) { replyWidget = Container(margin: const EdgeInsets.only(bottom: 5), padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8), border: const Border(left: BorderSide(color: Colors.green, width: 3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data['replyToSender'] ?? "User", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: bubbleTextColor.withOpacity(0.8))), Text(data['replyToText'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: bubbleTextColor.withOpacity(0.7))) ])); }

    return Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.65),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(2), bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(16)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 2, offset: const Offset(0, 1))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        if (!isMe) Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [_buildSmartAvatar(data), const SizedBox(width: 8), Text(data['senderName']??'', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800, fontSize: 14))])),
        if (replyWidget != null) replyWidget, content, const SizedBox(height: 4),
        Align(alignment: Alignment.bottomRight, child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (isLiked) ...[const Icon(Icons.favorite, size: 12, color: Colors.redAccent), const SizedBox(width: 2), Text("${likes.length}", style: TextStyle(fontSize: 10, color: Colors.redAccent)), const SizedBox(width: 4)],
          if (isEdited) Text("ed. ", style: TextStyle(fontSize: 9, color: bubbleTextColor.withOpacity(0.5))),
          Text(time, style: TextStyle(fontSize: 10, color: bubbleTextColor.withOpacity(0.7))),
          if (isMe) ...[const SizedBox(width: 4), Icon(isReadByOthers ? Icons.done_all : Icons.check, size: 14, color: isReadByOthers ? Colors.blueAccent : Colors.white70)]
        ])),
      ]),
    );
  }

  Widget _buildInputArea(bool isDark, Color textColor) {
    return SafeArea(
      child: Column(
        children: [
          if (_replyMessage != null) Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: isDark ? Colors.grey.shade900 : Colors.grey.shade200, child: Row(children: [const Icon(Icons.reply, color: Colors.green), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("${AppText.get('notif_reply_to')} ${_replyMessage!['sender']}", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)), Text(_replyMessage!['text']!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor.withOpacity(0.7)))])), IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _replyMessage = null))])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
            child: Row(children: [
              if (_editingMsgId == null) IconButton(icon: const Icon(Icons.camera_alt), color: Colors.grey, onPressed: _pickAndSendImage) else IconButton(icon: const Icon(Icons.close), color: Colors.red, onPressed: () { setState(() { _editingMsgId = null; _msgController.clear(); }); }),
              Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100, borderRadius: BorderRadius.circular(24)), child: TextField(controller: _msgController, maxLines: 5, minLines: 1, style: TextStyle(color: textColor), decoration: InputDecoration(hintText: _editingMsgId != null ? "Editing..." : AppText.get('chat_hint'), hintStyle: TextStyle(color: isDark ? Colors.grey : null), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 10))))),
              const SizedBox(width: 8),
              GestureDetector(onLongPress: (_isTextEmpty && _editingMsgId == null) ? _startRecording : null, onLongPressUp: (_isTextEmpty && _editingMsgId == null) ? _stopRecording : null, onTap: _isTextEmpty && _editingMsgId == null ? () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hold to record 🎤"), duration: Duration(seconds: 1))) : _sendMessage, child: CircleAvatar(radius: 24, backgroundColor: _isRecording ? Colors.red : (_editingMsgId != null ? Colors.blue : const Color(0xFF00897B)), child: _isRecording ? const Icon(Icons.mic, color: Colors.white, size: 24) : Icon(_editingMsgId != null ? Icons.check : (_isTextEmpty ? Icons.mic_none : Icons.send), color: Colors.white, size: 24))),
            ]),
          ),
        ],
      ),
    );
  }

  // ==============================================================================
  // 🔥🔥🔥 ОНОВЛЕНА ЛОГІКА З APPTEXT ТА CREDENTIALS 🔥🔥🔥
  // ==============================================================================

  Future<void> _notifyRecipients(String messageText, {String? replyToName}) async {
    try {
      final myDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final myName = myDoc.data()?['displayName'] ?? AppText.get('notif_new_msg');

      String notificationType = widget.isDirect ? 'private_chat' : 'family_chat';
      String targetChatId = widget.chatId;

      // 🔥 Формуємо перекладений заголовок і текст
      String title = widget.isDirect ? myName : "${AppText.get('notif_family')}: $myName";
      String body = messageText;

      if (replyToName != null) {
        body = "${AppText.get('notif_reply_to')} $replyToName: $messageText";
      }

      if (widget.isDirect) {
        String receiverId = '';
        if (widget.chatId.contains('_')) {
          final parts = widget.chatId.split('_');
          if (parts.length == 2) {
            if (parts[0] == user.uid) { receiverId = parts[1]; }
            else if (parts[1] == user.uid) { receiverId = parts[0]; }
          }
        }
        if (receiverId.isEmpty) {
          final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get();
          if (chatDoc.exists) {
            final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
            receiverId = participants.firstWhere((id) => id != user.uid, orElse: () => '');
          }
        }

        if (receiverId.isNotEmpty) {
          final receiverDoc = await FirebaseFirestore.instance.collection('users').doc(receiverId).get();
          final token = receiverDoc.data()?['fcmToken'];
          if (token != null) {
            await _sendPushV1(token, title, body, notificationType, targetChatId);
          }
        }
      } else {
        String? householdId = myDoc.data()?['householdId'];
        if (householdId != null) {
          final familyMembers = await FirebaseFirestore.instance.collection('users').where('householdId', isEqualTo: householdId).get();
          for (var doc in familyMembers.docs) {
            if (doc.id == user.uid) continue;
            final token = doc.data()['fcmToken'];
            if (token != null) {
              _sendPushV1(token, title, body, notificationType, targetChatId);
            }
          }
        }
      }
    } catch (e) {
      debugPrint("❌ [PUSH] Error: $e");
    }
  }

  Future<void> _notifyLike(String messageSenderId, String messageText) async {
    try {
      final myDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final myName = myDoc.data()?['displayName'] ?? AppText.get('notif_someone');

      final senderDoc = await FirebaseFirestore.instance.collection('users').doc(messageSenderId).get();
      final token = senderDoc.data()?['fcmToken'];

      if (token != null) {
        String shortText = messageText.length > 20 ? '${messageText.substring(0, 20)}...' : messageText;

        // 🔥 Перекладений текст лайку
        String title = "❤️ $myName ${AppText.get('notif_liked')}:";
        String body = "\"$shortText\"";

        String notificationType = widget.isDirect ? 'private_chat' : 'family_chat';

        await _sendPushV1(token, title, body, notificationType, widget.chatId);
      }
    } catch (e) {
      debugPrint("❌ Like push error: $e");
    }
  }

  Future<void> _sendPushV1(String token, String title, String body, String type, String chatId) async {
    try {
      // ✅ БЕРЕМО КЛЮЧІ З ОКРЕМОГО ФАЙЛУ
      final accountCredentials = auth.ServiceAccountCredentials.fromJson(googleServiceAccount);

      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await auth.clientViaServiceAccount(accountCredentials, scopes);

      final response = await client.post(
        Uri.parse('https://fcm.googleapis.com/v1/projects/${googleServiceAccount['project_id']}/messages:send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': {
            'token': token,
            'notification': {
              'title': title,
              'body': body,
            },
            'data': {
              'type': type,
              'chatId': chatId,
              'click_action': 'FLUTTER_NOTIFICATION_CLICK',
            },
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("🎉 [PUSH V1] Send Success!");
      } else {
        debugPrint("💀 [PUSH V1] Error: ${response.body}");
      }
      client.close();
    } catch (e) {
      debugPrint("❌ [PUSH V1] Exception: $e");
    }
  }
}