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

  testWidgets('the added-to-cart notice closes by itself, so it never covers the next screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showAddedSnackbar(context, message: 'Đã thêm Tacos vào giỏ', onViewCart: () {}),
              child: const Text('add'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('add'));
    await tester.pumpAndSettle();
    expect(find.text('Xem giỏ'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Xem giỏ'), findsNothing);
  });

  group('UserAvatar', () {
    test('the initial is the first letter of the given name, which comes last in Vietnamese names', () {
      expect(UserAvatar.initialOf('Nguyễn Minh Quân'), 'Q');
      expect(UserAvatar.initialOf('  ân  '), 'Â');
      expect(UserAvatar.initialOf(''), '');
    });

    testWidgets('without a photo it shows the initial, without a name a person icon', (tester) async {
      await tester.pumpWidget(host(const UserAvatar(name: 'Nguyễn Minh Quân')));
      expect(find.text('Q'), findsOneWidget);
      await tester.pumpWidget(host(const UserAvatar(name: '', photoUrl: 'http://not-secure')));
      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('a photo that cannot load falls back to the initial', (tester) async {
      await tester.pumpWidget(host(const UserAvatar(name: 'Quân', photoUrl: 'https://example.invalid/a.png')));
      await tester.pumpAndSettle();
      expect(find.text('Q'), findsOneWidget);
    });
  });

  testWidgets('SelectableCard reports its selection to screen readers and reacts to taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        SelectableCard(
          testId: 'x.card',
          selected: true,
          onTap: () => taps++,
          semanticLabel: 'Kiosk A',
          child: const Text('Kiosk A'),
        ),
      ),
    );
    expect(tester.getSemantics(find.bySemanticsIdentifier('x.card')), isSemantics(isSelected: true, label: 'Kiosk A'));
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    await tester.tap(find.text('Kiosk A'));
    expect(taps, 1);
  });

  testWidgets('BottomActionButton spans the width, shows loading and can be disabled', (tester) async {
    await tester.pumpWidget(host(const BottomActionButton(label: 'Lưu', testId: 'x.save', onPressed: null)));
    expect(find.bySemanticsIdentifier('x.save'), findsOneWidget);
    expect(tester.getSize(find.byType(AppButton)).width, greaterThan(700));
  });

  testWidgets('showAppMessage replaces the message on screen instead of queueing', (tester) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showAppMessage(context, 'Một');
              showAppMessage(context, 'Hai');
            },
            child: const Text('go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Hai'), findsOneWidget);
    expect(find.text('Một'), findsNothing);
  });
}
