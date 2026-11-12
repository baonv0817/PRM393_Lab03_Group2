import 'dart:convert';

import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/menu_item.dart';
import 'package:breakbite_core/utils/result.dart';

/// What Gemini proposes for the K14 form from a photo of a dish (docs/ai-feature.md). It is only a suggestion:
/// the form fills its fields with it, labels them "Gợi ý từ AI", and staff can change any field before saving.
class MenuItemSuggestion {
  const MenuItemSuggestion({
    required this.name,
    required this.category,
    this.priceVnd,
    this.prepMinutes,
    this.description = '',
  });

  /// The same limits as the K14 form, so a suggestion never puts something in a field that the form refuses.
  static const maxNameLength = 60;
  static const maxDescriptionLength = 200;
  static const maxPriceVnd = 1000000;
  static const maxPrepMinutes = 120;

  final String name;
  final ItemCategory category;

  /// Rounded to 1 000 đ; `null` when the model gave no usable price.
  final int? priceVnd;

  /// Between 1 and [maxPrepMinutes]; `null` when the model gave no usable time.
  final int? prepMinutes;

  final String description;

  /// The JSON keys the model must answer with (the response schema of the request).
  static const isFoodKey = 'isFood';
  static const nameKey = 'name';
  static const categoryKey = 'category';
  static const priceKey = 'priceVnd';
  static const prepKey = 'prepMinutes';
  static const descriptionKey = 'description';

  /// Reads the model's answer. A photo that is not food or drink, and an answer that is not the expected JSON,
  /// come back as an [AiException] so the form can say why and stay usable by hand.
  static Result<MenuItemSuggestion> parse(String? text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(_withoutCodeFence(text ?? ''));
    } on FormatException catch (error, stack) {
      return Result.error(AiException(AiFailure.badOutput, cause: error, stackTrace: stack));
    }
    if (decoded is! Map<String, dynamic>) {
      return Result.error(AiException(AiFailure.badOutput, cause: 'The answer is not a JSON object: $text'));
    }
    if (decoded[isFoodKey] == false) return Result.error(AiException(AiFailure.notFood));
    final name = _clip(decoded[nameKey], maxNameLength);
    if (name.isEmpty) {
      return Result.error(AiException(AiFailure.badOutput, cause: 'The answer has no dish name: $text'));
    }
    return Result.ok(
      MenuItemSuggestion(
        name: name,
        category: ItemCategory.values.asNameMap()[decoded[categoryKey]] ?? ItemCategory.other,
        priceVnd: _price(decoded[priceKey]),
        prepMinutes: _prep(decoded[prepKey]),
        description: _clip(decoded[descriptionKey], maxDescriptionLength),
      ),
    );
  }

  /// Some models wrap JSON in a ```json fence even when asked for JSON only.
  static String _withoutCodeFence(String text) {
    final trimmed = text.trim();
    final fence = RegExp(r'^```(?:json)?\s*([\s\S]*?)\s*```$').firstMatch(trimmed);
    return fence?.group(1) ?? trimmed;
  }

  static String _clip(Object? value, int max) {
    if (value is! String) return '';
    final trimmed = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    return trimmed.length > max ? trimmed.substring(0, max).trimRight() : trimmed;
  }

  static int? _price(Object? value) {
    if (value is! num || !value.isFinite) return null;
    final rounded = (value / 1000).round() * 1000;
    return rounded <= 0 || rounded > maxPriceVnd ? null : rounded;
  }

  static int? _prep(Object? value) {
    if (value is! num || !value.isFinite || value <= 0) return null;
    return value.round().clamp(1, maxPrepMinutes);
  }
}
