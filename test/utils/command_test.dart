import 'dart:async';

import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/utils/command.dart';
import 'package:breakbite/utils/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports running, then keeps the result', () async {
    final gate = Completer<Result<int>>();
    final command = Command0<int>(() => gate.future);
    final states = <bool>[];
    command.addListener(() => states.add(command.running));

    final run = command.execute();
    expect(command.running, isTrue);
    gate.complete(const Result.ok(7));
    expect(await run, isA<Ok<int>>());

    expect(command.running, isFalse);
    expect(command.completed, isTrue);
    expect(command.result?.valueOrNull, 7);
    expect(states, [true, false]);
  });

  test('ignores a second run while the first is still running', () async {
    var calls = 0;
    final gate = Completer<Result<void>>();
    final command = Command1<void, String>((_) {
      calls++;
      return gate.future;
    });

    final first = command.execute('a');
    final second = await command.execute('b');
    gate.complete(const Result.ok(null));
    await first;

    expect(second, isNull);
    expect(calls, 1);
  });

  test('keeps a failure as the result and can clear it', () async {
    final command = Command0<void>(() async => const Result.error(NetworkException()));
    await command.execute();
    expect(command.failed, isTrue);
    expect(command.result?.errorOrNull, isA<NetworkException>());

    command.clearResult();
    expect(command.result, isNull);
  });

  test('finishing after dispose does not throw', () async {
    final gate = Completer<Result<void>>();
    final command = Command0<void>(() => gate.future);
    final run = command.execute();
    command.dispose();
    gate.complete(const Result.ok(null));
    await expectLater(run, completes);
  });
}
