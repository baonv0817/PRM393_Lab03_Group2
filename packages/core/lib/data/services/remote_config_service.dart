abstract final class RemoteKeys {
  static const quickItemsLimit = 'quick_items_limit';
  static const promoBannerEnabled = 'promo_banner_enabled';
  static const pickupSlotEnabled = 'pickup_slot_enabled';

  /// The Gemini feature of K14 (docs/ai-feature.md): on/off, which model, and the instructions it gets.
  static const aiEnabled = 'ai_enabled';
  static const aiModel = 'ai_model';
  static const aiPrompt = 'ai_prompt';

  /// The instructions of the web admin's statistics summary; on/off and the model are the keys above.
  static const aiInsightPrompt = 'ai_insight_prompt';

  /// The reasons the web admin's review queue (W03) offers when staff reject an order, separated by `|`.
  static const rejectReasons = 'reject_reasons';
  static const defaultRejectReasons = 'Hết nguyên liệu|Quầy sắp đóng cửa|Quá tải, không kịp làm|Đơn trùng';

  /// [raw] split on `|`, trimmed, without empty or repeated entries; [defaultRejectReasons] when nothing is left.
  static List<String> reasonsFrom(String raw) {
    final reasons = raw.split('|').map((r) => r.trim()).where((r) => r.isNotEmpty).toSet().toList();
    return reasons.isEmpty ? defaultRejectReasons.split('|') : reasons;
  }

  static const defaultAiModel = 'gemini-3.5-flash-lite';
  static const defaultAiPrompt =
      'Bạn là trợ lý nhập món cho quầy ăn trong trường đại học ở Việt Nam. Nhìn ảnh và điền thông tin cho một '
      'món đang bán. Nếu ảnh không phải đồ ăn hoặc đồ uống, đặt isFood = false và để trống các trường khác. '
      'Tên món ngắn gọn bằng tiếng Việt, tối đa 40 ký tự. Giá gợi ý theo mức giá căng tin sinh viên, đơn vị '
      'đồng, làm tròn đến 1.000. Thời gian chuẩn bị tính bằng phút. Mô tả một câu, tối đa 120 ký tự, không '
      'nhắc đến người trong ảnh.';

  static const defaultAiInsightPrompt =
      'Bạn là trợ lý phân tích bán hàng cho quản trị viên hệ thống căng tin trong trường đại học ở Việt Nam. '
      'Bạn nhận số liệu của một khoảng thời gian. Viết bằng tiếng Việt, đúng 3 đến 4 gạch đầu dòng ngắn: điều '
      'đáng chú ý nhất, điều đáng lo (nếu có), và một việc nên làm. Chỉ dùng số trong dữ liệu, không bịa số, '
      'không nhắc tên khách. Nếu số đơn quá ít để kết luận thì nói rõ.';

  static const defaults = <String, Object>{
    quickItemsLimit: 5,
    promoBannerEnabled: true,
    pickupSlotEnabled: true,
    // Off in the app until the console turns it on, so a build never calls Gemini by surprise.
    aiEnabled: false,
    aiModel: defaultAiModel,
    aiPrompt: defaultAiPrompt,
    aiInsightPrompt: defaultAiInsightPrompt,
    rejectReasons: defaultRejectReasons,
  };
}

enum RemoteValueSource { inApp, console }

abstract interface class RemoteConfigService {
  Future<void> fetchAndActivate();

  Stream<Set<String>> watchUpdates();

  int getInt(String key);

  bool getBool(String key);

  /// The value as text; the in-app default when the console has none or it is empty.
  String getString(String key);

  RemoteValueSource sourceOf(String key);

  DateTime? get lastFetchedAt;
}
