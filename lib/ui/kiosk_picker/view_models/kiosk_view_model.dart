import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/utils/command.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:breakbite/utils/text.dart';
import 'package:flutter/foundation.dart';

class KioskViewModel extends ChangeNotifier with SafeChangeNotifier {
  KioskViewModel({
    required this.menu,
    required this.session,
    required this.cart,
    required this.crash,
    required this.uid,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _chosenId = session.selectedKioskId {
    confirm = Command0(_confirm);
    load();
  }

  final MenuRepository menu;
  final SessionRepository session;
  final CartRepository cart;
  final CrashService crash;
  final String uid;
  final DateTime Function() _clock;

  late final Command0<Kiosk> confirm;

  StreamSubscription<List<Kiosk>>? _kioskSub;
  StreamSubscription<Cart>? _cartSub;

  List<Kiosk>? _all;
  String? _error;
  String _query = '';
  String? _chosenId;
  Cart _cart = Cart.empty;

  String get query => _query;
  String? get chosenId => _chosenId;
  DateTime get now => _clock();

  ViewState<List<Kiosk>> get kiosks {
    if (_error case final message?) return ViewError(message);
    final all = _all;
    if (all == null) return const ViewLoading();
    if (all.isEmpty) return const ViewEmpty('Chưa có kiosk nào.');
    final key = searchKey(_query.trim());
    final shown = key.isEmpty
        ? all
        : all.where((k) => searchKey(k.name).contains(key) || searchKey(k.location).contains(key)).toList();
    return shown.isEmpty ? ViewEmpty('Không có kiosk nào khớp "${_query.trim()}".') : ViewData(shown);
  }

  Kiosk? get chosen => _all?.where((k) => k.id == _chosenId).firstOrNull;

  Kiosk? get cartKiosk => _cart.isEmpty ? null : _all?.where((k) => k.id == _cart.kioskId).firstOrNull;

  bool get choiceEmptiesCart => !_cart.isEmpty && _chosenId != null && _cart.kioskId != _chosenId;

  bool get canConfirm => chosen != null && !confirm.running;

  void load() {
    unawaited(_kioskSub?.cancel());
    unawaited(_cartSub?.cancel());
    _error = null;
    _all = null;
    notifyListeners();
    _kioskSub = menu.watchKiosks().listen(
      (kiosks) {
        _all = kiosks;
        _error = null;
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        _log(error, stack, 'kiosks.watchKiosks');
        _error = error is AppException ? error.message : 'Không tải được danh sách kiosk.';
        notifyListeners();
      },
    );
    if (uid.isEmpty) return;
    _cartSub = cart.watchCart(uid).listen((value) {
      _cart = value;
      notifyListeners();
    }, onError: (Object error, StackTrace stack) => _log(error, stack, 'kiosks.watchCart'));
  }

  void search(String text) {
    _query = text;
    notifyListeners();
  }

  void choose(String kioskId) {
    if (_chosenId == kioskId) return;
    _chosenId = kioskId;
    notifyListeners();
  }

  Future<Result<Kiosk>> _confirm() async {
    final kiosk = chosen;
    if (kiosk == null) return const Result.error(ValidationException('Chọn một kiosk trước.'));
    if (choiceEmptiesCart) {
      final cleared = await cart.clear(uid);
      if (cleared case Err(:final error)) {
        _log(error, error.stackTrace ?? StackTrace.current, 'kiosks.clearCart');
        return Result.error(error);
      }
    }
    final selected = await session.selectKiosk(kiosk.id);
    if (selected case Err(:final error)) return Result.error(error);
    return Result.ok(kiosk);
  }

  void _log(Object error, StackTrace stack, String reason) {
    if (error is CancelledException) return;
    unawaited(crash.recordError(error is AppException ? error.cause ?? error : error, stack, reason: reason));
  }

  @override
  void dispose() {
    unawaited(_kioskSub?.cancel());
    unawaited(_cartSub?.cancel());
    confirm.dispose();
    super.dispose();
  }
}
