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

/// Why the AI could not fill the K14 form (docs/ai-feature.md). Its [analyticsName] is the `reason` of `ai_error`.
enum AiFailure {
  disabled('disabled'),
  quota('quota'),
  network('network'),
  notFood('not_food'),
  badOutput('bad_output'),
  other('other');

  const AiFailure(this.analyticsName);

  final String analyticsName;
}

/// The Gemini feature could not help this time. The form still works by hand, so the message always says so.
final class AiException extends AppException {
  AiException(this.reason, {super.cause, super.stackTrace}) : super(_messageFor(reason));

  /// For the statistics summary, where the page keeps working and nobody types anything by hand.
  AiException.insight(this.reason, {super.cause, super.stackTrace}) : super(_insightMessageFor(reason));

  final AiFailure reason;

  static String _insightMessageFor(AiFailure reason) => switch (reason) {
    AiFailure.disabled => 'Tính năng AI đang tắt.',
    AiFailure.quota => 'AI đang quá tải hoặc hết lượt dùng. Thử lại sau ít phút.',
    AiFailure.network => 'Không gọi được AI vì mạng yếu hoặc mất mạng. Biểu đồ bên dưới vẫn đầy đủ.',
    AiFailure.notFood || AiFailure.badOutput => 'AI trả lời không đọc được. Thử tạo lại.',
    AiFailure.other => 'AI đang gặp lỗi. Biểu đồ bên dưới vẫn đầy đủ.',
  };

  static String _messageFor(AiFailure reason) => switch (reason) {
    AiFailure.disabled => 'Tính năng AI đang tắt. Bạn nhập tay giúp nhé.',
    AiFailure.quota => 'AI đang quá tải hoặc hết lượt dùng. Bạn nhập tay giúp nhé.',
    AiFailure.network => 'Không gọi được AI vì mạng yếu hoặc mất mạng. Bạn vẫn nhập tay được.',
    AiFailure.notFood => 'Ảnh này không giống món ăn hay đồ uống. Chụp lại món hoặc nhập tay.',
    AiFailure.badOutput => 'AI trả lời không đọc được. Bạn nhập tay giúp nhé.',
    AiFailure.other => 'AI đang gặp lỗi. Bạn nhập tay giúp nhé.',
  };
}
