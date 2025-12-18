import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  final String id;
  final String name;
  final DateTime expirationDate;
  final DateTime addedDate;
  final String category; // 🆕 Added category (icon name)

  Product({
    required this.id,
    required this.name,
    required this.expirationDate,
    required this.addedDate,
    required this.category,
  });

  // Convert Firestore data to Product object
  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Product(
      id: doc.id,
      name: data['name'] ?? '',
      expirationDate: (data['expirationDate'] as Timestamp).toDate(),
      addedDate: (data['addedDate'] as Timestamp).toDate(),
      category: data['category'] ?? 'other', // Default to 'other' if no category
    );
  }

  // Convert Product object to Firestore data
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'expirationDate': expirationDate,
      'addedDate': addedDate,
      'category': category,
    };
  }

  // Calculate days left
  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expirationDate.year, expirationDate.month, expirationDate.day);
    return exp.difference(today).inDays;
  }
}