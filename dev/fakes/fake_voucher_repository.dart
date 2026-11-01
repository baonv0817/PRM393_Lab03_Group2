import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/domain/models/models.dart';

import 'live_value.dart';

final fakeVouchers = [
  Voucher(
    code: 'BBSTUDENT',
    title: 'Giảm 10K cho sinh viên',
    discount: const FixedDiscount(10000),
    expiresAt: DateTime(2100),
    minOrderVnd: 40000,
  ),
  Voucher(
    code: 'GIOVANG',
    title: 'Combo Giờ Vàng giảm 15%, tối đa 15K',
    discount: const PercentDiscount(percent: 15, maxVnd: 15000),
    expiresAt: DateTime(2100),
    minOrderVnd: 30000,
    activeFrom: '10:15',
    activeTo: '10:30',
  ),
  Voucher(code: 'BB20', title: 'Giảm 20K', discount: const FixedDiscount(20000), expiresAt: DateTime(2020)),
];

class FakeVoucherRepository implements VoucherRepository {
  FakeVoucherRepository({List<Voucher>? vouchers}) : _vouchers = LiveValue(vouchers ?? fakeVouchers);

  final LiveValue<List<Voucher>> _vouchers;

  @override
  Stream<List<Voucher>> watchActiveVouchers() =>
      _vouchers.stream.map((all) => all.where((v) => v.active).toList()..sort((a, b) => a.code.compareTo(b.code)));
}
