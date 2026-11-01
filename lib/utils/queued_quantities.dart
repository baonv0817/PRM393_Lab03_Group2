import 'dart:async';

import 'package:breakbite/utils/result.dart';

class QueuedQuantities {
  QueuedQuantities({required this._write, required this._onChanged});

  final Future<Result<void>> Function(String id, int quantity) _write;
  final void Function() _onChanged;
  final _desired = <String, int>{};
  final _writes = <String, Future<void>>{};
  final _written = <String, int>{};

  int? pendingOf(String id) => _desired[id];

  Future<Result<void>> set(String id, int quantity) {
    _desired[id] = quantity;
    _onChanged();
    final done = Completer<Result<void>>();
    final write = (_writes[id] ?? Future<void>.value()).then((_) async {
      final target = _desired[id];
      if (target == null || target == _written[id]) {
        done.complete(const Result.ok(null));
        return;
      }
      final result = await _write(id, target);
      if (result is Ok<void>) _written[id] = target;
      if (result is Err<void>) {
        _desired.remove(id);
        _onChanged();
      }
      done.complete(result);
    });
    _writes[id] = write;
    unawaited(
      write.whenComplete(() {
        if (identical(_writes[id], write)) {
          _writes.remove(id);
          _written.remove(id);
          _settleOne(id);
        }
      }),
    );
    return done.future;
  }

  int Function(String id) _stored = (_) => 0;

  void settle(int Function(String id) storedOf) {
    _stored = storedOf;
    for (final id in _desired.keys.toList()) {
      if (!_writes.containsKey(id)) _settleOne(id);
    }
  }

  void _settleOne(String id) {
    if (_desired[id] == _stored(id)) {
      _desired.remove(id);
      _onChanged();
    }
  }
}
