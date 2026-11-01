import 'package:breakbite/utils/text.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('searchKey removes Vietnamese diacritics and lowercases like the seed script', () {
    expect(searchKey('Combo Tacos Bò Phô Mai'), 'combo tacos bo pho mai');
    expect(searchKey('Trà Đào Chanh Sả'), 'tra dao chanh sa');
    expect(searchKey('Bánh Mì Chả Lụa Trứng'), 'banh mi cha lua trung');
    expect(searchKey('  Cà Phê Sữa Đá '), 'ca phe sua da');
    expect(searchKey('Ỳ ỷ ỹ ỵ Ý'), 'y y y y y');
  });

  test('slugify builds the dishId used in menu item ids', () {
    expect(slugify('Combo Tacos Bò Phô Mai'), 'combo-tacos-bo-pho-mai');
    expect(slugify('  Mì Trộn — Gà Cay!! '), 'mi-tron-ga-cay');
    expect(slugify('!!!'), '');
  });
}
