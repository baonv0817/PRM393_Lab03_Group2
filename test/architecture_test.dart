import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _dartFiles(String dir) =>
    Directory(dir).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart')).toList();

String _path(File f) => f.path.replaceAll(r'\', '/');

List<String> _imports(File f) => RegExp(
  r"^\s*(?:import|export)\s+'([^']+)'",
  multiLine: true,
).allMatches(f.readAsStringSync()).map((m) => m.group(1)!).toList();

List<String> _violations(Iterable<File> files, bool Function(String import) forbidden) => [
  for (final f in files)
    for (final i in _imports(f))
      if (forbidden(i)) '${_path(f)} imports $i',
];

const _sdkPackages = ['package:firebase_', 'package:cloud_firestore', 'package:google_sign_in', 'package:http/'];

void main() {
  test('screens, view models, routing and models never import an SDK; only lib/data and lib/config do', () {
    final files = [..._dartFiles('lib/ui'), ..._dartFiles('lib/routing'), ..._dartFiles('lib/domain')];
    expect(_violations(files, (i) => _sdkPackages.any(i.startsWith)), isEmpty);
  });

  test('lib never imports dev/, so the submitted build has no fake data', () {
    expect(_violations(_dartFiles('lib'), (i) => i.contains('dev/') && !i.startsWith('package:breakbite/')), isEmpty);
  });

  test('domain models are plain Dart and do not import Flutter', () {
    expect(_violations(_dartFiles('lib/domain'), (i) => i.startsWith('package:flutter')), isEmpty);
  });

  test('view models depend on foundation only, never on widgets', () {
    final viewModels = _dartFiles('lib/ui').where((f) => _path(f).contains('/view_models/'));
    expect(
      _violations(viewModels, (i) => i.startsWith('package:flutter/') && i != 'package:flutter/foundation.dart'),
      isEmpty,
    );
  });

  test('view models never import screens or widgets of the UI layer', () {
    final viewModels = _dartFiles('lib/ui').where((f) => _path(f).contains('/view_models/'));
    expect(_violations(viewModels, (i) => i.contains('/widgets/')), isEmpty);
  });

  test('every view model mixes in SafeChangeNotifier', () {
    final missing = [
      for (final f in _dartFiles('lib/ui').where((f) => _path(f).contains('/view_models/')))
        if (f.readAsStringSync().contains('extends ChangeNotifier') &&
            !f.readAsStringSync().contains('with SafeChangeNotifier'))
          _path(f),
    ];
    expect(missing, isEmpty);
  });

  test('feature screens take colours and text styles from the theme, not literals', () {
    final screens = _dartFiles('lib/ui').where((f) => !_path(f).startsWith('lib/ui/core/'));
    final literal = RegExp(r'Color\(0x|\bColors\.(?!transparent)|\bTextStyle\(|fontFamily:');
    final found = [
      for (final f in screens)
        for (final (n, line) in f.readAsLinesSync().indexed)
          if (literal.hasMatch(line)) '${_path(f)}:${n + 1}: ${line.trim()}',
    ];
    expect(found, isEmpty);
  });
}
