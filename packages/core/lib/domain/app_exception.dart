/// Every failure a repository or service reports. [message] is Vietnamese text that can be shown
/// to the user as is; [cause] keeps the original error for Crashlytics.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause, this.stackTrace});

  final String message;
  final Object? cause;
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $message${cause == null ? '' : ' ($cause)'}';
}

/// No connection, or the request timed out.
final class NetworkException extends AppException {
  const NetworkException({
    String message = 'Không có kết nối mạng. Thử lại khi có mạng.',
    super.cause,
    super.stackTrace,
  }) : super(message);
}

/// The user stopped the action (for example closed the Google account picker). Not an error to log.
final class CancelledException extends AppException {
  const CancelledException({String message = 'Bạn đã huỷ thao tác.', super.cause, super.stackTrace}) : super(message);
}

/// The backend refused the action (security rules, wrong role).
final class PermissionDeniedException extends AppException {
  const PermissionDeniedException({
    String message = 'Bạn không có quyền thực hiện thao tác này.',
    super.cause,
    super.stackTrace,
  }) : super(message);
}

/// The requested document does not exist (for example a wrong voucher code).
final class NotFoundException extends AppException {
  const NotFoundException({String message = 'Không tìm thấy dữ liệu.', super.cause, super.stackTrace}) : super(message);
}

/// The input is not acceptable (file too large, empty field, expired voucher).
final class ValidationException extends AppException {
  const ValidationException(super.message, {super.cause, super.stackTrace});
}

/// Any other failure of a remote service. Always worth logging to Crashlytics.
final class ServiceException extends AppException {
  const ServiceException({String message = 'Có lỗi xảy ra. Thử lại sau.', super.cause, super.stackTrace})
    : super(message);
}
