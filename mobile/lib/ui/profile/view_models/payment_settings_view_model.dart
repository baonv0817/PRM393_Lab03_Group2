import 'dart:async';

import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:flutter/foundation.dart';

class PaymentSettingsViewModel extends ChangeNotifier with SafeChangeNotifier {
  PaymentSettingsViewModel({required this.users, required this.crash, required this.uid}) {
    save = Command0(_save);
    load();
  }

  static const fallback = PaymentMethod.momo;

  final UserRepository users;
  final CrashService crash;
  final String uid;

  late final Command0<PaymentMethod> save;

  StreamSubscription<UserProfile>? _sub;
  ViewState<PaymentMethod?> _saved = const ViewLoading();
  PaymentMethod? _chosen;

  ViewState<PaymentMethod?> get saved => _saved;
  PaymentMethod get chosen => _chosen ?? _saved.dataOrNull ?? fallback;
  bool get hasChanges => _saved is ViewData<PaymentMethod?> && chosen != _saved.dataOrNull;

  void load() {
    unawaited(_sub?.cancel());
    _saved = const ViewLoading();
    notifyListeners();
    _sub = users
        .watchProfile(uid)
        .listen(
          (profile) {
            _saved = ViewData(profile.defaultPaymentMethod);
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            crash.recordNonFatal(error, stack, 'paymentSettings.watchProfile');
            _saved = ViewError(error is AppException ? error.message : 'Không tải được cài đặt thanh toán.');
            notifyListeners();
          },
        );
  }

  void choose(PaymentMethod method) {
    _chosen = method;
    notifyListeners();
  }

  Future<Result<PaymentMethod>> _save() async {
    final method = chosen;
    final result = await users.setDefaultPaymentMethod(uid, method);
    switch (result) {
      case Ok():
        return Result.ok(method);
      case Err(:final error):
        crash.recordNonFatal(error, error.stackTrace, 'paymentSettings.save');
        return Result.error(error);
    }
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    save.dispose();
    super.dispose();
  }
}
