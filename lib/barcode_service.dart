import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class BarcodeService {
  static Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    // Безкоштовна база даних продуктів з усього світу
    final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Якщо продукт знайдено в базі
        if (data['status'] == 1 && data['product'] != null) {
          final product = data['product'];

          // Витягуємо назву продукту
          String name = product['product_name_uk'] ??
              product['product_name_ru'] ??
              product['product_name'] ?? '';

          // Додаємо бренд, щоб звучало красивіше
          String brands = product['brands'] ?? '';
          String fullName = brands.isNotEmpty && !name.toLowerCase().contains(brands.toLowerCase())
              ? '$brands $name'.trim()
              : name;

          if (fullName.isEmpty) return null;

          // Розумно підбираємо категорію під наші іконки
          String category = 'other';
          String categoriesTags = (product['categories_tags'] as List?)?.join(',') ?? '';

          if (categoriesTags.contains('dairy') || categoriesTags.contains('milk')) { category = 'dairy'; }
          else if (categoriesTags.contains('meat') || categoriesTags.contains('sausages')) { category = 'meat'; }
          else if (categoriesTags.contains('beverages') || categoriesTags.contains('drinks')) { category = 'drink'; }
          else if (categoriesTags.contains('sweets') || categoriesTags.contains('chocolates')) { category = 'sweet'; }
          else if (categoriesTags.contains('plant-based') || categoriesTags.contains('vegetables') || categoriesTags.contains('fruits')) { category = 'veg'; }
          else if (categoriesTags.contains('bread') || categoriesTags.contains('bakery')) { category = 'bakery'; }

          return {
            'name': fullName,
            'category': category,
          };
        }
      }
      return null; // Якщо бази немає або продукт не знайдено
    } catch (e) {
      debugPrint('Barcode error: $e');
      return null;
    }
  }
}