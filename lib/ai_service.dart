import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'recipe_model.dart';

class AiRecipeService {
  // Використовуємо OpenRouter
  final String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  Future<List<Recipe>> getRecipes({required List<String> ingredients, required String userLanguage}) async {
    String? apiKey = dotenv.env['OPENAI_API_KEY'];

    if (apiKey == null || apiKey.isEmpty) {
      print("🔴 ПОМИЛКА: Ключ не знайдено в .env! Перевір файл.");
      throw Exception("API Key missing");
    }

    final String prompt = '''
    Ти професійний кухар. У мене є: ${ingredients.join(', ')}.
    Мова користувача: $userLanguage.
    Придумай 3 рецепти.
    
    ВАЖЛИВО: Відповідай ТІЛЬКИ чистим JSON. Не пиши ніякого вступу.
    Формат JSON масиву:
    [
      {
        "title": "Назва страви",
        "description": "Короткий опис",
        "time": "30 хв",
        "kcal": "400 ккал",
        "ingredients": ["інгредієнт 1", "інгредієнт 2"],
        "steps": ["Крок 1", "Крок 2"],
        "imageUrl": "https://source.unsplash.com/800x600/?food,dinner"
      }
    ]
    ''';

    print("🟡 Відправляю запит на OpenRouter...");

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
          // Використовуємо безкоштовну модель Gemini через OpenRouter
          "model": "google/gemini-2.0-flash-lite-preview-02-05:free",
          "messages": [
            {"role": "system", "content": "You are a JSON generator. Output only valid JSON array."},
            {"role": "user", "content": prompt}
          ],
          "temperature": 0.7,
        }),
      );

      print("🔵 Код відповіді: ${response.statusCode}");

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String content = data['choices'][0]['message']['content'];

        // Чистимо відповідь від можливих markdown тегів
        content = content.replaceAll('```json', '').replaceAll('```', '').trim();

        List<dynamic> jsonList = jsonDecode(content);

        // 👇 ВИПРАВЛЕННЯ ТУТ: Ми прибрали поле 'id', бо його немає в твоїй моделі Recipe
        return jsonList.map((json) => Recipe(
          title: json['title'] ?? 'Без назви',
          description: json['description'] ?? '',
          imageUrl: json['imageUrl'] ?? 'https://via.placeholder.com/300?text=No+Image',
          time: json['time'] ?? '30 хв',
          kcal: json['kcal'] ?? 'Unknown',
          ingredients: List<String>.from(json['ingredients'] ?? []),
          steps: List<String>.from(json['steps'] ?? []),
          // category: 'dinner', // Якщо в конструкторі немає category, закоментуй і цей рядок
        )).toList();
      } else {
        throw Exception("Server Error: ${response.statusCode}");
      }
    } catch (e) {
      print("🔴 CRITICAL ERROR: $e");
      throw Exception("Failed to load recipes: $e");
    }
  }
}