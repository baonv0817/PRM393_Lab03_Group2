import 'package:breakbite_core/data/services/connectivity_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// [ConnectivityService] on `connectivity_plus`: offline when the phone reports no connection at all.
class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService([Connectivity? connectivity]) : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  static bool _online(List<ConnectivityResult> results) =>
      results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);

  @override
  Stream<bool> watchOnline() async* {
    yield _online(await _connectivity.checkConnectivity());
    yield* _connectivity.onConnectivityChanged.map(_online);
  }

  @override
  Future<bool> check() async => _online(await _connectivity.checkConnectivity());
}
