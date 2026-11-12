import 'dart:typed_data';

import 'package:breakbite_core/domain/models/menu_item_suggestion.dart';
import 'package:breakbite_core/utils/result.dart';

/// The Gemini feature of K14 (docs/ai-feature.md): proposes the fields of a new item from a photo of the dish.
///
/// Only the photo and the prompt are sent: no name, e-mail or account data. Failures come back as an
/// `AiException` (quota, network, not food, unreadable answer), never as a crash, so the form stays usable by hand.
abstract interface class MenuAiService {
  /// [model] and [prompt] come from Remote Config (`ai_model`, `ai_prompt`), so they change without a new build.
  Future<Result<MenuItemSuggestion>> suggestFromPhoto(Uint8List photo, {required String model, required String prompt});
}
