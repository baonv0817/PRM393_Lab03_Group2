import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The same MVVM rules as mobile/test/architecture_test.dart, for the web admin.
List<File> _dartFiles(String dir) =>
    Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

String _path(File f) => f.path.replaceAll(r'\', '/');

List<String> _imports(File f) => RegExp(
  r"^\s*(?:import|export)\s+'([^']+)'",
  multiLine: true,
).allMatches(f.readAsStringSync()).map((m) => m.group(1)!).toList();

const _sdkPackages = ['package:firebase_', 'package:cloud_firestore', 'package:google_sign_in', 'package:http/'];

void main() {
  final ui = _dartFiles('lib/ui');
  final viewModels = ui.where((f) => _path(f).contains('/view_models/'));

  test('screens and view models never import an SDK; only lib/config does', () {
    final bad = [
      for (final f in [...ui, ..._dartFiles('lib/routing')])
        for (final i in _imports(f))
          if (_sdkPackages.any(i.startsWith)) '${_path(f)} imports $i',
    ];
    expect(bad, isEmpty);
  });

  test('models and repositories come from the shared package, not from the web app', () {
    expect(Directory('lib/domain').existsSync(), isFalse);
    expect(Directory('lib/data').existsSync(), isFalse);
  });

  test('view models depend on foundation only and never on widgets', () {
    final bad = [
      for (final f in viewModels)
        for (final i in _imports(f))
          if ((i.startsWith('package:flutter/') && i != 'package:flutter/foundation.dart') || i.contains('/widgets/'))
            '${_path(f)} imports $i',
    ];
    expect(bad, isEmpty);
  });

  test('every view model mixes in SafeChangeNotifier', () {
    final missing = [
      for (final f in viewModels)
        if (f.readAsStringSync().contains('extends ChangeNotifier') &&
            !f.readAsStringSync().contains('with SafeChangeNotifier'))
          _path(f),
    ];
    expect(missing, isEmpty);
  });

  test('screens take colours and text styles from the Lab 2 theme, not literals', () {
    final literal = RegExp(r'Color\(0x|\bColors\.(?!transparent)|\bTextStyle\(|fontFamily:');
    final found = [
      for (final f in ui)
        for (final (n, line) in f.readAsLinesSync().indexed)
          if (literal.hasMatch(line)) '${_path(f)}:${n + 1}: ${line.trim()}',
    ];
    expect(found, isEmpty);
  });
}
