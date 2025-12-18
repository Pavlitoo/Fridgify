import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AiRecipeService {
  // 👇 Твій ключ OpenRouter
  static String get apiKey => dotenv.env['OPENROUTER_KEY'] ?? '';

  // 🚀 ТІЛЬКИ ШВИДКІ ТА РОБОЧІ МОДЕЛІ
  // Ми прибрали Google, який видавав помилки, щоб не гаяти час.
  final List<String> _models = [
    "mistralai/mistral-7b-instruct:free",   // Твоя перевірена "робоча конячка" 🐎
    "meta-llama/llama-3-8b-instruct:free",  // Дуже швидкий резерв
  ];

  Future<List<Map<String, dynamic>>> getRecipes({
    required List<String> ingredients,
    required String userLanguage,
    required String diet,
  }) async {

    if (apiKey.isEmpty) {
      throw "API Key not found in .env file!";
    }

    final uri = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    // 👇 ТУТ ТЕПЕР 5 РЕЦЕПТІВ (Create 5 recipes)
    final prompt = '''
      You are a professional chef.
      
      INPUT DATA:
      - Ingredients: ${ingredients.join(', ')}
      - Diet preferences: $diet
      - TARGET LANGUAGE: $userLanguage

      TASK:
      Create 5 recipes based on ingredients.
      
      CRITICAL RULES:
      1. RETURN ONLY A VALID JSON ARRAY. No markdown, no intro text.
      2. TRANSLATE EVERYTHING TO $userLanguage. Title, description, instructions - ALL in $userLanguage.
      
      JSON FORMAT:
      [
        {
          "title": "Name ($userLanguage)",
          "description": "Short tasty description ($userLanguage)",
          "missingIngredients": ["Ing1", "Ing2"],
          "instructions": "Step 1... Step 2... ($userLanguage)",
          "emoji": "🍲" 
        }
      ]
    ''';

    // 🔄 ЦИКЛ (Тільки по швидких моделях)
    for (String model in _models) {
      try {
        print("📡 Trying fast AI model: $model...");

        final response = await http.post(
          uri,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://smartfridge.app',
            'X-Title': 'Smart Fridge App',
          },
          body: json.encode({
            "model": model,
            "messages": [
              {"role": "user", "content": prompt}
            ]
          }),
        );

        print("📩 Code: ${response.statusCode}");

        if (response.statusCode == 200) {
          final data = json.decode(utf8.decode(response.bodyBytes));

          if (data['error'] != null) {
            print("⚠️ API Error: ${data['error']}");
            continue;
          }

          String content = data['choices'][0]['message']['content'];

          // 🧹 ЧИСТКА JSON (Знаходимо квадратні дужки)
          int startIndex = content.indexOf('[');
          int endIndex = content.lastIndexOf(']');

          if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
            content = content.substring(startIndex, endIndex + 1);
          } else {
            print("⚠️ Invalid JSON from $model. Trying backup...");
            continue;
          }

          final List<dynamic> jsonList = json.decode(content);
          print("✅ Success! Loaded 5 recipes using $model");
          return jsonList.map((e) => e as Map<String, dynamic>).toList();
        } else {
          print("⚠️ Model $model busy (Code ${response.statusCode}). Switching to backup...");
          continue;
        }

      } catch (e) {
        print("❌ Error with $model: $e");
        continue;
      }
    }

    print("❌ All fast models failed.");
    throw "Вибачте, сервери перевантажені. Спробуйте через хвилину! 👨‍🍳";
  }
}