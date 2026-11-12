import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

MenuItemSuggestion _ok(String? text) => (MenuItemSuggestion.parse(text) as Ok<MenuItemSuggestion>).value;

AiFailure _failure(String? text) => ((MenuItemSuggestion.parse(text) as Err).error as AiException).reason;

void main() {
  group('MenuItemSuggestion.parse (the JSON Gemini returns for K14)', () {
    test('a full answer becomes the model the form uses', () {
      final suggestion = _ok(
        '{"isFood": true, "name": "Bánh mì thịt nướng", "category": "food", "priceVnd": 25000, '
        '"prepMinutes": 5, "description": "Bánh mì giòn kẹp thịt nướng."}',
      );
      expect(suggestion.name, 'Bánh mì thịt nướng');
      expect(suggestion.category, ItemCategory.food);
      expect(suggestion.priceVnd, 25000);
      expect(suggestion.prepMinutes, 5);
      expect(suggestion.description, 'Bánh mì giòn kẹp thịt nướng.');
    });

    test('the price is rounded to 1 000 đ and the time kept between 1 and 120 minutes', () {
      final suggestion = _ok('{"name": "Trà đào", "category": "drink", "priceVnd": 18400, "prepMinutes": 300}');
      expect(suggestion.priceVnd, 18000);
      expect(suggestion.prepMinutes, MenuItemSuggestion.maxPrepMinutes);
    });

    test('a missing or unusable price, time and description leave those fields to staff', () {
      final suggestion = _ok('{"name": "Cơm gà", "priceVnd": -5000, "prepMinutes": "nhanh"}');
      expect(suggestion.priceVnd, isNull);
      expect(suggestion.prepMinutes, isNull);
      expect(suggestion.description, isEmpty);
      expect(suggestion.category, ItemCategory.other, reason: 'no kind given');
    });

    test('a kind the form does not have becomes "Khác"', () {
      expect(_ok('{"name": "Bánh flan", "category": "dessert"}').category, ItemCategory.other);
    });

    test('a long name and description are cut to the limits of the form', () {
      final suggestion = _ok('{"name": "${'Phở ' * 30}", "description": "${'ngon ' * 60}"}');
      expect(suggestion.name.length, lessThanOrEqualTo(MenuItemSuggestion.maxNameLength));
      expect(suggestion.description.length, lessThanOrEqualTo(MenuItemSuggestion.maxDescriptionLength));
    });

    test('a JSON answer wrapped in a ```json fence is still read', () {
      expect(_ok('```json\n{"name": "Mì trộn bò", "category": "food"}\n```').name, 'Mì trộn bò');
    });

    test('a photo that is not food or drink is refused with its own reason', () {
      expect(_failure('{"isFood": false}'), AiFailure.notFood);
    });

    test('an answer that is not the expected JSON is "unreadable", never a crash', () {
      expect(_failure('Xin lỗi, tôi không thấy món nào.'), AiFailure.badOutput);
      expect(_failure('[1, 2, 3]'), AiFailure.badOutput);
      expect(_failure(null), AiFailure.badOutput);
      expect(_failure('{"isFood": true, "name": "   "}'), AiFailure.badOutput, reason: 'no dish name');
    });

    test('every failure carries a message that tells staff they can type the item by hand', () {
      for (final reason in AiFailure.values) {
        expect(AiException(reason).message, isNotEmpty);
        expect(reason.analyticsName, matches(RegExp(r'^[a-z_]+$')), reason: 'snake_case for Analytics');
      }
    });
  });
}
