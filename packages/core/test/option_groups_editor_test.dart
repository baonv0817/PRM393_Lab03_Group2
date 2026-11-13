import 'package:breakbite_core/domain/models/option_group.dart';
import 'package:breakbite_core/ui/core/theme/app_theme.dart';
import 'package:breakbite_core/ui/core/widgets/option_groups_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder byId(String id) => find.bySemanticsIdentifier(id);

/// Holds the list the way a form does, so the editor can be used as it is in the apps.
class _Host extends StatefulWidget {
  const _Host({required this.initial, required this.onChanged});

  final List<OptionGroup> initial;
  final ValueChanged<List<OptionGroup>> onChanged;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late List<OptionGroup> groups = widget.initial;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SingleChildScrollView(
      child: OptionGroupsEditor(
        groups: groups,
        problem: optionGroupsProblem(groups),
        onChanged: (g) {
          setState(() => groups = g);
          widget.onChanged(g);
        },
      ),
    ),
  );
}

Future<void> _pump(WidgetTester tester, List<OptionGroup> initial, ValueChanged<List<OptionGroup>> onChanged) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(600, 1600);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: _Host(initial: initial, onChanged: onChanged),
    ),
  );
}

void main() {
  testWidgets('starts empty, and a preset adds the usual group with its prices', (tester) async {
    var groups = <OptionGroup>[];
    await _pump(tester, const [], (g) => groups = g);
    expect(find.text('Tuỳ chọn (size, topping…)'), findsOneWidget);
    await tester.tap(byId('options.preset.0'));
    await tester.pumpAndSettle();
    expect(groups.single.name, 'Size');
    expect(groups.single.required, isTrue);
    expect(groups.single.choices.map((c) => c.extraVnd), [0, 5000, 10000]);
    expect(optionGroupsProblem(groups), isNull);
  });

  testWidgets('a blank group is added, named, given choices and prices, and says what is missing meanwhile', (
    tester,
  ) async {
    var groups = <OptionGroup>[];
    await _pump(tester, const [], (g) => groups = g);
    await tester.tap(byId('options.add'));
    await tester.pumpAndSettle();
    expect(find.textContaining('cần có tên'), findsOneWidget, reason: 'a new group is not ready to save');

    await tester.enterText(
      find.descendant(of: byId('options.group.0.name'), matching: find.byType(TextField)),
      'Topping',
    );
    await tester.enterText(
      find.descendant(of: byId('options.group.0.choice.0.name'), matching: find.byType(TextField)),
      'Trân châu',
    );
    await tester.enterText(
      find.descendant(of: byId('options.group.0.choice.0.extra'), matching: find.byType(TextField)),
      '5000',
    );
    await tester.pumpAndSettle();
    expect(groups.single.name, 'Topping');
    expect(groups.single.choices.single.name, 'Trân châu');
    expect(groups.single.choices.single.extraVnd, 5000);
    expect(optionGroupsProblem(groups), isNull);

    await tester.tap(byId('options.group.0.addChoice'));
    await tester.pumpAndSettle();
    expect(groups.single.choices, hasLength(2));
    await tester.tap(byId('options.group.0.required'));
    await tester.pumpAndSettle();
    expect(groups.single.required, isTrue);
    await tester.tap(byId('options.group.0.multiple'));
    await tester.pumpAndSettle();
    expect(groups.single.maxChoices, 2, reason: 'two choices to pick from, so up to two can be picked');
  });

  testWidgets('removing a group or a choice, and the five-group limit', (tester) async {
    var groups = <OptionGroup>[
      for (var i = 0; i < 5; i++)
        OptionGroup(
          id: 'g$i',
          name: 'Nhóm $i',
          choices: const [
            OptionChoice(id: 'a', name: 'A'),
            OptionChoice(id: 'b', name: 'B'),
          ],
        ),
    ];
    await _pump(tester, groups, (g) => groups = g);
    final add = tester.widget<OutlinedButton>(
      find.descendant(of: byId('options.add'), matching: find.byType(OutlinedButton)),
    );
    expect(add.onPressed, isNull, reason: 'five groups is the most an item takes');

    await tester.tap(find.byTooltip('Xoá lựa chọn B').first);
    await tester.pumpAndSettle();
    expect(groups.first.choices.map((c) => c.name), ['A']);
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close).first).onPressed,
      isNull,
      reason: 'the last choice of a group stays',
    );
    await tester.tap(find.byTooltip('Xoá nhóm Nhóm 0'));
    await tester.pumpAndSettle();
    expect(groups, hasLength(4));
  });
}
