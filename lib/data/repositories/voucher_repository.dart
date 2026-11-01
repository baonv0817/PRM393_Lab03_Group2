import 'package:breakbite/domain/models/voucher.dart';

abstract interface class VoucherRepository {
  Stream<List<Voucher>> watchActiveVouchers();
}
