import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final DateTime expirationDate;
  final DateTime addedDate;
  final String category;
  // 🆕 НОВІ ПОЛЯ
  final double quantity;
  final String unit;

  Product({
    required this.id,
    required this.name,
    required this.expirationDate,
    required this.addedDate,
    required this.category,
    this.quantity = 1.0, // Дефолт
    this.unit = 'pcs',   // Дефолт
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      expirationDate: (data['expirationDate'] as Timestamp).toDate(),
      addedDate: (data['addedDate'] as Timestamp).toDate(),
      category: data['category'] ?? 'other',
      // Читаємо нові поля, якщо їх немає - беремо дефолт
      quantity: (data['quantity'] ?? 1.0).toDouble(),
      unit: data['unit'] ?? 'pcs',
    );
  }

  int get daysLeft {
    final now = DateTime.now();
    // Скидаємо час до опівночі, щоб рахувати тільки дні
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expirationDate.year, expirationDate.month, expirationDate.day);
    return exp.difference(today).inDays;
  }
}