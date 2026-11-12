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

class StudentInfoViewModel extends ChangeNotifier with SafeChangeNotifier {
  StudentInfoViewModel({required this.users, required this.menu, required this.crash, required this.uid}) {
    save = Command0(_save);
    load();
  }

  final UserRepository users;
  final MenuRepository menu;
  final CrashService crash;
  final String uid;

  late final Command0<void> save;

  StreamSubscription<UserProfile>? _profileSub;
  StreamSubscription<List<Kiosk>>? _kioskSub;

  ViewState<UserProfile> _profile = const ViewLoading();
  List<Kiosk> _kiosks = const [];
  String _name = '';
  String _studentId = '';
  String _phone = '';
  String? _defaultKioskId;
  bool _showErrors = false;
  UserProfile? _saved;

  ViewState<UserProfile> get profile => _profile;
  List<Kiosk> get kiosks => _kiosks;
  String get name => _name;
  String get studentId => _studentId;
  String get phone => _phone;
  String? get defaultKioskId => _kiosks.any((k) => k.id == _defaultKioskId) ? _defaultKioskId : null;

  String? get nameError => _showErrors ? UserProfile.nameProblem(_name) : null;
  String? get studentIdError => _showErrors ? UserProfile.studentIdProblem(_studentId) : null;
  String? get phoneError => _showErrors ? UserProfile.phoneProblem(_phone) : null;

  bool get hasChanges {
    final saved = _saved;
    if (saved == null) return false;
    return UserProfile.normalizeName(_name) != saved.displayName ||
        UserProfile.normalizeStudentId(_studentId) != (saved.studentId ?? '') ||
        UserProfile.normalizePhone(_phone) != (saved.phone ?? '') ||
        defaultKioskId != saved.defaultKioskId;
  }

  void load() {
    unawaited(_profileSub?.cancel());
    unawaited(_kioskSub?.cancel());
    _profile = const ViewLoading();
    notifyListeners();
    _profileSub = users
        .watchProfile(uid)
        .listen(
          (value) {
            final first = _saved == null;
            _saved = value;
            if (first) {
              _name = value.displayName;
              _studentId = value.studentId ?? '';
              _phone = value.phone ?? '';
              _defaultKioskId = value.defaultKioskId;
            }
            _profile = ViewData(value);
            notifyListeners();
          },
          onError: (Object error, StackTrace stack) {
            crash.recordNonFatal(error, stack, 'studentInfo.watchProfile');
            _profile = ViewError(error is AppException ? error.message : 'Không tải được hồ sơ.');
            notifyListeners();
          },
        );
    _kioskSub = menu.watchKiosks().listen((value) {
      _kiosks = value;
      notifyListeners();
    }, onError: (Object error, StackTrace stack) => crash.recordNonFatal(error, stack, 'studentInfo.watchKiosks'));
  }

  void setName(String value) => _update(() => _name = value);

  void setStudentId(String value) => _update(() => _studentId = value);

  void setPhone(String value) => _update(() => _phone = value);

  void setDefaultKiosk(String? kioskId) => _update(() => _defaultKioskId = kioskId);

  void _update(VoidCallback change) {
    change();
    notifyListeners();
  }

  Future<Result<void>> _save() async {
    _showErrors = true;
    notifyListeners();
    if (nameError != null || studentIdError != null || phoneError != null) {
      return const Result.error(ValidationException('Kiểm tra lại các ô báo lỗi.'));
    }
    final result = await users.saveProfile(
      uid,
      displayName: _name,
      studentId: _studentId,
      phone: _phone,
      defaultKioskId: defaultKioskId,
    );
    if (result case Err(:final error) when error is! ValidationException) {
      crash.recordNonFatal(error, error.stackTrace, 'studentInfo.save');
    }
    return result;
  }

  @override
  void dispose() {
    unawaited(_profileSub?.cancel());
    unawaited(_kioskSub?.cancel());
    save.dispose();
    super.dispose();
  }
}
