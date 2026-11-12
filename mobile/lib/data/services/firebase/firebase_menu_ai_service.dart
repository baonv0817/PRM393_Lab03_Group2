import 'dart:async';
import 'dart:io';

import 'package:breakbite_core/data/services/menu_ai_service.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/menu_item_suggestion.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Calls Gemini through Firebase AI Logic (Gemini Developer API). The API key stays in Firebase, and every
/// request carries an App Check token (`FirebaseAI.googleAI` picks up the App Check activated at start-up), so
/// only this app can spend the quota.
///
/// The answer is structured output: the request gives a JSON schema, and [MenuItemSuggestion.parse] turns the
/// JSON into the Dart model.
class FirebaseMenuAiService implements MenuAiService {
  FirebaseMenuAiService({FirebaseAI Function()? ai, this.timeout = const Duration(seconds: 30)})
    : _ai = ai ?? FirebaseAI.googleAI;

  final FirebaseAI Function() _ai;
  final Duration timeout;

  /// What the K14 form needs; `isFood` lets the model say the photo is not a dish instead of inventing one.
  ///
  /// Every key is required: with optional keys the model answered with the name and the kind only (tried on
  /// 12/11/2026). For a photo that is not food the other values are ignored, because `isFood` is false.
  static final responseSchema = Schema.object(
    properties: {
      MenuItemSuggestion.isFoodKey: Schema.boolean(description: 'false nếu ảnh không phải đồ ăn hay đồ uống'),
      MenuItemSuggestion.nameKey: Schema.string(description: 'Tên món bằng tiếng Việt'),
      MenuItemSuggestion.categoryKey: Schema.enumString(
        enumValues: const ['food', 'drink', 'other'],
        description: 'food là món ăn, drink là đồ uống',
      ),
      MenuItemSuggestion.priceKey: Schema.integer(description: 'Giá gợi ý, đơn vị đồng'),
      MenuItemSuggestion.prepKey: Schema.integer(description: 'Thời gian chuẩn bị, phút'),
      MenuItemSuggestion.descriptionKey: Schema.string(description: 'Mô tả một câu'),
    },
    propertyOrdering: const [
      MenuItemSuggestion.isFoodKey,
      MenuItemSuggestion.nameKey,
      MenuItemSuggestion.categoryKey,
      MenuItemSuggestion.priceKey,
      MenuItemSuggestion.prepKey,
      MenuItemSuggestion.descriptionKey,
    ],
  );

  @override
  Future<Result<MenuItemSuggestion>> suggestFromPhoto(
    Uint8List photo, {
    required String model,
    required String prompt,
  }) async {
    try {
      final gemini = _ai().generativeModel(
        model: model,
        systemInstruction: Content.system(prompt),
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: responseSchema,
          temperature: 0.2,
        ),
      );
      final response = await gemini
          .generateContent([
            Content.multi([
              const TextPart('Điền thông tin món trong ảnh này.'),
              InlineDataPart(mimeTypeOf(photo), photo),
            ]),
          ])
          .timeout(timeout);
      // Debug builds only: the raw answer, for docs/ai-feature.md and for checking a prompt change.
      if (kDebugMode) debugPrint('Gemini K14 answer ($model): ${response.text}');
      return MenuItemSuggestion.parse(response.text);
    } on QuotaExceeded catch (error, stack) {
      return Result.error(AiException(AiFailure.quota, cause: error, stackTrace: stack));
    } on TimeoutException catch (error, stack) {
      return Result.error(AiException(AiFailure.network, cause: error, stackTrace: stack));
    } on SocketException catch (error, stack) {
      return Result.error(AiException(AiFailure.network, cause: error, stackTrace: stack));
    } on http.ClientException catch (error, stack) {
      return Result.error(AiException(AiFailure.network, cause: error, stackTrace: stack));
    } on FirebaseAIException catch (error, stack) {
      return Result.error(AiException(AiFailure.other, cause: error, stackTrace: stack));
    } catch (error, stack) {
      return Result.error(AiException(AiFailure.other, cause: error, stackTrace: stack));
    }
  }

  /// The photo picker sends JPEG; a PNG (a screenshot from the gallery) is told apart by its signature.
  static String mimeTypeOf(Uint8List bytes) {
    final isPng = bytes.length >= 4 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4e && bytes[3] == 0x47;
    return isPng ? 'image/png' : 'image/jpeg';
  }
}
