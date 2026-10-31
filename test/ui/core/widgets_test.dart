import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/theme/app_theme.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(theme: AppTheme.light(), home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('AppButton cao ≥ 48 dp và gọi onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(AppButton(label: 'Xác nhận', onPressed: () => taps++)));
    expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
    await tester.tap(find.byType(FilledButton));
    expect(taps, 1);
  });

  testWidgets('AppButton đang tải thì không bấm được', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(AppButton(label: 'Xác nhận', loading: true, onPressed: () => taps++)));
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AppIconButton có vùng chạm 48 × 48', (tester) async {
    await tester.pumpWidget(host(AppIconButton(icon: Icons.add, semanticLabel: 'Thêm', onPressed: () {})));
    final size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('ViewStateView vẽ error kèm nút thử lại', (tester) async {
    var retried = false;
    await tester.pumpWidget(host(ViewStateView<int>(
      state: const ViewError('Mất mạng'),
      onRetry: () => retried = true,
      builder: (_, d) => Text('$d'),
    )));
    expect(find.text('Mất mạng'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    expect(retried, isTrue);
  });

  testWidgets('ViewStateView vẽ loading, empty và data', (tester) async {
    Future<void> show(ViewState<int> s) =>
        tester.pumpWidget(host(ViewStateView<int>(state: s, onRetry: () {}, builder: (_, d) => Text('dữ liệu $d'))));
    await show(const ViewLoading());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await show(const ViewEmpty('Trống'));
    expect(find.text('Trống'), findsOneWidget);
    await show(const ViewData(7));
    expect(find.text('dữ liệu 7'), findsOneWidget);
  });

  testWidgets('FoodCard hết hàng hiện Tạm hết, không có nút thêm', (tester) async {
    const item = MenuItem(id: 'x', name: 'Tacos', priceVnd: 35000, category: 'Tacos', prepMinutes: 4, soldOut: true);
    await tester.pumpWidget(host(FoodCard(item: item, onTap: () {}, onAdd: null)));
    expect(find.text('Tạm hết'), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
    expect(find.text('35.000đ'), findsOneWidget);
  });
}
