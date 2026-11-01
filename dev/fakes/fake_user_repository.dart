import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';

import 'live_value.dart';

class FakeUserRepository implements UserRepository {
  final _profiles = <String, LiveValue<UserProfile>>{};
  AppException? failNextWrite;
  int saves = 0;

  LiveValue<UserProfile> _of(String uid) => _profiles.putIfAbsent(
    uid,
    () => LiveValue(UserProfile(uid: uid, displayName: 'Minh Quân', email: 'quan@fpt.edu.vn')),
  );

  UserProfile profileOf(String uid) => _of(uid).value;

  @override
  Stream<UserProfile> watchProfile(String uid) => _of(uid).stream;

  @override
  Future<Result<void>> saveProfile(
    String uid, {
    required String displayName,
    String? studentId,
    String? phone,
    String? defaultKioskId,
  }) async {
    if (failNextWrite case final error?) {
      failNextWrite = null;
      return Result.error(error);
    }
    final problem =
        UserProfile.nameProblem(displayName) ??
        UserProfile.studentIdProblem(studentId ?? '') ??
        UserProfile.phoneProblem(phone ?? '');
    if (problem != null) return Result.error(ValidationException(problem));
    final current = _of(uid).value;
    String? orNull(String? value) => value == null || value.isEmpty ? null : value;
    saves++;
    _of(uid).set(
      UserProfile(
        uid: uid,
        displayName: UserProfile.normalizeName(displayName),
        email: current.email,
        studentId: orNull(studentId == null ? null : UserProfile.normalizeStudentId(studentId)),
        phone: orNull(phone == null ? null : UserProfile.normalizePhone(phone)),
        defaultKioskId: orNull(defaultKioskId),
        defaultPaymentMethod: current.defaultPaymentMethod,
      ),
    );
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> setDefaultPaymentMethod(String uid, PaymentMethod method) async {
    if (failNextWrite case final error?) {
      failNextWrite = null;
      return Result.error(error);
    }
    final c = _of(uid).value;
    saves++;
    _of(uid).set(
      UserProfile(
        uid: uid,
        displayName: c.displayName,
        email: c.email,
        studentId: c.studentId,
        phone: c.phone,
        defaultKioskId: c.defaultKioskId,
        defaultPaymentMethod: method,
      ),
    );
    return const Result.ok(null);
  }
}
