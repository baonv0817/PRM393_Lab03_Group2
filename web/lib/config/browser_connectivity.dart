import 'dart:async';
import 'dart:js_interop';

import 'package:breakbite_core/data/services/connectivity_service.dart';
import 'package:web/web.dart' as web;

/// Whether the browser has a network, from `navigator.onLine` and the window's `online` / `offline` events.
///
/// Firestore on the web keeps listening while offline and answers from its cache, which is empty after a page load:
/// without this a screen would say "Kiosk chưa có món nào" when the truth is "there is no network". The shell
/// shows the offline error state instead (AdminSession.online).
class BrowserConnectivityService implements ConnectivityService {
  @override
  Stream<bool> watchOnline() {
    late final StreamController<bool> controller;
    final onOnline = ((web.Event _) => controller.add(true)).toJS;
    final onOffline = ((web.Event _) => controller.add(false)).toJS;
    controller = StreamController<bool>(
      onListen: () {
        controller.add(web.window.navigator.onLine);
        web.window.addEventListener('online', onOnline);
        web.window.addEventListener('offline', onOffline);
      },
      onCancel: () async {
        web.window.removeEventListener('online', onOnline);
        web.window.removeEventListener('offline', onOffline);
        await controller.close();
      },
    );
    return controller.stream;
  }

  @override
  Future<bool> check() async => web.window.navigator.onLine;
}
