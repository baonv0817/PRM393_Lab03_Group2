import 'package:breakbite_core/domain/models/voucher.dart';

abstract interface class VoucherRepository {
  Stream<List<Voucher>> watchActiveVouchers();
}
