import 'package:breakbite/ui/offline/view_models/connectivity_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../dev/fakes/fakes.dart';

void main() {
  group('ConnectivityViewModel (S30)', () {
    test('shows the offline screen only while the phone is offline', () async {
      final network = FakeConnectivityService();
      final vm = ConnectivityViewModel(connectivity: network, crash: FakeCrashService());
      await pumpEventQueue();
      expect(vm.showOffline, isFalse);

      network.online = false;
      await pumpEventQueue();
      expect((vm.online, vm.showOffline), (false, true));
      network.online = true;
      await pumpEventQueue();
      expect(vm.showOffline, isFalse);
    });

    test('"Xem giỏ hàng" hides it until the connection changes again', () async {
      final network = FakeConnectivityService(online: false);
      final vm = ConnectivityViewModel(connectivity: network, crash: FakeCrashService());
      await pumpEventQueue();
      expect(vm.showOffline, isTrue);

      vm.dismiss();
      expect(vm.showOffline, isFalse);
      network.online = true;
      await pumpEventQueue();
      network.online = false;
      await pumpEventQueue();
      expect(vm.showOffline, isTrue, reason: 'a new loss of connection is news again');
    });

    test('"Thử lại" asks again and leaves the screen when the phone is back online', () async {
      final network = FakeConnectivityService(online: false);
      final vm = ConnectivityViewModel(connectivity: network, crash: FakeCrashService());
      await pumpEventQueue();

      await vm.retry();
      expect((vm.online, vm.checking), (false, false), reason: 'still offline');
      network.online = true;
      await vm.retry();
      expect(vm.online, isTrue);
    });
  });
}
