import 'dart:async';

import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/data/repositories/menu_repository.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:breakbite_core/utils/text.dart';
import 'package:flutter/foundation.dart';

/// A01: the accounts of the app. An admin finds one by name or email, and gives it a role: user, staff of a kiosk,
/// or admin. Nobody can change their own role (an admin would be able to lock themselves out), and a staff member
/// always has a kiosk.
class AdminUsersViewModel extends ChangeNotifier with SafeChangeNotifier {
  AdminUsersViewModel({required this.users, required this.menu, required this.selfUid}) {
    setAccess = Command1(_setAccess);
    load();
  }

  static const selfMessage = 'Bạn không đổi được vai trò của chính mình. Nhờ một admin khác làm giúp.';
  static const emptyMessage = 'Chưa có tài khoản nào.';
  static const noMatchMessage = 'Không có tài khoản nào khớp.';

  final AdminUserRepository users;
  final MenuRepository menu;

  /// The admin who is looking at the page.
  final String selfUid;

  late final Command1<void, AccessChange> setAccess;
  StreamSubscription<List<AppUser>>? _usersSub;
  StreamSubscription<List<Kiosk>>? _kioskSub;
  ViewState<List<AppUser>> _state = const ViewLoading();
  List<Kiosk> _kiosks = const [];
  String _query = '';
  UserRole? _role;

  ViewState<List<AppUser>> get state => _state;
  List<Kiosk> get kiosks => _kiosks;
  String get query => _query;

  /// The role the list is filtered to, or `null` for every role.
  UserRole? get roleFilter => _role;

  /// The accounts that match the search and the role filter.
  List<AppUser> get visible {
    final all = _state.dataOrNull ?? const <AppUser>[];
    final needle = searchKey(_query.trim());
    return [
      for (final user in all)
        if ((_role == null || user.role == _role) &&
            (needle.isEmpty || searchKey('${user.displayName} ${user.email ?? ''}').contains(needle)))
          user,
    ];
  }

  /// True when more accounts exist than the list holds.
  bool get truncated => (_state.dataOrNull?.length ?? 0) >= AdminUserRepository.maxUsers;

  int countOf(UserRole role) => (_state.dataOrNull ?? const <AppUser>[]).where((u) => u.role == role).length;

  bool isSelf(AppUser user) => user.uid == selfUid;

  String kioskName(String? id) => id == null ? '' : _kiosks.where((k) => k.id == id).firstOrNull?.name ?? id;

  void load() {
    unawaited(_usersSub?.cancel());
    unawaited(_kioskSub?.cancel());
    _state = const ViewLoading();
    notifyListeners();
    _usersSub = users.watchUsers().listen(
      (list) {
        _state = list.isEmpty ? const ViewEmpty(emptyMessage) : ViewData(list);
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        _state = ViewError(error is AppException ? error.message : 'Không tải được danh sách tài khoản.');
        notifyListeners();
      },
    );
    // The kiosk names are an extra: a failure leaves the ids.
    _kioskSub = menu.watchKiosks().listen((list) {
      _kiosks = list;
      notifyListeners();
    }, onError: (Object e, StackTrace s) {});
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void setRoleFilter(UserRole? value) {
    _role = value;
    notifyListeners();
  }

  /// Why [change] cannot be saved, or `null`.
  String? problemOf(AccessChange change) {
    if (change.uid == selfUid) return selfMessage;
    if (change.role == UserRole.staff && (change.kioskId ?? '').isEmpty) return 'Chọn kiosk cho nhân viên.';
    return null;
  }

  Future<Result<void>> _setAccess(AccessChange change) async {
    final problem = problemOf(change);
    if (problem != null) return Result.error(ValidationException(problem));
    return users.setAccess(change.uid, role: change.role, kioskId: change.kioskId);
  }

  @override
  void dispose() {
    unawaited(_usersSub?.cancel());
    unawaited(_kioskSub?.cancel());
    setAccess.dispose();
    super.dispose();
  }
}

/// The role (and kiosk) an admin chose for an account.
class AccessChange {
  const AccessChange({required this.uid, required this.role, this.kioskId});

  final String uid;
  final UserRole role;
  final String? kioskId;
}
