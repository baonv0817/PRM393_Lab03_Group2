import 'package:flutter/foundation.dart';

/// Mix into every view model. An async call that finishes after the user left the screen would
/// otherwise call `notifyListeners()` on a disposed notifier and throw.
mixin SafeChangeNotifier on ChangeNotifier {
  bool _disposed = false;

  bool get isDisposed => _disposed;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
