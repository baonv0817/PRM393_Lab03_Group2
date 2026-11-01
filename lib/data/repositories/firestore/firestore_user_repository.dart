import 'package:breakbite/data/firebase/firebase_errors.dart';
import 'package:breakbite/data/firebase/firestore_helpers.dart';
import 'package:breakbite/data/repositories/firestore/firestore_mappers.dart';
import 'package:breakbite/data/repositories/user_repository.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

class FirestoreUserRepository implements UserRepository {
  FirestoreUserRepository(this._db);

  final FirebaseFirestore _db;

  DocumentReference<Json> _user(String uid) => _db.collection('users').doc(uid);

  @override
  Stream<UserProfile> watchProfile(String uid) =>
      guardStream(_user(uid).snapshots().map((snapshot) => userProfileFromData(uid, snapshot.data())));

  @override
  Future<Result<void>> saveProfile(
    String uid, {
    required String displayName,
    String? studentId,
    String? phone,
    String? defaultKioskId,
  }) => guard(() async {
    if (uid.isEmpty) throw const PermissionDeniedException();
    final problem =
        UserProfile.nameProblem(displayName) ??
        UserProfile.studentIdProblem(studentId ?? '') ??
        UserProfile.phoneProblem(phone ?? '');
    if (problem != null) throw ValidationException(problem);
    Object valueOrDelete(String? value) => value == null || value.isEmpty ? FieldValue.delete() : value;
    await _user(uid).update({
      'displayName': UserProfile.normalizeName(displayName),
      'studentId': valueOrDelete(studentId == null ? null : UserProfile.normalizeStudentId(studentId)),
      'phone': valueOrDelete(phone == null ? null : UserProfile.normalizePhone(phone)),
      'defaultKioskId': valueOrDelete(defaultKioskId),
      ...Stamp.updated(),
    });
  });

  @override
  Future<Result<void>> setDefaultPaymentMethod(String uid, PaymentMethod method) => guard(() async {
    if (uid.isEmpty) throw const PermissionDeniedException();
    await _user(uid).update({'defaultPaymentMethod': method.name, ...Stamp.updated()});
  });
}
