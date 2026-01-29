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

    // 🧠 AI САМ РОЗУМІЄ ЩО СМІТТЯ
    final String prompt = '''
You are a SMART chef with built-in security system. Your job has 2 phases:

📋 USER'S INPUT: ${ingredients.join(', ')}
🗣️ TARGET LANGUAGE: $userLanguage
🥗 DIET TYPE: $dietInstruction

═══════════════════════════════════════════════════════
PHASE 1: INTELLIGENT FOOD VALIDATION
═══════════════════════════════════════════════════════

Analyze EACH item in the user's list. Ask yourself:
❓ "Is this something you can EAT or COOK with?"

✅ REAL FOOD (Accept these):
- Fruits: Apple, Banana, Orange, Mango, etc.
- Vegetables: Tomato, Potato, Carrot, Cucumber, etc.
- Proteins: Chicken, Beef, Fish, Egg, Tofu, etc.
- Dairy: Milk, Cheese, Butter, Yogurt, etc.
- Grains: Rice, Pasta, Bread, Flour, etc.
- Spices & Condiments: Salt, Pepper, Sugar, Honey, Oil, etc.
- Beverages for cooking: Water, Wine, Broth, etc.

❌ GARBAGE (Reject these):
- Electronics: laptop, phone, computer, keyboard
- Furniture: chair, table, desk, sofa
- Random typing: asdf, qwerty, zzzz, lalala, sdfsdf
- Test words: test, testing, debug, dev
- Non-food objects: brick, stone, paper, plastic
- Gibberish: kjsdhfkjsd, wwwww, xxxxxx
- Anything that makes NO SENSE as food

🔍 VALIDATION LOGIC:
- If ALL items are real food → Continue to Phase 2
- If EVEN ONE item is garbage/non-food → Return error immediately

═══════════════════════════════════════════════════════
PHASE 2: RECIPE GENERATION (Only if Phase 1 passed)
═══════════════════════════════════════════════════════

Create EXACTLY 5 DIVERSE recipes:
1. Different cooking methods (baking, frying, raw, boiling, etc.)
2. Different dish types (main course, salad, dessert, soup, etc.)
3. Adapt to available ingredients:
   - Only fruits? → Make fruit salads, smoothies, desserts, jams
   - Only vegetables? → Make salads, soups, stir-fries
   - Mix of items? → Create balanced meals

📝 RECIPE REQUIREMENTS:
- Translate EVERYTHING to "$userLanguage"
- Use Metric units ONLY: g, kg, ml, l (NO cups, oz, tbsp)
- Be creative but realistic

📦 INGREDIENT SORTING:
- "ingredients": Items from user's list that THIS recipe uses
  Example: User has [Apple, Milk, Egg], recipe uses Apple & Milk
  → ["2 pcs Apple", "200ml Milk"]

- "missingIngredients": Everything else the recipe needs
  Example: Recipe also needs Flour, Sugar
  → ["150g Flour", "30g Sugar"]

═══════════════════════════════════════════════════════
OUTPUT FORMAT
═══════════════════════════════════════════════════════

If VALIDATION FAILED (found non-food):
Return this EXACT JSON:
[{"error": "INVALID_INGREDIENTS"}]

If VALIDATION PASSED (all items are food):
Return 5 recipes in this format:
[
  {
    "title": "Recipe name in $userLanguage",
    "description": "Appetizing description in $userLanguage",
    "time": "30 min",
    "kcal": "350",
    "isVegetarian": true,
    "searchQuery": "english name for image search",
    "ingredients": ["2 pcs Apple", "200ml Milk"],
    "missingIngredients": ["150g Flour", "2 pcs Egg", "30g Sugar"],
    "steps": [
      "Step 1 in $userLanguage",
      "Step 2 in $userLanguage",
      "Step 3 in $userLanguage"
    ]
  },
  ... (4 more recipes)
]

⚠️ CRITICAL: Return ONLY pure JSON (no markdown, no ```json, no explanation)
''';

    debugPrint("👨‍🍳 AI Chef: Analyzing ingredients...");

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
          "temperature": 0.6,
          "max_tokens": 4500,
          "messages": [{"role": "user", "content": prompt}],
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        if (data['choices'] == null || data['choices'].isEmpty) {
          throw Exception("AI Empty Response");
        }

        String content = data['choices'][0]['message']['content'];

        // Чистка від Markdown
        content = content.replaceAll('```json', '').replaceAll('```', '').trim();

        int startIndex = content.indexOf('[');
        int endIndex = content.lastIndexOf(']');

        if (startIndex == -1 || endIndex == -1) {
          if (content.toLowerCase().contains("invalid") ||
              content.toLowerCase().contains("garbage") ||
              content.toLowerCase().contains("not food")) {
            throw Exception('INVALID_INGREDIENTS');
          }
          throw Exception("AI Format Error: No JSON found");
        }

        String jsonString = content.substring(startIndex, endIndex + 1);

        List<dynamic> jsonList;
        try {
          jsonList = jsonDecode(jsonString);
        } catch (e) {
          debugPrint("JSON Parse Error: $e \nContent: $jsonString");
          throw Exception("JSON_PARSE_ERROR");
        }

        // Перевірка на помилку валідації
        if (jsonList.isNotEmpty && jsonList[0] is Map && jsonList[0].containsKey('error')) {
          if (jsonList[0]['error'] == 'INVALID_INGREDIENTS') {
            debugPrint("🚫 AI detected non-food items in the list");
            throw Exception('INVALID_INGREDIENTS');
          }
        }

        debugPrint("✅ AI validated ingredients & created ${jsonList.length} recipes");

        return jsonList.map((json) {
          String query = json['searchQuery'] ?? 'food';
          String imageUrl = "https://tse2.mm.bing.net/th?q=${Uri.encodeComponent('$query meal recipe')}&w=800&h=600&c=7&rs=1&p=0";

          List<String> cleanUnits(List<dynamic> list) {
            List<String> result = list.map((e) => e.toString()).toList();

            if (userLanguage == 'Українська') {
              return result.map((str) {
                String s = str.replaceAll(r'$', '').trim();
                s = s.replaceAllMapped(RegExp(r'(\d+)\s*g\b', caseSensitive: false), (m) => '${m[1]} г');
                s = s.replaceAllMapped(RegExp(r'(\d+)\s*kg\b', caseSensitive: false), (m) => '${m[1]} кг');
                s = s.replaceAllMapped(RegExp(r'(\d+)\s*ml\b', caseSensitive: false), (m) => '${m[1]} мл');
                s = s.replaceAllMapped(RegExp(r'(\d+)\s*l\b', caseSensitive: false), (m) => '${m[1]} л');
                s = s.replaceAll(RegExp(r'\btbsp\b', caseSensitive: false), 'ст.л.');
                s = s.replaceAll(RegExp(r'\btsp\b', caseSensitive: false), 'ч.л.');
                s = s.replaceAll(RegExp(r'\bpcs\b', caseSensitive: false), 'шт');
                s = s.replaceAll(RegExp(r'\bcup\b', caseSensitive: false), 'склянка');
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