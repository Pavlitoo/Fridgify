import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'recipe_model.dart';
import '../translations.dart';

class AiRecipeService {

  // ===========================================================================
  // 🍳 ГЕНЕРАЦІЯ РЕЦЕПТІВ
  // ===========================================================================
  Future<List<Recipe>> getRecipes({
    required List<String> ingredients,
    required String userLanguage,
    required String dietType
  }) async {
    debugPrint("👨‍🍳 Викликаємо безпечну Cloud Function (Gemini)...");

    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'generateRecipes',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
      );

      final response = await callable.call({
        'ingredients': ingredients,
        'userLanguage': userLanguage,
        'dietType': dietType,
      });

      String content = response.data['result'] as String;
      content = content.replaceAll('```json', '').replaceAll('```', '').trim();

      dynamic decodedData;
      try {
        int startObj = content.indexOf('{');
        int endObj = content.lastIndexOf('}');

        if (startObj != -1 && endObj != -1 && endObj > startObj) {
          content = content.substring(startObj, endObj + 1);
          decodedData = jsonDecode(content);
        } else {
          throw const FormatException("Неповний JSON від AI");
        }
      } catch (e) {
        debugPrint("❌ JSON Parse Error: $e \nContent: $content");
        throw Exception(AppText.get('err_recipe_failed'));
      }

      List<dynamic> jsonList;
      if (decodedData is Map) {
        if (decodedData.containsKey('error') && decodedData['error'] == 'INVALID_INGREDIENTS') {
          throw Exception(AppText.get('err_invalid_ingredients'));
        }
        if (decodedData.containsKey('recipes') && decodedData['recipes'] != null) {
          jsonList = decodedData['recipes'];
        } else {
          throw Exception(AppText.get('err_recipe_failed'));
        }
      } else {
        throw Exception(AppText.get('err_recipe_failed'));
      }

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

    } on FirebaseFunctionsException catch (e) {
      debugPrint("🔴 Firebase Functions Error: ${e.code} - ${e.message}");
      throw Exception(AppText.get('err_general'));
    } on TimeoutException {
      throw Exception(AppText.get('err_check_internet'));
    } on SocketException {
      throw Exception(AppText.get('err_no_internet'));
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.startsWith("Exception: ")) {
        throw Exception(errorMsg.replaceFirst("Exception: ", ""));
      }
      throw Exception(AppText.get('err_recipe_failed'));
    }
  }

  // ===========================================================================
  // 📸 АНАЛІЗ ФОТО ХОЛОДИЛЬНИКА
  // ===========================================================================
  Future<List<Map<String, dynamic>>> analyzeFridgeImage({
    required File imageFile,
    required String userLanguage,
  }) async {
    debugPrint("📸 Відправляємо фото холодильника в Gemini Vision...");

    try {
      final bytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(bytes);

      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'analyzeFridgePhoto',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      final response = await callable.call({
        'imageBase64': base64Image,
        'userLanguage': userLanguage,
      });

      final String resultText = response.data['result'] as String;
      String content = resultText.replaceAll('```json', '').replaceAll('```', '').trim();

      List<dynamic> jsonList;
      try {
        jsonList = jsonDecode(content);
      } catch (e) {
        debugPrint("❌ Помилка парсингу Vision JSON: $e");
        throw Exception(AppText.get('err_general'));
      }

      return jsonList.map((item) => Map<String, dynamic>.from(item)).toList();

    } on FirebaseFunctionsException catch (e) {
      debugPrint("🔴 Firebase Vision Error: ${e.code} - ${e.message}");
      throw Exception(AppText.get('err_general'));
    } on TimeoutException {
      throw Exception(AppText.get('err_check_internet'));
    } on SocketException {
      throw Exception(AppText.get('err_no_internet'));
    } catch (e) {
      throw Exception(AppText.get('err_general'));
    }
  }

  // ===========================================================================
  // 🧾 АНАЛІЗ ЧЕКУ З МАГАЗИНУ (НОВЕ!)
  // ===========================================================================
  Future<List<Map<String, dynamic>>> analyzeReceiptImage({
    required File imageFile,
    required String userLanguage,
  }) async {
    debugPrint("🧾 Відправляємо фото чеку в Gemini Vision...");

    try {
      final bytes = await imageFile.readAsBytes();
      final String base64Image = base64Encode(bytes);

      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'analyzeReceiptPhoto',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 90)),
      );

      final response = await callable.call({
        'imageBase64': base64Image,
        'userLanguage': userLanguage,
      });

      final String resultText = response.data['result'] as String;
      String content = resultText.replaceAll('```json', '').replaceAll('```', '').trim();

      List<dynamic> jsonList;
      try {
        jsonList = jsonDecode(content);
      } catch (e) {
        debugPrint("❌ Помилка парсингу Receipt JSON: $e");
        throw Exception(AppText.get('err_general'));
      }

      debugPrint("✅ AI розпізнав чек: знайшов ${jsonList.length} продуктів!");
      return jsonList.map((item) => Map<String, dynamic>.from(item)).toList();

    } on FirebaseFunctionsException catch (e) {
      debugPrint("🔴 Firebase Receipt Error: ${e.code} - ${e.message}");
      throw Exception(AppText.get('err_general'));
    } on TimeoutException {
      throw Exception(AppText.get('err_check_internet'));
    } on SocketException {
      throw Exception(AppText.get('err_no_internet'));
    } catch (e) {
      throw Exception(AppText.get('err_general'));
    }
  }
}