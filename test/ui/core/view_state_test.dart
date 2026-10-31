import 'package:breakbite/ui/core/view_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('danh sách rỗng thành ViewEmpty, có phần tử thành ViewData', () {
    expect(ViewStateX.fromList<int>([]), isA<ViewEmpty<List<int>>>());
    final s = ViewStateX.fromList<int>([1, 2]);
    expect(s, isA<ViewData<List<int>>>());
    expect(s.dataOrNull, [1, 2]);
  });

  test('isLoading và dataOrNull', () {
    expect(const ViewLoading<int>().isLoading, isTrue);
    expect(const ViewError<int>('lỗi').dataOrNull, isNull);
  });
}
