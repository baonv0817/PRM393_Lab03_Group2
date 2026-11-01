import 'dart:async';

extension SwitchMapStream<T> on Stream<T> {
  Stream<R> switchMap<R>(Stream<R> Function(T value) project) {
    StreamSubscription<T>? outer;
    StreamSubscription<R>? inner;
    var outerDone = false;
    late final StreamController<R> controller;
    controller = StreamController<R>(
      onListen: () {
        outer = listen(
          (value) {
            final previous = inner;
            inner = null;
            if (previous != null) unawaited(previous.cancel());
            inner = project(value).listen(
              controller.add,
              onError: controller.addError,
              onDone: () {
                inner = null;
                if (outerDone) unawaited(controller.close());
              },
            );
          },
          onError: controller.addError,
          onDone: () {
            outerDone = true;
            if (inner == null) unawaited(controller.close());
          },
        );
      },
      onPause: () {
        outer?.pause();
        inner?.pause();
      },
      onResume: () {
        outer?.resume();
        inner?.resume();
      },
      onCancel: () async {
        await inner?.cancel();
        await outer?.cancel();
      },
    );
    return controller.stream;
  }
}
