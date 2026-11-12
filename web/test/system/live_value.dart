import 'dart:async';

/// In-memory value that replays to new listeners (like a Firestore snapshot).
class LiveValue<T> {
  LiveValue(this._value);

  T _value;
  final _controller = StreamController<T>.broadcast();

  T get value => _value;

  Stream<T> get stream async* {
    yield _value;
    yield* _controller.stream;
  }

  void set(T v) {
    _value = v;
    _controller.add(v);
  }
}
