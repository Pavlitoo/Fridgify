import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SmartAvatar extends StatelessWidget {
  final String userId;
  final double radius;

  // 🔥 Глобальний статичний кеш. Живе, поки запущено додаток!
  static final Map<String, Uint8List> _globalAvatarCache = {};

  const SmartAvatar({super.key, required this.userId, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) {
      return CircleAvatar(radius: radius, backgroundColor: Colors.grey.shade300, child: Icon(Icons.person, size: radius * 1.2, color: Colors.grey.shade600));
    }

    // 1. Якщо аватарка ВЖЕ є в кеші — віддаємо її МИТТЄВО (без блимання)
    if (_globalAvatarCache.containsKey(userId)) {
      return CircleAvatar(backgroundImage: MemoryImage(_globalAvatarCache[userId]!), radius: radius);
    }

    // 2. Якщо немає — вантажимо з бази ОДИН РАЗ і зберігаємо
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>?;
          final liveAvatar = userData?['avatar_base64'];

          if (liveAvatar != null && liveAvatar.isNotEmpty) {
            try {
              Uint8List bytes = base64Decode(liveAvatar);
              _globalAvatarCache[userId] = bytes; // 🔥 Зберігаємо в кеш!
              return CircleAvatar(backgroundImage: MemoryImage(bytes), radius: radius);
            } catch (e) {
              debugPrint("Avatar decode error: $e");
            }
          }
        }
        // Заглушка, поки вантажиться або якщо немає фото
        return CircleAvatar(radius: radius, backgroundColor: Colors.grey.shade200, child: Icon(Icons.person, size: radius * 1.2, color: Colors.grey.shade500));
      },
    );
  }
}