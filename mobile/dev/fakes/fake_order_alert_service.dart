import 'package:breakbite_core/data/services/services.dart';

/// Remembers what staff would have been told, in order.
class FakeOrderAlertService implements OrderAlertService {
  final alerts = <({int count, String? orderCode})>[];

  @override
  Future<void> newOrders({required int count, String? orderCode}) async =>
      alerts.add((count: count, orderCode: orderCode));
}
