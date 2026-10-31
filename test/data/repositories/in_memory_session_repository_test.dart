import 'package:breakbite/data/repositories/local/in_memory_session_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('emits the current kiosk first, then each change once', () async {
    final session = InMemorySessionRepository(selectedKioskId: 'q9-t2');
    final seen = <String?>[];
    final sub = session.watchSelectedKioskId().listen(seen.add);
    await Future<void>.delayed(Duration.zero);

    await session.selectKiosk('q9-t4');
    await session.selectKiosk('q9-t4');
    await session.clear();
    await Future<void>.delayed(Duration.zero);

    expect(seen, ['q9-t2', 'q9-t4', null]);
    expect(session.selectedKioskId, isNull);
    await sub.cancel();
    await session.dispose();
  });
}
