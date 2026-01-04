import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'recipe_model.dart';

class AiRecipeService {

  Future<List<Recipe>> getRecipes({
    required List<String> ingredients,
    required String userLanguage,
    String diet = '',
  }) async {

    List<Future<Recipe?>> futures = List.generate(5, (index) {
      String variation = ["soup", "salad", "main course", "appetizer", "dessert"][index];
      return _getSingleRecipe(ingredients, userLanguage, diet, index, variation);
    });

    final results = await Future.wait(futures);
    return results.whereType<Recipe>().toList();
  }

  Future<Recipe?> _getSingleRecipe(List<String> ingredients, String lang, String diet, int seedModifier, String variation) async {
    final apiKey = dotenv.env['OPENROUTER_KEY'];
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    // 👇 ПРОСИМО ДЕТАЛЬНИЙ ОПИС ДЛЯ ФОТО (img_key)
    String prompt = '''
      Create 1 recipe using: ${ingredients.join(', ')}. Lang: $lang.
      Type: $variation.
      
      Output strict JSON:
      {
        "title": "Recipe Name",
        "title_en": "Recipe Name in English",
        "img_key": "Full english visual description of the dish (e.g. 'bowl of red tomato soup with basil on wooden table')",
        "desc": "Short summary",
        "time": "20 min",
        "kcal": "300",
        "ing": ["Item 1"],
        "steps": ["Step 1"]
      }
    ''';

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
          'HTTP-Referer': 'https://fridgify.app',
          'X-Title': 'Fridgify App',
        },
        body: jsonEncode({
          'model': 'openai/gpt-4o-mini',
          'messages': [{'role': 'user', 'content': prompt}],
          'temperature': 0.8,
          'max_tokens': 450,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String content = data['choices'][0]['message']['content'];
        content = content.replaceAll('```json', '').replaceAll('```', '').trim();
        return Recipe.fromJson(jsonDecode(content));
      }
    } catch (e) {
      print("Error in single request: $e");
      return null;
    }
    return null;
  }
}