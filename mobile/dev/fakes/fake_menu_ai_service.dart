import 'dart:async';
import 'dart:typed_data';

import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';

/// Answers without calling Gemini. [next] is what the next [suggestFromPhoto] returns (a bánh mì by default);
/// [calls] records what the app sent, so tests can check that only the photo, the model and the prompt go out.
class FakeMenuAiService implements MenuAiService {
  static const banhMi = MenuItemSuggestion(
    name: 'Bánh mì thịt nướng',
    category: ItemCategory.food,
    priceVnd: 25000,
    prepMinutes: 5,
    description: 'Bánh mì giòn kẹp thịt nướng, đồ chua và rau thơm.',
  );

  Result<MenuItemSuggestion> next = const Result.ok(banhMi);
  final calls = <({Uint8List photo, String model, String prompt})>[];

  /// When set, the answer waits for it: a test can act while Gemini is still "thinking".
  Completer<void>? gate;

  @override
  Future<Result<MenuItemSuggestion>> suggestFromPhoto(
    Uint8List photo, {
    required String model,
    required String prompt,
  }) async {
    calls.add((photo: photo, model: model, prompt: prompt));
    await gate?.future;
    return next;
  }
}
