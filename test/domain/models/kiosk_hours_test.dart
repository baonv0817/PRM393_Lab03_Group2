import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/utils/format.dart';
import 'package:flutter_test/flutter_test.dart';

Kiosk _kiosk({String? from, String? to, bool open = true, DateTime? pausedUntil}) => Kiosk(
  id: 'q9-t2',
  name: 'Kiosk Q9',
  open: open,
  waitMinutes: 5,
  openTime: from,
  closeTime: to,
  pausedUntil: pausedUntil,
);

DateTime _at(int hour, [int minute = 0]) => DateTime(2026, 11, 11, hour, minute);

void main() {
  group('Kiosk opening hours', () {
    test('orders are taken from the opening time up to, not including, the closing time', () {
      final kiosk = _kiosk(from: '06:30', to: '17:00');
      expect(kiosk.acceptsOrders(_at(6, 29)), isFalse);
      expect(kiosk.acceptsOrders(_at(6, 30)), isTrue);
      expect(kiosk.acceptsOrders(_at(12)), isTrue);
      expect(kiosk.acceptsOrders(_at(16, 59)), isTrue);
      expect(kiosk.acceptsOrders(_at(17)), isFalse);
      expect(kiosk.acceptsOrders(_at(23)), isFalse);
    });

    test('without both times, or with the same time twice, there are no hours to keep', () {
      expect(_kiosk().acceptsOrders(_at(3)), isTrue);
      expect(_kiosk(from: '06:30').acceptsOrders(_at(3)), isTrue);
      expect(_kiosk(to: '17:00').acceptsOrders(_at(23)), isTrue);
      expect(_kiosk(from: '00:00', to: '00:00').acceptsOrders(_at(3)), isTrue);
    });

    test('closing before opening means the hours run past midnight', () {
      final night = _kiosk(from: '18:00', to: '02:00');
      expect(night.acceptsOrders(_at(17, 59)), isFalse);
      expect(night.acceptsOrders(_at(18)), isTrue);
      expect(night.acceptsOrders(_at(23, 30)), isTrue);
      expect(night.acceptsOrders(_at(1, 59)), isTrue);
      expect(night.acceptsOrders(_at(2)), isFalse);
    });

    test('the switch and a pause still close a kiosk that is within its hours', () {
      final inside = _at(10);
      expect(_kiosk(from: '06:30', to: '17:00', open: false).acceptsOrders(inside), isFalse);
      final paused = _kiosk(from: '06:30', to: '17:00', pausedUntil: _at(10, 30));
      expect(paused.acceptsOrders(inside), isFalse);
      expect(paused.acceptsOrders(_at(10, 31)), isTrue, reason: 'the pause is over');
    });

    test('a time that is not a clock time is ignored rather than closing the kiosk', () {
      expect(_kiosk(from: '6:30', to: '17:00').acceptsOrders(_at(3)), isTrue);
    });

    test('the status says it is outside the hours and when it opens again', () {
      final kiosk = _kiosk(from: '06:30', to: '17:00');
      expect(kioskStatusLabel(kiosk, now: _at(20)), 'Ngoài giờ mở cửa · mở lại 06:30');
      expect(kioskStatusLabel(kiosk, now: _at(10)), startsWith('Mở · chờ'));
      expect(
        kioskStatusLabel(
          _kiosk(from: '06:30', to: '17:00', open: false),
          now: _at(10),
        ),
        'Đóng · mở lại 06:30',
      );
    });
  });
}
