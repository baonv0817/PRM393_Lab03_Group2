import 'dart:async';

/// Giá trị trong bộ nhớ phát lại cho người nghe mới (giống snapshot Firestore).
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
