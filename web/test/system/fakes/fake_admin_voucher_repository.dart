import 'package:breakbite_core/data/repositories/admin/admin_repositories.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/utils/result.dart';

import '../live_value.dart';
import 'fake_audit_log.dart';

class FakeAdminVoucherRepository implements AdminVoucherRepository {
  FakeAdminVoucherRepository(this.audit, {List<Voucher>? vouchers}) : _vouchers = LiveValue(vouchers ?? _seed());

  static List<Voucher> _seed() => [
    Voucher(
      code: 'BBSTUDENT',
      title: 'Giảm 10K cho sinh viên',
      discount: const FixedDiscount(10000),
      minOrderVnd: 40000,
      expiresAt: DateTime.utc(2100),
    ),
    Voucher(
      code: 'GOLDEN15',
      title: 'Giờ vàng -15%',
      discount: const PercentDiscount(percent: 15, maxVnd: 15000),
      expiresAt: DateTime.utc(2100),
      activeFrom: '10:15',
      activeTo: '10:30',
    ),
    Voucher(
      code: 'OLD2020',
      title: 'Đã hết hạn',
      discount: const FixedDiscount(5000),
      expiresAt: DateTime.utc(2020, 12, 31),
    ),
  ];

  final FakeAuditLog audit;
  final LiveValue<List<Voucher>> _vouchers;
  AppException? failNext;

  List<Voucher> get vouchers => _vouchers.value;

  Voucher byCode(String code) => vouchers.firstWhere((v) => v.code == code);

  @override
  Stream<List<Voucher>> watchAll() => _vouchers.stream;

  @override
  Future<Result<void>> save(Voucher voucher, {required bool isNew}) async {
    if (failNext case final error?) {
      failNext = null;
      return Result.error(error);
    }
    final problem = VoucherRules.problemOf(voucher, isNew: isNew);
    if (problem != null) return Result.error(ValidationException(problem));
    final index = vouchers.indexWhere((v) => v.code == voucher.code);
    if (isNew && index >= 0) return Result.error(ValidationException('Mã ${voucher.code} đã có.'));
    if (!isNew && index < 0) return const Result.error(NotFoundException(message: 'Không tìm thấy mã này.'));
    if (isNew) {
      _vouchers.set([...vouchers, voucher]);
    } else {
      _vouchers.set([...vouchers]..[index] = voucher);
    }
    audit.record(AuditAction.voucherSave, 'vouchers/${voucher.code}', '${isNew ? 'Thêm' : 'Sửa'} mã ${voucher.code}');
    return const Result.ok(null);
  }

  @override
  Future<Result<void>> setActive(String code, bool active) async {
    if (failNext case final error?) {
      failNext = null;
      return Result.error(error);
    }
    final index = vouchers.indexWhere((v) => v.code == code);
    if (index < 0) return const Result.error(NotFoundException(message: 'Không tìm thấy mã này.'));
    final old = vouchers[index];
    _vouchers.set(
      [...vouchers]
        ..[index] = Voucher(
          code: old.code,
          title: old.title,
          discount: old.discount,
          minOrderVnd: old.minOrderVnd,
          startsAt: old.startsAt,
          expiresAt: old.expiresAt,
          activeFrom: old.activeFrom,
          activeTo: old.activeTo,
          active: active,
        ),
    );
    audit.record(AuditAction.voucherSave, 'vouchers/$code', '${active ? 'Bật' : 'Tắt'} mã $code');
    return const Result.ok(null);
  }
}
