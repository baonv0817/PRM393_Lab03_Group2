import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';

abstract interface class UserRepository {
  Stream<UserProfile> watchProfile(String uid);

  Future<Result<void>> saveProfile(
    String uid, {
    required String displayName,
    String? studentId,
    String? phone,
    String? defaultKioskId,
  });

  Future<Result<void>> setDefaultPaymentMethod(String uid, PaymentMethod method);
}
