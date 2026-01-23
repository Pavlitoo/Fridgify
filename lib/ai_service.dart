import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'recipe_model.dart';

class AiRecipeService {
  final String _baseUrl = 'https://openrouter.ai/api/v1/chat/completions';

  Future<List<Recipe>> getRecipes({
    required List<String> ingredients,
    required String userLanguage,
    required String dietType
  }) async {
    String? apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("API Key missing");
    }

    String dietInstruction = "";
    switch (dietType) {
      case 'vegetarian': dietInstruction = "Vegetarian (no meat)."; break;
      case 'vegan': dietInstruction = "Vegan (no animal products)."; break;
      case 'healthy': dietInstruction = "Healthy balanced diet (PP)."; break;
      case 'keto': dietInstruction = "Keto (low carb)."; break;
      default: dietInstruction = "Standard tasty food.";
    }

    // 🔥 ОНОВЛЕНИЙ ПРОМПТ
    final String prompt = '''
    Role: Professional Chef & Tech Parser.
    User Inventory: ${ingredients.join(', ')}.
    Target Language: $userLanguage.
    Diet: $dietInstruction

    TASK 1 (ANALYSIS):
    - The "User Inventory" might contain words in different languages (e.g., "Ananas" instead of "Pineapple"). Understand them as food.
    - Check for GIBBERISH (random letters like "asdf", "ываыва", "powerwvj").
    - If ALL items are gibberish/not food -> Return JSON: [{"error": "INVALID_INGREDIENTS"}]
    - If at least ONE item is valid food -> Proceed to TASK 2.

    TASK 2 (GENERATION):
    - Create 5 recipes using the valid ingredients found.
    - Translate everything to "$userLanguage".
    - Convert units to Metric (g, ml, kg) if language is Ukrainian/European.
    - Missing ingredients MUST have quantities (e.g., "50ml Oil").

    JSON OUTPUT ONLY (No extra text):
    [
      {
        "title": "Recipe Name",
        "description": "Short description",
        "time": "30 min",
        "kcal": "450",
        "isVegetarian": true,
        "searchQuery": "English dish name",
        "ingredients": ["200g Ingredient"],
        "missingIngredients": ["50ml Oil", "10g Salt"],
        "steps": ["Step 1", "Step 2"]
      }
    ]
    ''';

    debugPrint("👨‍🍳 AI Chef: Thinking...");

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
          "messages": [{"role": "user", "content": prompt}],
          "temperature": 0.4,
          "max_tokens": 2500,
        }),
      ).timeout(const Duration(seconds: 100));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        if (data['choices'] == null || data['choices'].isEmpty) {
          throw Exception("AI Empty Response");
        }

        String content = data['choices'][0]['message']['content'];

        // 🔥 ВИПРАВЛЕННЯ ПОМИЛКИ FormatException
        // Шукаємо чистий JSON масив між [ та ]
        int startIndex = content.indexOf('[');
        int endIndex = content.lastIndexOf(']');

        if (startIndex == -1 || endIndex == -1) {
          // Якщо ШІ не повернув масив, можливо він повернув помилку без дужок
          if (content.contains("INVALID_INGREDIENTS")) {
            throw Exception('INVALID_INGREDIENTS');
          }
          throw Exception("AI Format Error: No JSON found");
        }

        // Вирізаємо чистий JSON
        String jsonString = content.substring(startIndex, endIndex + 1);

        List<dynamic> jsonList;
        try {
          jsonList = jsonDecode(jsonString);
        } catch (e) {
          debugPrint("JSON Parse Error: $e \nContent: $jsonString");
          throw Exception("JSON_PARSE_ERROR");
        }

        // Перевірка на валідацію
        if (jsonList.isNotEmpty && jsonList[0] is Map && jsonList[0].containsKey('error')) {
          throw Exception('INVALID_INGREDIENTS');
        }

        return jsonList.map((json) {
          String query = json['searchQuery'] ?? 'food';
          String imageUrl = "https://tse2.mm.bing.net/th?q=${Uri.encodeComponent('$query meal recipe')}&w=800&h=600&c=7&rs=1&p=0";

          // 🔥 БЕЗПЕЧНА ФУНКЦІЯ ЗАМІНИ ОДИНИЦЬ
          List<String> cleanUnits(List<dynamic> list) {
            List<String> result = list.map((e) => e.toString()).toList();

            if (userLanguage == 'Українська') {
              return result.map((str) {
                // Прибираємо можливі артефакти ($)
                String s = str.replaceAll(r'$', '');

                // Замінюємо одиниці
                s = s.replaceAllMapped(RegExp(r'(\d+)\s*g\b', caseSensitive: false), (m) => '${m[1]} г');
                s = s.replaceAllMapped(RegExp(r'(\d+)\s*kg\b', caseSensitive: false), (m) => '${m[1]} кг');
                s = s.replaceAllMapped(RegExp(r'(\d+)\s*ml\b', caseSensitive: false), (m) => '${m[1]} мл');
                s = s.replaceAllMapped(RegExp(r'(\d+)\s*l\b', caseSensitive: false), (m) => '${m[1]} л');

                s = s.replaceAll(RegExp(r'\btbsp\b', caseSensitive: false), 'ст.л.');
                s = s.replaceAll(RegExp(r'\btsp\b', caseSensitive: false), 'ч.л.');
                s = s.replaceAll(RegExp(r'\bpcs\b', caseSensitive: false), 'шт');

                return s;
              }).toList();
            }
            return result;
          }

          json['ingredients'] = cleanUnits(json['ingredients'] ?? []);
          json['missingIngredients'] = cleanUnits(json['missingIngredients'] ?? []);
          json['imageUrl'] = imageUrl;

          return Recipe.fromJson(json);
        }).toList();

      } else {
        if (response.statusCode == 401) throw Exception("401");
        throw Exception("Server Error: ${response.statusCode}");
      }
    } on TimeoutException {
      throw TimeoutException("TIMEOUT");
    } on SocketException {
      throw const SocketException('NO_INTERNET');
    } catch (e) {
      debugPrint("🔴 AI Error: $e");
      rethrow;
    }
  }
}