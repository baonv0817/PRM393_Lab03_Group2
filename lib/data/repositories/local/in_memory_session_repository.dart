import 'dart:async';

import 'package:breakbite/data/repositories/session_repository.dart';
import 'package:breakbite/utils/result.dart';

/// [SessionRepository] kept in memory for the life of the app. Used by the real app and by tests;
/// persisting the choice (`users/{uid}.defaultKioskId`, DB-09) can wrap this class later.
class InMemorySessionRepository implements SessionRepository {
  InMemorySessionRepository({String? selectedKioskId}) : _selected = selectedKioskId;

  final _changes = StreamController<String?>.broadcast();
  String? _selected;

  @override
  String? get selectedKioskId => _selected;

  @override
  Stream<String?> watchSelectedKioskId() async* {
    yield _selected;
    yield* _changes.stream;
  }

  @override
  Future<Result<void>> selectKiosk(String kioskId) async {
    if (kioskId != _selected) {
      _selected = kioskId;
      _changes.add(kioskId);
    }
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> clear() async {
    if (_selected != null) {
      _selected = null;
      _changes.add(null);
    }
    return const Result.ok(null);
  }

  Future<void> dispose() => _changes.close();
}
