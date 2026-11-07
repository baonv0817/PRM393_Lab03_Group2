/// Whether the phone has a network (S30). Having one does not promise that the server answers, but having none
/// means every request will fail, so the app says so at once.
abstract interface class ConnectivityService {
  /// The state now, and again every time it changes.
  Stream<bool> watchOnline();

  /// Asks again, for the "Thử lại" button.
  Future<bool> check();
}
