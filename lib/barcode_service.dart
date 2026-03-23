import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class BarcodeService {
  // Використовуємо безкоштовне API Open Food Facts
  static Future<Map<String, dynamic>?> getProductByBarcode(String barcode) async {
    final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Якщо продукт знайдено
        if (data['status'] == 1 && data['product'] != null) {
          final product = data['product'];

          // Витягуємо назву (шукаємо українську, російську або англійську, що є)
          String name = product['product_name_uk'] ??
              product['product_name_ru'] ??
              product['product_name'] ?? '';

          // Витягуємо бренд, щоб було красивіше (напр. "Яготинське Молоко")
          String brands = product['brands'] ?? '';
          String fullName = brands.isNotEmpty && !name.toLowerCase().contains(brands.toLowerCase())
              ? '$brands $name'.trim()
              : name;

          if (fullName.isEmpty) return null;

          // Пробуємо вгадати категорію (дуже базово)
          String category = 'other';
          String categoriesTags = (product['categories_tags'] as List?)?.join(',') ?? '';
          if (categoriesTags.contains('dairy') || categoriesTags.contains('milk')) category = 'dairy';
          if (categoriesTags.contains('meat') || categoriesTags.contains('sausages')) category = 'meat';
          if (categoriesTags.contains('beverages')) category = 'drink';
          if (categoriesTags.contains('sweets') || categoriesTags.contains('chocolates')) category = 'sweet';

          return {
            'name': fullName,
            'category': category,
          };
        }
      }
      return null; // Продукт не знайдено
    } catch (e) {
      debugPrint('Помилка сканування штрихкоду: $e');
      return null;
    }
  }
}