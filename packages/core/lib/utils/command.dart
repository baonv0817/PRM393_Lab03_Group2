import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

/// A user action of a view model (place an order, accept an order, sign in) with its own state:
/// [running] while it works, then [result]. A second tap while it runs is ignored, so double taps
/// cannot place two orders. Screens disable the button while [running] and react to [result].
///
/// Pattern from the official Flutter architecture guide.
sealed class Command<T> extends ChangeNotifier with SafeChangeNotifier {
  Command();

  bool _running = false;
  Result<T>? _result;

  bool get running => _running;

  /// Outcome of the last run; `null` before the first run and while running.
  Result<T>? get result => _result;

  bool get completed => _result is Ok<T>;

  bool get failed => _result is Err<T>;

  /// Forget the last outcome, for example after its snackbar was shown.
  void clearResult() {
    _result = null;
    notifyListeners();
  }

  Future<Result<T>?> _run(Future<Result<T>> Function() action) async {
    if (_running) return null;
    _running = true;
    _result = null;
    notifyListeners();
    try {
      final result = await action();
      _result = result;
      return result;
    } finally {
      _running = false;
      notifyListeners();
    }
  }
}

/// A [Command] without an argument.
final class Command0<T> extends Command<T> {
  Command0(this._action);

  final Future<Result<T>> Function() _action;

  /// Runs the action and returns its result, or `null` when it was already running.
  Future<Result<T>?> execute() => _run(_action);
}

/// A [Command] with one argument.
final class Command1<T, A> extends Command<T> {
  Command1(this._action);

  final Future<Result<T>> Function(A argument) _action;

  /// Runs the action and returns its result, or `null` when it was already running.
  Future<Result<T>?> execute(A argument) => _run(() => _action(argument));
}
