import 'dart:async';

import 'package:breakbite/domain/models/models.dart';

/// Passes the menu of a kiosk on with every sold-out item that is due back already on sale (`MenuItem.availableAt`),
/// and sends the menu again at the moment the next one is due, so S02 and S03 change at "có lại lúc 10:30" without
/// waiting for a change in the database.
Stream<List<MenuItem>> withReturns(Stream<List<MenuItem>> source, {DateTime Function()? clock}) {
  final now = clock ?? DateTime.now;
  late final StreamController<List<MenuItem>> controller;
  StreamSubscription<List<MenuItem>>? subscription;
  Timer? timer;
  var latest = const <MenuItem>[];

  void emit() {
    timer?.cancel();
    final at = now();
    controller.add([for (final item in latest) item.availableAt(at)]);
    final next = MenuItem.nextReturn(latest, at);
    if (next != null) {
      // Looked at again at least every 6 hours, and a moment after the time so the clock is surely past it.
      final wait = next.difference(at) + const Duration(milliseconds: 100);
      timer = Timer(wait > const Duration(hours: 6) ? const Duration(hours: 6) : wait, emit);
    }
  }

  controller = StreamController<List<MenuItem>>(
    onListen: () {
      subscription = source.listen(
        (items) {
          latest = items;
          emit();
        },
        onError: controller.addError,
        onDone: controller.close,
      );
    },
    onCancel: () {
      timer?.cancel();
      return subscription?.cancel();
    },
  );
  return controller.stream;
}
