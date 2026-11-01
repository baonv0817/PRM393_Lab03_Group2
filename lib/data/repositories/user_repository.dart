import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/result.dart';

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
