import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/theme/app_theme.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/ui/core/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
  theme: AppTheme.light(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('AppButton is at least 48 dp tall and calls onPressed', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(AppButton(label: 'Xác nhận', onPressed: () => taps++)));
    expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
    await tester.tap(find.byType(FilledButton));
    expect(taps, 1);
  });

  testWidgets('AppButton cannot be tapped while loading', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(AppButton(label: 'Xác nhận', loading: true, onPressed: () => taps++)));
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('AppIconButton has a 48 × 48 touch target', (tester) async {
    await tester.pumpWidget(host(AppIconButton(icon: Icons.add, semanticLabel: 'Thêm', onPressed: () {})));
    final size = tester.getSize(find.byType(IconButton));
    expect(size.width, greaterThanOrEqualTo(48));
    expect(size.height, greaterThanOrEqualTo(48));
  });

  testWidgets('ViewStateView renders error with a retry button', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      host(
        ViewStateView<int>(
          state: const ViewError('Mất mạng'),
          onRetry: () => retried = true,
          builder: (_, d) => Text('$d'),
        ),
      ),
    );
    expect(find.text('Mất mạng'), findsOneWidget);
    await tester.tap(find.text('Thử lại'));
    expect(retried, isTrue);
  });

  testWidgets('ViewStateView renders loading, empty and data', (tester) async {
    Future<void> show(ViewState<int> s) =>
        tester.pumpWidget(host(ViewStateView<int>(state: s, onRetry: () {}, builder: (_, d) => Text('dữ liệu $d'))));
    await show(const ViewLoading());
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await show(const ViewEmpty('Trống'));
    expect(find.text('Trống'), findsOneWidget);
    await show(const ViewData(7));
    expect(find.text('dữ liệu 7'), findsOneWidget);
  });

  testWidgets('sold-out FoodCard shows Tạm hết and no add button', (tester) async {
    const item = MenuItem(
      id: 'x',
      name: 'Tacos',
      priceVnd: 35000,
      category: ItemCategory.food,
      prepMinutes: 4,
      soldOut: true,
    );
    await tester.pumpWidget(host(FoodCard(item: item, onTap: () {}, onAdd: null)));
    expect(find.text('Tạm hết'), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
    expect(find.text('35.000đ'), findsOneWidget);
  });
}
