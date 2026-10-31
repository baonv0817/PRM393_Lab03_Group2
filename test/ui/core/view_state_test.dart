import 'package:breakbite/ui/core/view_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('empty list becomes ViewEmpty, non-empty list becomes ViewData', () {
    expect(ViewStateX.fromList<int>([]), isA<ViewEmpty<List<int>>>());
    final s = ViewStateX.fromList<int>([1, 2]);
    expect(s, isA<ViewData<List<int>>>());
    expect(s.dataOrNull, [1, 2]);
  });

  test('isLoading and dataOrNull', () {
    expect(const ViewLoading<int>().isLoading, isTrue);
    expect(const ViewError<int>('lỗi').dataOrNull, isNull);
  });
}
