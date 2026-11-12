import 'package:flutter/widgets.dart';

/// Gives [child] a stable id in the accessibility tree. On Android it becomes the view's
/// `resource-id`, which ARTEMIS and widget tests (`find.bySemanticsIdentifier`) can target without
/// depending on Vietnamese text or layout.
///
/// Format: `<screen>.<element>` or `<screen>.<element>.<itemId>`, lower camel case parts, for example
/// `s02.search`, `s02.add.m1`, `k02.accept.A-204`. Build ids for repeated items from data ids.
class TestId extends StatelessWidget {
  const TestId(this.id, {super.key, required this.child});

  static final _format = RegExp(r'^[a-z][a-z0-9-]*(\.[A-Za-z0-9-]+)+$');

  final String id;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    assert(_format.hasMatch(id), 'TestId "$id" must look like s02.add or s02.add.m1');
    return Semantics(container: true, identifier: id, child: child);
  }
}
