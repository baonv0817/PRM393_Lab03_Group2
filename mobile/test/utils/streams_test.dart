import 'dart:async';

import 'package:breakbite_core/utils/streams.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('switchMap follows only the stream of the latest value', () async {
    final source = StreamController<String>();
    final inner = {'a': StreamController<int>(), 'b': StreamController<int>()};
    final seen = <int>[];
    final sub = source.stream.switchMap((key) => inner[key]!.stream).listen(seen.add);

    source.add('a');
    await pumpEventQueue();
    inner['a']!.add(1);
    await pumpEventQueue();
    source.add('b');
    await pumpEventQueue();
    inner['b']!.add(2);
    await pumpEventQueue();

    expect(seen, [1, 2]);
    expect(inner['a']!.hasListener, isFalse);
    expect(inner['b']!.hasListener, isTrue);
    await sub.cancel();
    expect(inner['b']!.hasListener, isFalse);
    await source.close();
  });

  test('switchMap forwards errors of the inner stream', () async {
    final errors = <Object>[];
    final sub = Stream.value(1)
        .switchMap((_) => Stream<int>.error(StateError('boom')))
        .listen(null, onError: errors.add);
    await pumpEventQueue();
    expect(errors.single, isA<StateError>());
    await sub.cancel();
  });

  test('switchMap closes once the source and the last inner stream are done', () async {
    final values = await Stream.fromIterable([1, 2]).switchMap((n) => Stream.value(n * 10)).toList();
    expect(values.last, 20);
  });
}
