import 'dart:async';
import 'dart:convert' hide Codec;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' hide Codec;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:image_gallery_saver/image_gallery_saver.dart';

import '../chat_service.dart';
import '../translations.dart';
import '../credentials.dart';
import '../utils/snackbar_utils.dart';
import 'chat_components.dart';
import 'smart_avatar.dart';
import '../recipe_model.dart';
import '../screens/recipe_detail_screen.dart';

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
  int _recordDuration = 0;
  Timer? _recordTimer;
  String? _recordedFilePath;
  bool _isRecorderInitialized = false;

  final Set<String> _deletingMessageIds = {};
  bool _isTextEmpty = true;
  String? _playingMsgId;
  bool _isUploading = false;
  String? _editingMsgId;

  bool _isSearching = false;
  String _searchQuery = "";
  bool _showScrollToBottom = false;

  Duration _currentAudioPosition = Duration.zero;
  Duration _totalAudioDuration = Duration.zero;
  double _playbackRate = 1.0;

  Map<String, String>? _replyMessage;
  String? _bgImagePath;
  Color _myBubbleColor = const Color(0xFF00897B);
  double _chatFontSize = 16.0;
  bool _showMediaOnly = false;

  List<Map<String, dynamic>> _pinnedMessages = [];
  int _currentPinIndex = 0;
  StreamSubscription<DocumentSnapshot>? _chatDocSub;
  StreamSubscription<DocumentSnapshot>? _typingSub; // 🔥 Окремий слухач для друку
  double? _uploadProgress;

  // 🔥 ЗМІННІ ДЛЯ ІНДИКАТОРА ДРУКУ ("ПИШЕ...")
  Timer? _typingTimer;
  bool _isTyping = false;
  List<String> _typingUserNames = [];
  final Map<String, String> _userNameCache = {};

  @override
  void initState() {
    super.initState();
    _loadChatSettings();
    _chatService.markAsRead(widget.chatId, isDirect: widget.isDirect);

    _audioPlayer.onPositionChanged.listen((p) { if(mounted) setState(() => _currentAudioPosition = p); });
    _audioPlayer.onDurationChanged.listen((d) { if(mounted) setState(() => _totalAudioDuration = d); });
    _audioPlayer.onPlayerComplete.listen((_) { if(mounted) setState(() { _playingMsgId = null; _currentAudioPosition = Duration.zero; }); });

    // 🔥 СЛУХАЄМО ВВІД ТЕКСТУ
    _msgController.addListener(() {
      bool textEmpty = _msgController.text.trim().isEmpty;
      if (_isTextEmpty != textEmpty) {
        setState(() { _isTextEmpty = textEmpty; });
      }

      if (!textEmpty) {
        if (!_isTyping) {
          _isTyping = true;
          _chatService.setTypingStatus(widget.chatId, true, isDirect: widget.isDirect);
        }
        _typingTimer?.cancel();
        _typingTimer = Timer(const Duration(seconds: 3), () {
          if (_isTyping) {
            _isTyping = false;
            _chatService.setTypingStatus(widget.chatId, false, isDirect: widget.isDirect);
          }
        });
      } else {
        if (_isTyping) {
          _typingTimer?.cancel();
          _isTyping = false;
          _chatService.setTypingStatus(widget.chatId, false, isDirect: widget.isDirect);
        }
      }
    });

    _scrollController.addListener(() {
      if (_scrollController.offset > 300 && !_showScrollToBottom) setState(() => _showScrollToBottom = true);
      else if (_scrollController.offset <= 300 && _showScrollToBottom) setState(() => _showScrollToBottom = false);
    });

    // 1. Слухаємо головний документ для закріплених повідомлень
    final docRef = widget.isDirect ? FirebaseFirestore.instance.collection('chats').doc(widget.chatId) : FirebaseFirestore.instance.collection('households').doc(widget.chatId);
    _chatDocSub = docRef.snapshots().listen((doc) {
      if (doc.exists && doc.data()!.containsKey('pinnedMessages')) {
        final newPins = List<Map<String, dynamic>>.from(doc.data()!['pinnedMessages'] ?? []);
        if (mounted) {
          setState(() {
            if (newPins.length > _pinnedMessages.length) _currentPinIndex = newPins.length - 1;
            _pinnedMessages = newPins;
            if (_currentPinIndex >= _pinnedMessages.length) _currentPinIndex = _pinnedMessages.length - 1;
          });
        }
      } else {
        if(mounted) setState(() { _pinnedMessages = []; _currentPinIndex = 0; });
      }
    });

    // 2. Слухаємо спеціальний документ TYPING_INDICATOR всередині messages
    final typingRef = widget.isDirect
        ? FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').doc('TYPING_INDICATOR')
        : FirebaseFirestore.instance.collection('households').doc(widget.chatId).collection('messages').doc('TYPING_INDICATOR');

    _typingSub = typingRef.snapshots().listen((doc) {
      if (doc.exists && doc.data()!.containsKey('typing')) {
        List<String> typingUids = List<String>.from(doc.data()!['typing'] ?? []);
        typingUids.remove(user.uid);
        _updateTypingUsers(typingUids);
      } else {
        if (mounted) setState(() => _typingUserNames = []);
      }
    });
  }

  // Отримуємо імена тих, хто зараз пише
  Future<void> _updateTypingUsers(List<String> uids) async {
    if (uids.isEmpty) {
      if (mounted) setState(() => _typingUserNames = []);
      return;
    }
    List<String> names = [];
    for (String uid in uids) {
      if (_userNameCache.containsKey(uid)) {
        names.add(_userNameCache[uid]!);
      } else {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists) {
          String name = doc.data()?['displayName'] ?? AppText.get('notif_someone');
          _userNameCache[uid] = name;
          names.add(name);
        } else {
          names.add(AppText.get('notif_someone'));
        }
      }
    }
    if (mounted) setState(() => _typingUserNames = names);
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_isTyping) _chatService.setTypingStatus(widget.chatId, false, isDirect: widget.isDirect);

    _recordTimer?.cancel();
    _chatDocSub?.cancel();
    _typingSub?.cancel(); // Звільняємо слухача
    if (_isRecorderInitialized && _recorder != null) _recorder!.closeRecorder();
    _audioPlayer.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    _chatService.markAsRead(widget.chatId, isDirect: widget.isDirect);
    super.dispose();
  }

  Future<void> _saveMedia(Map<String, dynamic> data) async {
    try {
      if (Platform.isAndroid) { await Permission.storage.request(); await Permission.photos.request(); }
      if (data['imageUrl'] != null) {
        SnackbarUtils.showInfo(context, AppText.get('chat_uploading'));
        var response = await http.get(Uri.parse(data['imageUrl']));
        final result = await ImageGallerySaver.saveImage(response.bodyBytes);
        if (result != null && result['isSuccess'] == true) { if (mounted) SnackbarUtils.showSuccess(context, "✅ ${AppText.get('msg_saved_gallery')}"); } else { if (mounted) SnackbarUtils.showError(context, AppText.get('msg_error')); }
      } else if (data['imageBase64'] != null) {
        Uint8List bytes = base64Decode(data['imageBase64']);
        final result = await ImageGallerySaver.saveImage(bytes);
        if (result != null && result['isSuccess'] == true) { if (mounted) SnackbarUtils.showSuccess(context, "✅ ${AppText.get('msg_saved_gallery')}"); }
      }
    } catch (e) {
      if (mounted) SnackbarUtils.showError(context, "${AppText.get('msg_error')}: $e");
    }
  }

  Future<void> _pinMessage(String msgId, Map<String, dynamic> data) async {
    final docRef = widget.isDirect ? FirebaseFirestore.instance.collection('chats').doc(widget.chatId) : FirebaseFirestore.instance.collection('households').doc(widget.chatId);
    String pinText = data['text'] ?? '';
    if (pinText.isEmpty) {
      if (data['type'] == 'poll') pinText = '📊 ${AppText.get('chat_poll_msg')}';
      else if (data['type'] == 'recipe') pinText = '🍲 ${AppText.get('chat_recipe_msg')}: ${data['recipeTitle']}';
      else if (data['imageUrl'] != null || data['imageBase64'] != null) pinText = '📷 ${AppText.get('chat_photo_msg')}';
      else if (data['fileUrl'] != null) pinText = '📎 ${data['fileName'] ?? AppText.get('chat_attachment_file')}';
      else if (data['audioUrl'] != null || data['audioBase64'] != null) pinText = '🎤 ${AppText.get('chat_voice_msg')}';
    }
    final newPin = {'id': msgId, 'text': pinText, 'senderName': data['senderName'] ?? 'User'};
    await docRef.set({'pinnedMessages': FieldValue.arrayUnion([newPin])}, SetOptions(merge: true));
    if(mounted) SnackbarUtils.showSuccess(context, "📌 ${AppText.get('msg_pinned')}");
  }

  Future<void> _unpinMessage(Map<String, dynamic> pinToRemove) async {
    final docRef = widget.isDirect ? FirebaseFirestore.instance.collection('chats').doc(widget.chatId) : FirebaseFirestore.instance.collection('households').doc(widget.chatId);
    await docRef.update({'pinnedMessages': FieldValue.arrayRemove([pinToRemove])});
  }

  Future<void> _handlePinTap() async {
    if (_pinnedMessages.isEmpty) return;
    if (_currentPinIndex < 0 || _currentPinIndex >= _pinnedMessages.length) _currentPinIndex = _pinnedMessages.length - 1;
    final targetPin = _pinnedMessages[_currentPinIndex];
    _scrollToMessage(targetPin['id']);
    setState(() { _currentPinIndex--; if (_currentPinIndex < 0) _currentPinIndex = _pinnedMessages.length - 1; });
  }

  Future<void> _scrollToMessage(String msgId) async {
    final query = widget.isDirect ? FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages') : FirebaseFirestore.instance.collection('households').doc(widget.chatId).collection('messages');
    final snapshot = await query.orderBy('timestamp', descending: true).get();
    final index = snapshot.docs.indexWhere((doc) => doc.id == msgId);
    if (index != -1) { double targetOffset = index * 90.0; _scrollController.animateTo(targetOffset, duration: const Duration(milliseconds: 600), curve: Curves.easeInOutCubic); }
  }

  void _startUploadProgress() {
    setState(() { _isUploading = true; _uploadProgress = 0.0; });
    Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!_isUploading) { timer.cancel(); setState(() => _uploadProgress = null); }
      else { setState(() { _uploadProgress = (_uploadProgress ?? 0.0) + 0.05; if (_uploadProgress! >= 0.95) _uploadProgress = 0.95; }); }
    });
  }

  Future<void> _sendPoll(String question, List<String> options) async {
    final docRef = widget.isDirect ? FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages') : FirebaseFirestore.instance.collection('households').doc(widget.chatId).collection('messages');
    final myDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final myName = myDoc.data()?['displayName'] ?? 'User';
    await docRef.add({'type': 'poll', 'text': question, 'pollOptions': options, 'pollVotes': {}, 'senderId': user.uid, 'senderName': myName, 'timestamp': FieldValue.serverTimestamp(), 'readBy': [user.uid]});
    _notifyRecipients("📊 ${AppText.get('chat_poll_msg')}: $question");
    _scrollToBottom();
  }

  void _openSettingsMenu() {
    ChatComponents.showChatMenu(
      context: context, hasBackground: _bgImagePath != null, onChangeBackground: _pickBackground,
      onClearBackground: () async { final prefs = await SharedPreferences.getInstance(); await prefs.remove('chat_bg_${widget.chatId}'); setState(() => _bgImagePath = null); },
      onChangeColor: _showColorPicker, onChangeFont: _showFontSizePicker, showMediaOnly: _showMediaOnly,
      onToggleMediaOnly: () => setState(() => _showMediaOnly = !_showMediaOnly), onShowStats: _showChatStats, onClearHistory: _clearChatHistory,
    );
  }

  Future<void> _loadChatSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() { _bgImagePath = prefs.getString('chat_bg_${widget.chatId}'); int? colorInt = prefs.getInt('chat_color_${widget.chatId}'); if (colorInt != null) _myBubbleColor = Color(colorInt); _chatFontSize = prefs.getDouble('chat_font_${widget.chatId}') ?? 16.0; });
  }

  Future<void> _pickBackground() async {
    final picker = ImagePicker(); final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) { final prefs = await SharedPreferences.getInstance(); await prefs.setString('chat_bg_${widget.chatId}', image.path); setState(() { _bgImagePath = image.path; }); if (mounted) SnackbarUtils.showSuccess(context, "✨ ${AppText.get('chat_change_bg')}!"); }
  }

  void _showColorPicker() {
    final colors = [const Color(0xFF00897B), Colors.blue, Colors.purple, Colors.orange, Colors.pink, Colors.grey.shade800];
    showModalBottomSheet(context: context, backgroundColor: Theme.of(context).cardColor, builder: (ctx) { return Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(AppText.get('chat_color'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 20), Wrap(spacing: 15, children: colors.map((color) => GestureDetector(onTap: () async { final prefs = await SharedPreferences.getInstance(); await prefs.setInt('chat_color_${widget.chatId}', color.value); setState(() => _myBubbleColor = color); Navigator.pop(ctx); }, child: CircleAvatar(backgroundColor: color, radius: 24, child: _myBubbleColor == color ? const Icon(Icons.check, color: Colors.white) : null))).toList()), const SizedBox(height: 20)])); });
  }

  void _showFontSizePicker() {
    showModalBottomSheet(context: context, backgroundColor: Theme.of(context).cardColor, builder: (ctx) { return StatefulBuilder(builder: (context, setModalState) { return Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [Text(AppText.get('chat_font_size'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Slider(value: _chatFontSize, min: 12.0, max: 24.0, divisions: 6, label: _chatFontSize.round().toString(), onChanged: (val) async { final prefs = await SharedPreferences.getInstance(); await prefs.setDouble('chat_font_${widget.chatId}', val); setModalState(() => _chatFontSize = val); setState(() => _chatFontSize = val); }), Text(AppText.get('chat_font_sample'), style: TextStyle(fontSize: _chatFontSize)), const SizedBox(height: 20)])); }); });
  }

  Future<void> _showChatStats() async {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));
    final snapshot = await (widget.isDirect ? FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').get() : FirebaseFirestore.instance.collection('households').doc(widget.chatId).collection('messages').get());
    if (mounted) Navigator.pop(context);
    int total = snapshot.docs.length; int photos = 0; int voices = 0; int files = 0; int texts = 0;
    for(var doc in snapshot.docs) { final data = doc.data() as Map<String, dynamic>; if(data['imageUrl'] != null || data['imageBase64'] != null) photos++; else if(data['audioUrl'] != null || data['audioBase64'] != null) voices++; else if(data['fileUrl'] != null) files++; else texts++; }
    if(mounted) ChatComponents.showChatStats(context: context, total: total, texts: texts, photos: photos, voices: voices, files: files);
  }

  Future<void> _clearChatHistory() async {
    showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(AppText.get('dialog_clear_title'), style: const TextStyle(color: Colors.red)), content: Text(AppText.get('dialog_clear_content')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppText.get('btn_no'))), TextButton(onPressed: () async { Navigator.pop(ctx); final snapshot = await (widget.isDirect ? FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').get() : FirebaseFirestore.instance.collection('households').doc(widget.chatId).collection('messages').get()); final batch = FirebaseFirestore.instance.batch(); for (var doc in snapshot.docs) { batch.delete(doc.reference); } await batch.commit(); if(mounted) SnackbarUtils.showSuccess(context, "🧹 ${AppText.get('msg_cleared')}"); }, child: Text(AppText.get('btn_yes'), style: const TextStyle(color: Colors.red)))]));
  }

  Future<void> _setAudioSessionForRecording() async { try { await _audioPlayer.setAudioContext(AudioContext(android: AudioContextAndroid(isSpeakerphoneOn: false, stayAwake: true, contentType: AndroidContentType.speech, usageType: AndroidUsageType.voiceCommunication, audioFocus: AndroidAudioFocus.gainTransientExclusive), iOS: AudioContextIOS(category: AVAudioSessionCategory.playAndRecord, options: {AVAudioSessionOptions.defaultToSpeaker, AVAudioSessionOptions.allowBluetooth}))); } catch (e) {} }
  Future<void> _setAudioSessionForPlayback() async { try { await _audioPlayer.setAudioContext(AudioContext(android: AudioContextAndroid(isSpeakerphoneOn: true, stayAwake: true, contentType: AndroidContentType.music, usageType: AndroidUsageType.media, audioFocus: AndroidAudioFocus.gain), iOS: AudioContextIOS(category: AVAudioSessionCategory.playback, options: {AVAudioSessionOptions.defaultToSpeaker}))); } catch (e) {} }
  void _scrollToBottom() { _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut); }
  String _formatDuration(int seconds) { final m = seconds ~/ 60; final s = seconds % 60; return '$m:${s.toString().padLeft(2, '0')}'; }
  String _getDateSeparatorLabel(DateTime date) { final now = DateTime.now(); final today = DateTime(now.year, now.month, now.day); final yesterday = today.subtract(const Duration(days: 1)); final msgDate = DateTime(date.year, date.month, date.day); if (msgDate == today) return "Сьогодні"; if (msgDate == yesterday) return "Вчора"; return DateFormat('d MMMM y', 'uk').format(date); }

  void _sendMessage({bool isSilent = false}) {
    String text = _msgController.text.trim(); if (text.isEmpty) return;
    if (_editingMsgId != null) { _chatService.editMessage(widget.chatId, _editingMsgId!, text, isDirect: widget.isDirect); setState(() { _editingMsgId = null; }); }
    else { String? replyToName = _replyMessage?['sender']; _chatService.sendMessage(widget.chatId, text, isDirect: widget.isDirect, replyToText: _replyMessage?['text'], replyToSender: _replyMessage?['sender']); if (!isSilent) _notifyRecipients(text, replyToName: replyToName); else SnackbarUtils.showSuccess(context, "🔕 ${AppText.get('chat_silent_send')}"); setState(() => _replyMessage = null); }

    _isTyping = false;
    _chatService.setTypingStatus(widget.chatId, false, isDirect: widget.isDirect);

    _msgController.clear(); _scrollToBottom();
  }

  void _showSilentSendMenu() { showModalBottomSheet(context: context, backgroundColor: Theme.of(context).cardTheme.color, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) { return Wrap(children: [ListTile(leading: const Icon(Icons.notifications_off, color: Colors.grey), title: Text(AppText.get('chat_silent_send')), subtitle: Text(AppText.get('chat_silent_desc'), style: const TextStyle(fontSize: 12)), onTap: () { Navigator.pop(ctx); _sendMessage(isSilent: true); })]); }); }

  void _showMessageInfo(List<dynamic> readByUids) {
    showModalBottomSheet(
        context: context, backgroundColor: Theme.of(context).cardColor, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          final isDark = Theme.of(context).brightness == Brightness.dark; final textColor = isDark ? Colors.white : Colors.black;
          List<dynamic> othersReadBy = readByUids.where((id) => id != user.uid).toList();
          return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                  mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${AppText.get('chat_seen_by')} (${othersReadBy.length}):", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)), const SizedBox(height: 16),
                    if (othersReadBy.isEmpty) Text(AppText.get('chat_nobody_seen'), style: const TextStyle(color: Colors.grey))
                    else ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4), child: ListView.builder(shrinkWrap: true, itemCount: othersReadBy.length, itemBuilder: (context, index) { String uid = othersReadBy[index].toString(); return FutureBuilder<DocumentSnapshot>(future: FirebaseFirestore.instance.collection('users').doc(uid).get(), builder: (context, snap) { String name = "User"; if (snap.hasData && snap.data!.exists) { name = (snap.data!.data() as Map<String, dynamic>?)?['displayName'] ?? "User"; } return ListTile(contentPadding: EdgeInsets.zero, leading: SmartAvatar(userId: uid, radius: 20), title: Text(name, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)), trailing: const Icon(Icons.done_all, color: Colors.blueAccent, size: 20)); }); }))
                  ]
              )
          );
        }
    );
  }

  void _showMsgOptions(BuildContext context, DocumentSnapshot doc, bool isMe) {
    final data = doc.data() as Map<String, dynamic>;
    final bool hasText = data['text'] != null && data['text'].toString().isNotEmpty;
    final bool isImage = data['imageUrl'] != null || data['imageBase64'] != null;
    final bool isFile = data['fileUrl'] != null;
    final List<String> emojis = ['👍', '❤️', '😂', '😮', '😢'];
    final List<dynamic> readBy = data['readBy'] ?? [];

    showModalBottomSheet(context: context, backgroundColor: Theme.of(context).cardTheme.color, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Container(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20), decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: emojis.map((emoji) => GestureDetector(onTap: () { Navigator.pop(ctx); _addReaction(doc.id, emoji); }, child: Text(emoji, style: const TextStyle(fontSize: 32)))).toList())), const Divider(height: 1),
        if (hasText) ListTile(leading: const Icon(Icons.copy, color: Colors.blue), title: Text(AppText.get('chat_copy')), onTap: () { Navigator.pop(ctx); Clipboard.setData(ClipboardData(text: data['text'])); SnackbarUtils.showSuccess(context, AppText.get('msg_copied')); }),
        if (isImage) ListTile(leading: const Icon(Icons.download, color: Colors.green), title: Text(AppText.get('chat_save_gallery')), onTap: () { Navigator.pop(ctx); _saveMedia(data); }),
        if (isFile) ListTile(leading: const Icon(Icons.download, color: Colors.green), title: Text(AppText.get('chat_download_file')), onTap: () { Navigator.pop(ctx); _launchUrl(data['fileUrl']); }),
        if (isMe) ListTile(leading: const Icon(Icons.info_outline, color: Colors.teal), title: Text(AppText.get('chat_seen_by')), onTap: () { Navigator.pop(ctx); _showMessageInfo(readBy); }),
        ListTile(leading: const Icon(Icons.push_pin, color: Colors.green), title: Text(AppText.get('chat_pin')), onTap: () { Navigator.pop(ctx); _pinMessage(doc.id, data); }),
        ListTile(leading: const Icon(Icons.reply, color: Colors.blue), title: Text(AppText.get('chat_reply')), onTap: () { Navigator.pop(ctx); setState(() { String txt = data['text'] ?? (data['audioUrl'] != null || data['audioBase64'] != null ? "🎤 ${AppText.get('chat_voice_msg')}" : (data['type']=='poll'?"📊 ${AppText.get('chat_poll_msg')}":"📷 ${AppText.get('chat_photo_msg')}")); _replyMessage = {'text': txt, 'sender': data['senderName'] ?? 'User'}; }); }),
        if (isMe && hasText) ListTile(leading: const Icon(Icons.edit, color: Colors.blue), title: Text(AppText.get('chat_edit')), onTap: () { Navigator.pop(ctx); setState(() { _editingMsgId = doc.id; _msgController.text = data['text']; }); }),
        if (isMe) ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: Text(AppText.get('chat_delete')), onTap: () { Navigator.pop(ctx); _confirmDelete(doc.id); }),
      ]);
    });
  }

  Future<void> _addReaction(String msgId, String emoji) async { final ref = widget.isDirect ? FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').doc(msgId) : FirebaseFirestore.instance.collection('households').doc(widget.chatId).collection('messages').doc(msgId); await ref.update({'reactions.${user.uid}': emoji}); }
  void _confirmDelete(String msgId) { showDialog(context: context, builder: (ctx) => AlertDialog(title: Text(AppText.get('dialog_delete_title')), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(AppText.get('btn_no'))), TextButton(onPressed: () async { Navigator.pop(ctx); setState(() { _deletingMessageIds.add(msgId); }); await Future.delayed(const Duration(milliseconds: 300)); _chatService.deleteMessage(widget.chatId, msgId, isDirect: widget.isDirect); }, child: Text(AppText.get('btn_yes'), style: const TextStyle(color: Colors.red)))])); }

  void _showAttachmentOptions() {
    showModalBottomSheet(context: context, backgroundColor: Theme.of(context).cardColor, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (context) {
      return Wrap(children: [
        ListTile(leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.image, color: Colors.white)), title: Text(AppText.get('chat_attachment_gallery')), onTap: () { Navigator.pop(context); _pickAndSendImage(); }),
        ListTile(leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.insert_drive_file, color: Colors.white)), title: Text(AppText.get('chat_attachment_file')), onTap: () { Navigator.pop(context); _pickAndSendFile(); }),
        ListTile(leading: const CircleAvatar(backgroundColor: Colors.green, child: Icon(Icons.poll, color: Colors.white)), title: Text(AppText.get('chat_attachment_poll')), onTap: () { Navigator.pop(context); ChatComponents.showCreatePollSheet(context, _sendPoll); }),
        const SizedBox(height: 20),
      ]);
    });
  }

  Future<void> _pickAndSendImage() async { final picker = ImagePicker(); final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70); if (image == null) return; _startUploadProgress(); await _chatService.sendImage(widget.chatId, File(image.path), isDirect: widget.isDirect); _notifyRecipients("📷 ${AppText.get('chat_photo_msg')}"); setState(() => _isUploading = false); _scrollToBottom(); }
  Future<void> _pickAndSendFile() async { try { FilePickerResult? result = await FilePicker.platform.pickFiles(); if (result != null && result.files.single.path != null) { File file = File(result.files.single.path!); String fileName = result.files.single.name; _startUploadProgress(); await _chatService.sendFile(widget.chatId, file, fileName, isDirect: widget.isDirect); _notifyRecipients("📎 $fileName"); setState(() => _isUploading = false); _scrollToBottom(); } } catch (e) { SnackbarUtils.showError(context, AppText.get('msg_error')); } }

  Future<void> _startRecording() async {
    if (_isRecording) return;
    try {
      final status = await Permission.microphone.request(); if (status != PermissionStatus.granted) { if (mounted) SnackbarUtils.showError(context, "Microphone access denied."); return; }
      await _setAudioSessionForRecording(); if (_recorder == null) _recorder = FlutterSoundRecorder(); if (!_isRecorderInitialized) { await _recorder!.openRecorder(); _isRecorderInitialized = true; }
      Directory tempDir = await getTemporaryDirectory(); String path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.mp4'; await _recorder!.startRecorder(toFile: path, codec: Codec.aacMP4);
      setState(() { _isRecording = true; _recordedFilePath = path; _recordDuration = 0; });

      _isTyping = true;
      _chatService.setTypingStatus(widget.chatId, true, isDirect: widget.isDirect);

      _recordTimer?.cancel(); _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) { setState(() { _recordDuration++; }); });
    } catch (e) { if (mounted) SnackbarUtils.showError(context, AppText.get('msg_error')); }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return; _recordTimer?.cancel(); try { await _recorder!.stopRecorder(); } catch (e) {}
    setState(() => _isRecording = false);

    _isTyping = false;
    _chatService.setTypingStatus(widget.chatId, false, isDirect: widget.isDirect);

    if (_recordDuration < 1) { _recordedFilePath = null; return; }
    if (_recordedFilePath != null) { _startUploadProgress(); await _chatService.sendVoice(widget.chatId, _recordedFilePath!, isDirect: widget.isDirect); _notifyRecipients("🎤 ${AppText.get('chat_voice_msg')}"); setState(() => _isUploading = false); _scrollToBottom(); }
  }

  Future<void> _playAudio(String msgId, {String? base64Audio, String? audioUrl}) async { try { if (_playingMsgId == msgId) { await _audioPlayer.pause(); setState(() => _playingMsgId = null); return; } await _audioPlayer.stop(); await _setAudioSessionForPlayback(); setState(() { _playingMsgId = msgId; _currentAudioPosition = Duration.zero; }); await _audioPlayer.setVolume(1.0); await _audioPlayer.setPlaybackRate(_playbackRate); if (audioUrl != null) { await _audioPlayer.play(UrlSource(audioUrl)); } else if (base64Audio != null) { Uint8List bytes = base64Decode(base64Audio); final dir = await getTemporaryDirectory(); final file = File('${dir.path}/audio_$msgId.m4a'); await file.writeAsBytes(bytes); await _audioPlayer.play(DeviceFileSource(file.path)); } } catch (e) { setState(() => _playingMsgId = null); } }
  void _cyclePlaybackRate() { setState(() { if (_playbackRate == 1.0) _playbackRate = 1.5; else if (_playbackRate == 1.5) _playbackRate = 2.0; else _playbackRate = 1.0; }); if (_playingMsgId != null) _audioPlayer.setPlaybackRate(_playbackRate); }
  Future<void> _launchUrl(String url) async { final Uri uri = Uri.parse(url); if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) { if(mounted) SnackbarUtils.showError(context, AppText.get('msg_error')); } }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF101010) : const Color(0xFFE5DDD5),
      appBar: AppBar(
        title: _isSearching ? TextField(autofocus: true, style: TextStyle(color: textColor), decoration: InputDecoration(hintText: AppText.get('chat_search'), hintStyle: TextStyle(color: textColor.withValues(alpha: 0.5)), border: InputBorder.none), onChanged: (val) => setState(() => _searchQuery = val))
            : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.chatTitle ?? AppText.get('chat_title'), style: TextStyle(fontSize: 18, color: textColor)),
              // 🔥 ІНДИКАТОР "ПИШЕ..."
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _typingUserNames.isNotEmpty
                    ? Text("${_typingUserNames.join(', ')} ${AppText.get('chat_is_typing')}", key: const ValueKey('typing'), style: const TextStyle(fontSize: 12, color: Colors.green, fontStyle: FontStyle.italic))
                    : (widget.isDirect ? Text(AppText.get('chat_personal'), key: const ValueKey('personal'), style: const TextStyle(fontSize: 12, color: Colors.grey)) : const Text("", key: ValueKey('empty'), style: TextStyle(fontSize: 12))),
              ),
            ]
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor, iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(icon: Icon(_isSearching ? Icons.close : Icons.search), onPressed: () => setState(() { _isSearching = !_isSearching; _searchQuery = ""; })),
          if (!_isSearching) IconButton(icon: const Icon(Icons.more_vert), onPressed: _openSettingsMenu),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: _buildChatBackground(isDark)),
          Column(
            children: [
              ChatComponents.buildPinnedMessageBar(context: context, pinnedMessages: _pinnedMessages, currentIndex: _currentPinIndex, onUnpin: _unpinMessage, onTap: _handlePinTap, textColor: textColor),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _chatService.getMessages(widget.chatId, isDirect: widget.isDirect),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                    // 🔥 ВАЖЛИВО: Відфільтровуємо системний документ TYPING_INDICATOR зі списку!
                    var docs = snapshot.data!.docs.where((doc) => doc.id != 'TYPING_INDICATOR').toList();

                    if (_showMediaOnly) docs = docs.where((doc) { final data = doc.data() as Map<String, dynamic>; return data['imageUrl'] != null || data['imageBase64'] != null || data['audioUrl'] != null || data['audioBase64'] != null || data['fileUrl'] != null; }).toList();
                    if (_isSearching && _searchQuery.isNotEmpty) docs = docs.where((doc) { final data = doc.data() as Map<String, dynamic>; final text = data['text']?.toString().toLowerCase() ?? ''; return text.contains(_searchQuery.toLowerCase()); }).toList();
                    if (docs.isEmpty) return Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(16)), child: Text(_isSearching ? AppText.get('chat_nothing_found') : AppText.get('chat_no_messages'), style: const TextStyle(color: Colors.white))));

                    return ListView.builder(
                      controller: _scrollController, reverse: true, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20), itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index]; final data = doc.data() as Map<String, dynamic>; bool isMe = data['senderId'] == user.uid;
                        bool isSameUser = false; if (index < docs.length - 1) { final prev = docs[index + 1].data() as Map<String, dynamic>; if (prev['senderId'] == data['senderId']) isSameUser = true; }
                        bool showDateSeparator = false; if (index == docs.length - 1) { showDateSeparator = true; } else { final prevMsgDate = (docs[index + 1].data() as Map<String, dynamic>)['timestamp'] as Timestamp?; final currMsgDate = data['timestamp'] as Timestamp?; if (prevMsgDate != null && currMsgDate != null && prevMsgDate.toDate().day != currMsgDate.toDate().day) showDateSeparator = true; }
                        bool isDeleting = _deletingMessageIds.contains(doc.id);

                        return Column(
                          children: [
                            if (showDateSeparator && data['timestamp'] != null && !_isSearching && !_showMediaOnly) Container(margin: const EdgeInsets.symmetric(vertical: 16), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)), child: Text(_getDateSeparatorLabel((data['timestamp'] as Timestamp).toDate()), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                            AnimatedSize(key: ValueKey(doc.id), duration: const Duration(milliseconds: 300), curve: Curves.easeInOut, child: isDeleting ? Container(width: double.infinity, height: 0) : AnimatedOpacity(duration: const Duration(milliseconds: 200), opacity: 1.0, child: Dismissible(key: ValueKey("swipe_${doc.id}"), direction: DismissDirection.endToStart, confirmDismiss: (direction) async { setState(() { String txt = data['text'] ?? (data['audioUrl'] != null || data['audioBase64'] != null ? "🎤 ${AppText.get('chat_voice_msg')}" : "📷 ${AppText.get('chat_photo_msg')}"); _replyMessage = {'text': txt, 'sender': data['senderName'] ?? 'User'}; }); return false; }, background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const CircleAvatar(backgroundColor: Colors.black26, child: Icon(Icons.reply, color: Colors.white))), child: GestureDetector(onLongPress: () => _showMsgOptions(context, doc, isMe), child: Container(color: Colors.transparent, padding: const EdgeInsets.symmetric(vertical: 2), child: _buildMessageRow(data, isMe, doc.id, isSameUser, isDark)))))),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              if (_isUploading) ChatComponents.buildUploadProgress(_uploadProgress, isDark, textColor),
              if (!_isSearching && !_showMediaOnly) _buildInputArea(isDark, textColor),
            ],
          ),
          if (_showScrollToBottom) Positioned(bottom: 90, right: 16, child: FloatingActionButton(mini: true, backgroundColor: Theme.of(context).cardColor, child: Icon(Icons.keyboard_arrow_down, color: isDark ? Colors.white : Colors.black), onPressed: _scrollToBottom))
        ],
      ),
    );
  }

  Widget _buildChatBackground(bool isDark) {
    if (_bgImagePath != null && File(_bgImagePath!).existsSync()) { return Stack(fit: StackFit.expand, children: [Image.file(File(_bgImagePath!), fit: BoxFit.cover), BackdropFilter(filter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0), child: Container(color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.3)))]); }
    return Container(color: isDark ? const Color(0xFF101010) : const Color(0xFFE5DDD5), child: Opacity(opacity: isDark ? 0.05 : 0.06, child: GridView.builder(physics: const NeverScrollableScrollPhysics(), itemCount: 100, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 6), itemBuilder: (context, index) { List<IconData> icons = [Icons.lunch_dining, Icons.local_pizza, Icons.icecream, Icons.coffee, Icons.egg, Icons.apple]; return Icon(icons[index % icons.length], size: 32, color: isDark ? Colors.white : Colors.black); })));
  }

  Widget _buildMessageRow(Map<String, dynamic> data, bool isMe, String msgId, bool isSameUser, bool isDark) { return Padding(padding: EdgeInsets.only(top: isSameUser ? 2 : 10), child: Row(mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.end, children: [Flexible(child: _buildBubble(data, isMe, msgId, isDark))])); }

  Widget _buildBubble(Map<String, dynamic> data, bool isMe, String msgId, bool isDark) {
    String time = data['timestamp'] != null ? DateFormat('HH:mm').format((data['timestamp'] as Timestamp).toDate()) : ""; Widget content;
    final bubbleTextColor = isMe ? Colors.white : (isDark ? Colors.white : Colors.black87);
    final bubbleColor = isMe ? _myBubbleColor : (isDark ? const Color(0xFF1F1F1F) : Colors.white);
    bool isEdited = data['isEdited'] == true; List<dynamic> readBy = data['readBy'] ?? []; bool isReadByOthers = readBy.any((id) => id != user.uid);
    Map<String, dynamic> reactionsMap = data['reactions'] ?? {}; List<String> reactionEmojis = reactionsMap.values.map((e) => e.toString()).toList();

    if (data['type'] == 'recipe') {
      final cardBg = isDark ? const Color(0xFF2C2C2C) : Colors.white;
      final cardText = isDark ? Colors.white : Colors.black87;
      final cardSubText = isDark ? Colors.white70 : Colors.black54;
      final imageUrl = data['imageUrl'] ?? '';

      content = Container(
        width: MediaQuery.of(context).size.width * 0.75,
        decoration: BoxDecoration(color: cardBg, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))], border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (imageUrl.isNotEmpty) ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(15)), child: Image.network(imageUrl, height: 140, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(height: 140, color: Colors.grey.shade300, child: const Icon(Icons.restaurant, color: Colors.grey, size: 40)))),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.green.shade100, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.restaurant_menu, color: Colors.green.shade800, size: 18)), const SizedBox(width: 10), Expanded(child: Text(AppText.get('chat_recipe_offer'), style: TextStyle(fontSize: 13, color: cardSubText, fontWeight: FontWeight.w600)))]),
                  const SizedBox(height: 12),
                  Text(data['recipeTitle'] ?? 'Recipe', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: cardText)),
                  if (data['recipeTime'] != null) ...[const SizedBox(height: 6), Row(children: [Icon(Icons.timer_outlined, size: 14, color: Colors.orange.shade700), const SizedBox(width: 6), Text(data['recipeTime'], style: TextStyle(fontSize: 13, color: cardSubText, fontWeight: FontWeight.w500)), const SizedBox(width: 12), Icon(Icons.local_fire_department, size: 14, color: Colors.red.shade400), const SizedBox(width: 4), Text("${data['recipeKcal'] ?? '--'} ${AppText.get('rec_kcal')}", style: TextStyle(fontSize: 13, color: cardSubText, fontWeight: FontWeight.w500))])],
                  const SizedBox(height: 14),
                  SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 10)), onPressed: () { final r = Recipe(title: data['recipeTitle'] ?? '', description: data['description'] ?? '', time: data['recipeTime'] ?? '', kcal: data['recipeKcal'] ?? '', imageUrl: data['imageUrl'] ?? '', isVegetarian: data['isVegetarian'] ?? false, ingredients: List<String>.from(data['ingredients'] ?? []), steps: List<String>.from(data['steps'] ?? []), missingIngredients: []); Navigator.push(context, MaterialPageRoute(builder: (_) => RecipeDetailScreen(recipe: r, dietLabelKey: data['dietLabelKey'] ?? 'tag_standard'))); }, child: Text(AppText.get('chat_open_recipe'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))))
                ],
              ),
            )
          ],
        ),
      );
    }
    else if (data['type'] == 'poll') {
      List<dynamic> options = data['pollOptions'] ?? []; Map<String, dynamic> votes = data['pollVotes'] ?? {}; int totalVotes = votes.length; String? myVote = votes[user.uid]?.toString();
      content = Container(
          width: MediaQuery.of(context).size.width * 0.75, padding: const EdgeInsets.only(bottom: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.poll, color: Colors.orange), const SizedBox(width: 8), Expanded(child: Text(data['text'] ?? AppText.get('chat_poll_msg'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: bubbleTextColor)))]), const SizedBox(height: 12),
            ...List.generate(options.length, (index) {
              int count = votes.values.where((v) => v.toString() == index.toString()).length; double percent = totalVotes > 0 ? count / totalVotes : 0.0; bool isMyChoice = myVote == index.toString();
              return GestureDetector(
                  onTap: () { final docRef = widget.isDirect ? FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('messages').doc(msgId) : FirebaseFirestore.instance.collection('households').doc(widget.chatId).collection('messages').doc(msgId); if (isMyChoice) docRef.update({'pollVotes.${user.uid}': FieldValue.delete()}); else docRef.update({'pollVotes.${user.uid}': index}); },
                  child: Container(margin: const EdgeInsets.only(bottom: 8), child: Stack(children: [ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: percent, minHeight: 36, backgroundColor: Colors.black.withValues(alpha: 0.1), valueColor: AlwaysStoppedAnimation<Color>(isMyChoice ? Colors.green.withValues(alpha: 0.5) : Colors.blue.withValues(alpha: 0.2)))), Positioned.fill(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(options[index], style: TextStyle(color: bubbleTextColor, fontWeight: isMyChoice ? FontWeight.bold : FontWeight.normal))), if (totalVotes > 0) Text("${(percent * 100).toInt()}%", style: TextStyle(color: bubbleTextColor.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.bold))])))]))
              );
            }),
            Align(alignment: Alignment.centerRight, child: Text("${AppText.get('chat_total_votes')} $totalVotes", style: TextStyle(fontSize: 10, color: bubbleTextColor.withValues(alpha: 0.6)))),
          ])
      );
    }
    else if (data['imageUrl'] != null || data['imageBase64'] != null) { content = GestureDetector(onTap: () => showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent, child: InteractiveViewer(child: data['imageUrl'] != null ? Image.network(data['imageUrl']) : Image.memory(base64Decode(data['imageBase64']))))), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: data['imageUrl'] != null ? Image.network(data['imageUrl'], height: 250, width: 250, fit: BoxFit.cover, loadingBuilder: (context, child, loadingProgress) { if (loadingProgress == null) return child; return Container(height: 250, width: 250, color: Colors.grey.withValues(alpha: 0.2), child: const Center(child: CircularProgressIndicator(color: Colors.green))); }) : Image.memory(base64Decode(data['imageBase64']), height: 250, width: 250, fit: BoxFit.cover, gaplessPlayback: true))); }
    else if (data['audioUrl'] != null || data['audioBase64'] != null) { bool isPlaying = _playingMsgId == msgId; content = Row(mainAxisSize: MainAxisSize.min, children: [GestureDetector(onTap: () => _playAudio(msgId, audioUrl: data['audioUrl'], base64Audio: data['audioBase64']), child: CircleAvatar(radius: 22, backgroundColor: isMe ? Colors.white24 : Colors.green, child: Icon(isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white))), const SizedBox(width: 8), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SliderTheme(data: SliderThemeData(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6), overlayShape: const RoundSliderOverlayShape(overlayRadius: 10), activeTrackColor: isMe ? Colors.white : Colors.green, inactiveTrackColor: isMe ? Colors.white38 : Colors.grey.shade300, thumbColor: isMe ? Colors.white : Colors.green), child: Slider(value: (isPlaying && _totalAudioDuration.inMilliseconds > 0) ? _currentAudioPosition.inMilliseconds.toDouble() : 0.0, max: (isPlaying && _totalAudioDuration.inMilliseconds > 0) ? _totalAudioDuration.inMilliseconds.toDouble() : 1.0, onChanged: (val) { if (isPlaying) _audioPlayer.seek(Duration(milliseconds: val.toInt())); })), Padding(padding: const EdgeInsets.only(left: 10), child: Text(isPlaying ? "${_formatDuration(_currentAudioPosition.inSeconds)} / ${_formatDuration(_totalAudioDuration.inSeconds)}" : "🎤 ${AppText.get('chat_voice_msg')}", style: TextStyle(fontSize: 10, color: bubbleTextColor.withValues(alpha: 0.7))))])), if (isPlaying) GestureDetector(onTap: _cyclePlaybackRate, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), decoration: BoxDecoration(color: isMe ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(10)), child: Text("${_playbackRate}x", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: bubbleTextColor))))]); }
    else if (data['fileUrl'] != null) { String fName = data['fileName'] ?? 'Документ'; content = GestureDetector(onTap: () => _launchUrl(data['fileUrl']), child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.insert_drive_file, color: Colors.orange, size: 30), const SizedBox(width: 10), Flexible(child: Text(fName, style: TextStyle(color: bubbleTextColor, fontWeight: FontWeight.bold, decoration: TextDecoration.underline), overflow: TextOverflow.ellipsis))]))); }
    else { content = SelectableText(data['text'] ?? '', style: TextStyle(fontSize: _chatFontSize, color: bubbleTextColor)); }

    Widget? replyWidget; if (data['replyToText'] != null) { replyWidget = Container(margin: const EdgeInsets.only(bottom: 5), padding: const EdgeInsets.all(5), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8), border: Border(left: BorderSide(color: isMe? Colors.white : Colors.green, width: 3))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data['replyToSender'] ?? "User", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: bubbleTextColor.withValues(alpha: 0.8))), Text(data['replyToText'], maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: bubbleTextColor.withValues(alpha: 0.7))) ])); }

    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), decoration: BoxDecoration(color: bubbleColor, borderRadius: BorderRadius.only(topLeft: const Radius.circular(16), topRight: const Radius.circular(16), bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4), bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))]),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (!isMe) Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [SmartAvatar(userId: data['senderId'] ?? ''), const SizedBox(width: 8), Text(data['senderName']??'', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange.shade800, fontSize: 13))])),
            if (replyWidget != null) replyWidget, content, const SizedBox(height: 4),
            Align(alignment: Alignment.bottomRight, child: Row(mainAxisSize: MainAxisSize.min, children: [if (isEdited) Text("ed. ", style: TextStyle(fontSize: 9, color: bubbleTextColor.withValues(alpha: 0.5))), Text(time, style: TextStyle(fontSize: 10, color: bubbleTextColor.withValues(alpha: 0.7))), if (isMe) ...[const SizedBox(width: 4), Icon(isReadByOthers ? Icons.done_all : Icons.check, size: 14, color: isReadByOthers ? Colors.blueAccent : Colors.white70)]])),
          ]),
        ),
        if (reactionEmojis.isNotEmpty) Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: isDark ? Colors.grey.shade800 : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300, width: 0.5)), child: Row(mainAxisSize: MainAxisSize.min, children: [Text(reactionEmojis.take(3).join(''), style: const TextStyle(fontSize: 14)), if (reactionEmojis.length > 1) Padding(padding: const EdgeInsets.only(left: 4), child: Text("${reactionEmojis.length}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black54)))]))
      ],
    );
  }

  Widget _buildInputArea(bool isDark, Color textColor) {
    return SafeArea(
      child: Column(
        children: [
          if (_replyMessage != null) Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), color: isDark ? Colors.grey.shade900 : Colors.grey.shade200, child: Row(children: [const Icon(Icons.reply, color: Colors.green), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("${AppText.get('notif_reply_to')} ${_replyMessage!['sender']}", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)), Text(_replyMessage!['text']!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor.withValues(alpha: 0.7)))])), IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _replyMessage = null))])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8), color: isDark ? const Color(0xFF1F1F1F) : Colors.white,
            child: Row(children: [
              if (_isRecording) ...[const SizedBox(width: 16), const Icon(Icons.mic, color: Colors.red), const SizedBox(width: 8), Text(_formatDuration(_recordDuration), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)), const Spacer(), Text(AppText.get('chat_release_to_send'), style: const TextStyle(color: Colors.grey, fontSize: 13)), const SizedBox(width: 16)]
              else ...[
                if (_editingMsgId == null) IconButton(icon: const Icon(Icons.attach_file), color: Colors.grey, onPressed: _showAttachmentOptions) else IconButton(icon: const Icon(Icons.close), color: Colors.red, onPressed: () { setState(() { _editingMsgId = null; _msgController.clear(); }); }),
                Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(color: isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100, borderRadius: BorderRadius.circular(24)), child: TextField(controller: _msgController, maxLines: 5, minLines: 1, style: TextStyle(color: textColor), contentInsertionConfiguration: ContentInsertionConfiguration(onContentInserted: (KeyboardInsertedContent content) async { if (content.data != null) { try { _startUploadProgress(); final tempDir = await getTemporaryDirectory(); File tempFile = File('${tempDir.path}/pasted_img_${DateTime.now().millisecondsSinceEpoch}.png'); await tempFile.writeAsBytes(content.data!); await _chatService.sendImage(widget.chatId, tempFile, isDirect: widget.isDirect); _notifyRecipients("📷 ${AppText.get('chat_photo_msg')}"); _scrollToBottom(); } catch (e) { if (mounted) SnackbarUtils.showError(context, AppText.get('msg_error')); } finally { setState(() => _isUploading = false); } } }), decoration: InputDecoration(hintText: _editingMsgId != null ? "..." : AppText.get('chat_hint'), hintStyle: TextStyle(color: isDark ? Colors.grey : null), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 10))))), const SizedBox(width: 8),
              ],
              GestureDetector(onLongPress: () { if (_isTextEmpty && _editingMsgId == null) { _startRecording(); } else if (!_isTextEmpty) { _showSilentSendMenu(); } }, onLongPressUp: () { if (_isTextEmpty && _editingMsgId == null) { _stopRecording(); } }, onLongPressCancel: () { if (_isTextEmpty && _editingMsgId == null && _isRecording) { _stopRecording(); } }, onTap: () { if (_isTextEmpty && _editingMsgId == null) { SnackbarUtils.showInfo(context, AppText.get('chat_hold_to_record')); } else { _sendMessage(); } }, child: AnimatedContainer(duration: const Duration(milliseconds: 200), width: _isRecording ? 54 : 48, height: _isRecording ? 54 : 48, decoration: BoxDecoration(color: _isRecording ? Colors.red : (_editingMsgId != null ? Colors.blue : _myBubbleColor), shape: BoxShape.circle), child: Icon(_editingMsgId != null ? Icons.check : (_isTextEmpty ? Icons.mic_none : Icons.send), color: Colors.white, size: _isRecording ? 30 : 24))),
            ]),
          ),
        ],
      ),
    );
  }

  // 🔥 ПУШІ
  Future<void> _notifyRecipients(String messageText, {String? replyToName}) async { try { final myDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get(); final myName = myDoc.data()?['displayName'] ?? AppText.get('notif_someone'); String notificationType = widget.isDirect ? 'private_chat' : 'family_chat'; String targetChatId = widget.chatId; String title = widget.isDirect ? myName : "${AppText.get('notif_family')}: $myName"; String body = messageText; if (replyToName != null) { body = "↪️ ${AppText.get('notif_reply_to')} $replyToName: $messageText"; } if (widget.isDirect) { String receiverId = ''; if (widget.chatId.contains('_')) { final parts = widget.chatId.split('_'); if (parts.length == 2) { if (parts[0] == user.uid) receiverId = parts[1]; else if (parts[1] == user.uid) receiverId = parts[0]; } } if (receiverId.isEmpty) { final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).get(); if (chatDoc.exists) { final participants = List<String>.from(chatDoc.data()?['participants'] ?? []); receiverId = participants.firstWhere((id) => id != user.uid, orElse: () => ''); } } if (receiverId.isNotEmpty) { final receiverDoc = await FirebaseFirestore.instance.collection('users').doc(receiverId).get(); final token = receiverDoc.data()?['fcmToken']; if (token != null) await _sendPushV1(token, title, body, notificationType, targetChatId); } } else { String? householdId = myDoc.data()?['householdId']; if (householdId != null) { final familyMembers = await FirebaseFirestore.instance.collection('users').where('householdId', isEqualTo: householdId).get(); for (var doc in familyMembers.docs) { if (doc.id == user.uid) continue; final token = doc.data()['fcmToken']; if (token != null) _sendPushV1(token, title, body, notificationType, targetChatId); } } } } catch (e) { debugPrint("❌ [PUSH] Error: $e"); } }
  Future<void> _sendPushV1(String token, String title, String body, String type, String chatId) async { try { final accountCredentials = auth.ServiceAccountCredentials.fromJson(googleServiceAccount); final scopes = ['https://www.googleapis.com/auth/firebase.messaging']; final client = await auth.clientViaServiceAccount(accountCredentials, scopes); await client.post(Uri.parse('https://fcm.googleapis.com/v1/projects/${googleServiceAccount['project_id']}/messages:send'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({ 'message': { 'token': token, 'notification': { 'title': title, 'body': body }, 'data': { 'type': type, 'chatId': chatId, 'click_action': 'FLUTTER_NOTIFICATION_CLICK' } } })); client.close(); } catch (e) { debugPrint("❌ [PUSH V1] Exception: $e"); } }
}