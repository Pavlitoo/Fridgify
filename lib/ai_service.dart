import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'recipe_model.dart';

class AiRecipeService {
  final String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  Future<List<Recipe>> getRecipes({required List<String> ingredients, required String userLanguage}) async {
    String? apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) throw Exception("API Key missing");

    // 👇 Просимо GPT дати нам точну назву для пошуку картинки
    final String prompt = '''
    Ти шеф-кухар. У користувача є: ${ingredients.join(', ')}. Мова: $userLanguage.
    
    Придумай 5 (п'ять) смачних рецептів.
    
    ВАЖЛИВО: 
    1. Відповідай ТІЛЬКИ чистим JSON масивом.
    2. "searchQuery" - це назва страви АНГЛІЙСЬКОЮ мовою для пошуку фото (наприклад: "Chicken Caesar Salad", "Borsch with sour cream"). Чим точніше, тим краще.
    
    JSON Структура:
    [
      {
        "title": "Назва страви",
        "description": "Короткий смачний опис",
        "time": "30 хв",
        "kcal": "400 ккал",
        "searchQuery": "English Dish Name For Photo",
        "ingredients": ["що є"],
        "missingIngredients": ["що докупити"],
        "steps": ["Крок 1", "Крок 2"]
      }
    ]
    ''';

    debugPrint("👨‍🍳 AI Chef: Генерую 5 рецептів...");

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://fridgify.app',
          'X-Title': 'Fridgify',
        },
        body: jsonEncode({
          "model": "openai/gpt-4o-mini",
          "messages": [
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.7,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String content = data['choices'][0]['message']['content'];
        content = content.replaceAll('```json', '').replaceAll('```', '').trim();
        List<dynamic> jsonList = jsonDecode(content);

        debugPrint("✅ Рецепти готові. Підбираю фото...");

        // Перетворюємо JSON у список рецептів
        return jsonList.map((json) {
          String query = json['searchQuery'] ?? 'delicious food';

          // 🔥 МАГІЯ: Використовуємо Bing Image Proxy для миттєвого пошуку реального фото
          // Це працює набагато стабільніше за генератори
          String imageUrl = "https://tse2.mm.bing.net/th?q=${Uri.encodeComponent(query + ' food recipe high quality')}&w=800&h=600&c=7&rs=1&p=0";

          return Recipe(
            title: json['title'] ?? 'Без назви',
            description: json['description'] ?? '',
            imageUrl: imageUrl, // Ось наше надійне фото
            time: json['time'] ?? '30 хв',
            kcal: json['kcal'] ?? '-',
            ingredients: List<String>.from(json['ingredients'] ?? []),
            missingIngredients: List<String>.from(json['missingIngredients'] ?? []),
            steps: List<String>.from(json['steps'] ?? []),
          );
        }).toList();

      } else {
        throw Exception("AI Server Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("🔴 Error: $e");
      throw Exception("Failed to load recipes: $e");
    }
  }
}