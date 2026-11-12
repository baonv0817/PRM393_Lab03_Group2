import 'package:breakbite_core/data/services/crash_service.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';

void main() {
  test('recordNonFatal sends the underlying cause and skips actions the user cancelled', () async {
    final crash = FakeCrashService();
    final cause = StateError('socket closed');
    crash
      ..recordNonFatal(NetworkException(cause: cause), null, 'x')
      ..recordNonFatal(const CancelledException(), null, 'y')
      ..recordNonFatal(ArgumentError('bad'), StackTrace.current, 'z');
    await pumpEventQueue();
    expect(crash.errors, [cause, isA<ArgumentError>()]);
  });
}
