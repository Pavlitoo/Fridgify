import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final DateTime expirationDate;
  final DateTime addedDate;

  Product({
    required this.id,
    required this.name,
    required this.expirationDate,
    required this.addedDate,
  });

  // Перетворюємо дані з Бази в Продукт
  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      expirationDate: (data['expirationDate'] as Timestamp).toDate(),
      addedDate: (data['addedDate'] as Timestamp).toDate(),
    );
  }

  // Перетворюємо Продукт в дані для Бази
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'expirationDate': expirationDate,
      'addedDate': addedDate,
    };
  }

  // Рахуємо дні
  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expirationDate.year, expirationDate.month, expirationDate.day);
    return exp.difference(today).inDays;
  }
}