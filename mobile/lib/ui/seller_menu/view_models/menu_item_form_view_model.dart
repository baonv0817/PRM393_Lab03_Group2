import 'dart:async';

import 'package:breakbite_core/data/repositories/repositories.dart';
import 'package:breakbite_core/data/services/services.dart';
import 'package:breakbite_core/domain/app_exception.dart';
import 'package:breakbite_core/domain/models/models.dart';
import 'package:breakbite_core/ui/core/view_state.dart';
import 'package:breakbite_core/utils/command.dart';
import 'package:breakbite_core/utils/format.dart';
import 'package:breakbite_core/utils/result.dart';
import 'package:breakbite_core/utils/safe_change_notifier.dart';
import 'package:breakbite_core/utils/text.dart';
import 'package:flutter/foundation.dart';

/// A field of the form that the AI can fill (docs/ai-feature.md).
enum AiField { name, category, price, prep, description }

/// K14 (add an item) and K15 (edit one): the same form. The field errors show once the staff member has
/// tried to save (K14-ERR); nothing is written until every field is valid.
///
/// The photo of the item: staff pick one (gallery or camera) and it is shown at once; it goes to Cloudinary
/// when the item is saved, and the link is stored in the item (`imageUrl`), which is what customers see.
///
/// The AI feature (K14 only, docs/ai-feature.md): with a photo chosen, "Điền bằng AI" asks Gemini for the name,
/// kind, price, preparation time and description. The answer fills the fields, each labelled "Gợi ý từ AI" until
/// staff change it; nothing is saved until staff press "Lưu món". Remote Config `ai_enabled` shows or hides the
/// button live; any failure leaves the form as it was and usable by hand.
class MenuItemFormViewModel extends ChangeNotifier with SafeChangeNotifier {
  MenuItemFormViewModel({
    required this.menu,
    required this.storage,
    required this.photos,
    required this.crash,
    required this.ai,
    required this.remoteConfig,
    required this.analytics,
    required this.kioskId,
    this.itemId,
  }) {
    save = Command0(_save);
    suggest = Command0(_suggest)..addListener(notifyListeners);
    _configSub = remoteConfig.watchUpdates().listen((keys) {
      if (keys.contains(RemoteKeys.aiEnabled)) notifyListeners();
    });
    load();
  }

  /// The `feature` parameter of the AI events, so a second AI feature can be told apart in Analytics.
  static const aiFeature = 'k14_photo';

  static const maxNameLength = 60;
  static const maxDescriptionLength = 200;
  static const maxPriceVnd = 1000000;
  static const maxPrepMinutes = 120;
  static const defaultPrepMinutes = 5;

  static const noKioskMessage = 'Tài khoản này chưa được gán kiosk nên chưa thêm hay sửa món được.';
  static const notFoundMessage = 'Không tìm thấy món này.';
  static const waitForAiMessage = 'Đợi AI gợi ý xong rồi lưu món.';
  static const notYoursMessage = 'Món này không thuộc kiosk của bạn.';
  static const invalidMessage = 'Kiểm tra lại các ô báo lỗi.';

  /// The kinds of item, in the order they are offered.
  static const categories = ItemCategory.values;

  final MenuRepository menu;
  final StorageService storage;
  final PhotoPickerService photos;
  final CrashService crash;
  final MenuAiService ai;
  final RemoteConfigService remoteConfig;
  final AnalyticsService analytics;

  /// The kiosk of the staff member; a new item belongs to it.
  final String? kioskId;

  /// The item being edited, `null` when adding a new one.
  final String? itemId;

  bool get isNew => itemId == null;

  /// Saves the item and returns its id.
  late final Command0<String> save;

  /// Asks Gemini to fill the form from the chosen photo.
  late final Command0<MenuItemSuggestion> suggest;

  StreamSubscription<Set<String>>? _configSub;

  /// The fields that still hold what the AI proposed (staff have not changed them).
  final _aiFields = <AiField>{};

  /// Fields staff changed while Gemini was still answering (CR-F01): the answer must not overwrite them.
  final _editedWhileSuggesting = <AiField>{};

  /// How many fields the last suggestion filled; `0` when the AI was not used.
  int _aiFilledCount = 0;

  ViewState<MenuItem?> _state = const ViewLoading();
  MenuItem? _loaded;
  String _name = '';
  String _price = '';
  String _prep = '$defaultPrepMinutes';
  String _description = '';
  ItemCategory _category = ItemCategory.food;

  /// What the "Còn hàng" switch was set to; `null` while it was not touched, so the item keeps the state it has.
  bool? _inStockChoice;
  bool _attempted = false;
  String? _takenSlug;

  PickedPhoto? _picked;
  bool _photoRemoved = false;
  bool _picking = false;
  double? _uploadProgress;

  /// The photo already on Cloudinary for [_picked], so a save that failed later does not upload it again.
  ({PickedPhoto photo, String url})? _uploaded;

  /// `ViewData(null)` is a new item; `ViewData(item)` is the item being edited.
  ViewState<MenuItem?> get state => _state;

  Future<void> load() async {
    final id = kioskId;
    if (id == null || id.isEmpty) {
      _state = const ViewEmpty(noKioskMessage);
      notifyListeners();
      return;
    }
    if (isNew) {
      _state = const ViewData(null);
      notifyListeners();
      return;
    }
    _state = const ViewLoading();
    notifyListeners();
    final result = await menu.getItem(itemId!);
    switch (result) {
      case Ok(:final value) when value.kioskId != id:
        _state = const ViewEmpty(notYoursMessage);
      case Ok(:final value):
        _loaded = value;
        _name = value.name;
        _price = '${value.priceVnd}';
        _prep = '${value.prepMinutes}';
        _description = value.description;
        _category = value.category;
        _state = ViewData(value);
      case Err(error: NotFoundException()):
        _state = const ViewEmpty(notFoundMessage);
      case Err(:final error):
        crash.recordNonFatal(error, error.stackTrace, 'menuItemForm.load');
        _state = ViewError(error.message);
    }
    notifyListeners();
  }

  String get name => _name;
  String get price => _price;
  String get prepMinutes => _prep;
  String get description => _description;
  ItemCategory get category => _category;

  /// The item is on sale: the switch as the staff member left it, or the item's own state.
  bool get inStock => _inStockChoice ?? !(_loaded?.soldOut ?? false);

  /// The preparation time for the stepper; the default while the field holds something that is not a number.
  int get prepMinutesValue => (_prepValue ?? defaultPrepMinutes).clamp(0, maxPrepMinutes);

  /// The photo chosen in this form, not saved yet; shown in place of the item's own photo.
  Uint8List? get pickedPhoto => _picked?.bytes;

  /// The link of the item's photo as it is saved, or `null` when it has none, or it was removed here, or a new
  /// one was chosen (then [pickedPhoto] is what to show).
  String? get photoUrl => _photoRemoved || _picked != null ? null : _loaded?.imageUrl;

  bool get hasPhoto => pickedPhoto != null || (photoUrl != null && photoUrl!.isNotEmpty);

  /// A photo is being opened, the AI is reading it, or the item and its photo are being saved: the photo buttons
  /// wait.
  bool get photoBusy => _picking || _uploadProgress != null || suggest.running;

  /// 0 to 1 while the photo goes to Cloudinary, `null` otherwise.
  double? get uploadProgress => _uploadProgress;

  /// Opens the gallery or the camera. Backing out changes nothing. A refused permission or a device that cannot
  /// do it comes back as an error to show.
  Future<Result<void>> pickPhoto(PhotoSource source) async {
    if (photoBusy) return const Result.ok(null);
    _picking = true;
    notifyListeners();
    try {
      final result = await photos.pick(source);
      switch (result) {
        case Ok(:final value):
          if (value != null) {
            _picked = value;
            _photoRemoved = false;
            // A new photo: what the AI said about the previous one no longer applies.
            if (suggest.failed) suggest.clearResult();
          }
          return const Result.ok(null);
        case Err(:final error):
          if (error is! PermissionDeniedException) {
            crash.recordNonFatal(error, error.stackTrace, 'menuItemForm.pickPhoto');
          }
          return Result.error(error);
      }
    } finally {
      _picking = false;
      notifyListeners();
    }
  }

  /// The feature is switched on in Remote Config (read live: turning it off in the console hides the button).
  bool get aiEnabled => remoteConfig.getBool(RemoteKeys.aiEnabled);

  /// The AI helps add a new item (K14); editing an existing one (K15) keeps what staff wrote.
  bool get aiAvailable => isNew && aiEnabled;

  /// A photo has been chosen in this form and nothing else is running.
  bool get canSuggest => aiAvailable && _picked != null && !photoBusy && !save.running;

  /// The field still holds the AI's suggestion, so the form labels it "Gợi ý từ AI".
  bool isAiSuggested(AiField field) => _aiFields.contains(field);

  /// Some fields still hold the AI's suggestion: the form shows the notice to check them before saving.
  bool get hasAiSuggestion => _aiFields.isNotEmpty;

  /// Why the last "Điền bằng AI" did not work, shown under the button until another photo is chosen or the AI is
  /// asked again; `null` otherwise.
  String? get aiError => switch (suggest.result) {
    Err(:final error) => error.message,
    _ => null,
  };

  Future<Result<MenuItemSuggestion>> _suggest() async {
    final photo = _picked;
    if (!aiEnabled) return Result.error(AiException(AiFailure.disabled));
    if (photo == null) {
      return const Result.error(ValidationException('Chọn hoặc chụp ảnh món trước để AI gợi ý.'));
    }
    final model = remoteConfig.getString(RemoteKeys.aiModel);
    _editedWhileSuggesting.clear();
    unawaited(analytics.logEvent(AnalyticsEvents.aiRequest, {'feature': aiFeature, 'model': model}));
    final result = await ai.suggestFromPhoto(
      photo.bytes,
      model: model,
      prompt: remoteConfig.getString(RemoteKeys.aiPrompt),
    );
    switch (result) {
      case Ok(:final value):
        _apply(value);
      case Err(:final error):
        final reason = error is AiException ? error.reason : AiFailure.other;
        unawaited(
          analytics.logEvent(AnalyticsEvents.aiError, {
            'feature': aiFeature,
            'reason': reason.analyticsName,
            'model': model,
          }),
        );
        // Quota, network and "not food" are expected and shown to staff; the rest is worth a look in Crashlytics.
        if (reason == AiFailure.other || reason == AiFailure.badOutput) {
          crash.recordNonFatal(error, error.stackTrace, 'menuItemForm.suggest');
        }
    }
    return result;
  }

  /// Fills the form from [suggestion]. A field staff typed into while waiting keeps what they typed (CR-F01).
  void _apply(MenuItemSuggestion suggestion) {
    _aiFields.clear();
    bool take(AiField field) => !_editedWhileSuggesting.contains(field);
    if (take(AiField.name)) {
      _name = suggestion.name.length > maxNameLength ? suggestion.name.substring(0, maxNameLength) : suggestion.name;
      _aiFields.add(AiField.name);
    }
    if (take(AiField.category)) {
      _category = suggestion.category;
      _aiFields.add(AiField.category);
    }
    if (suggestion.priceVnd case final price? when take(AiField.price)) {
      _price = '$price';
      _aiFields.add(AiField.price);
    }
    if (suggestion.prepMinutes case final minutes? when take(AiField.prep)) {
      _prep = '${minutes.clamp(0, maxPrepMinutes)}';
      _aiFields.add(AiField.prep);
    }
    if (suggestion.description.isNotEmpty && take(AiField.description)) {
      final text = suggestion.description;
      _description = text.length > maxDescriptionLength ? text.substring(0, maxDescriptionLength) : text;
      _aiFields.add(AiField.description);
    }
    _editedWhileSuggesting.clear();
    _aiFilledCount = _aiFields.length;
    notifyListeners();
  }

  /// Staff changed [field] by hand: it loses its AI label, and an answer still on its way leaves it alone.
  void _edited(AiField field) {
    _aiFields.remove(field);
    if (suggest.running) _editedWhileSuggesting.add(field);
  }

  /// Takes the photo off the item (the logo shows instead). Nothing is deleted from Cloudinary.
  void removePhoto() {
    if (photoBusy || !hasPhoto) return;
    _picked = null;
    _uploaded = null;
    _photoRemoved = true;
    if (suggest.failed) suggest.clearResult();
    notifyListeners();
  }

  void setInStock(bool value) {
    if (value == inStock) return;
    _inStockChoice = value;
    notifyListeners();
  }

  /// The − and + of the preparation time, one minute at a time between 0 and [maxPrepMinutes].
  void changePrepMinutes(int delta) {
    _prep = '${(prepMinutesValue + delta).clamp(0, maxPrepMinutes)}';
    _edited(AiField.prep);
    notifyListeners();
  }

  void setName(String value) {
    _name = value.length > maxNameLength ? value.substring(0, maxNameLength) : value;
    _edited(AiField.name);
    notifyListeners();
  }

  void setPrice(String value) {
    _price = value;
    _edited(AiField.price);
    notifyListeners();
  }

  void setPrepMinutes(String value) {
    _prep = value;
    _edited(AiField.prep);
    notifyListeners();
  }

  void setDescription(String value) {
    _description = value.length > maxDescriptionLength ? value.substring(0, maxDescriptionLength) : value;
    _edited(AiField.description);
    notifyListeners();
  }

  void setCategory(ItemCategory value) {
    if (value == _category) return;
    _category = value;
    _edited(AiField.category);
    notifyListeners();
  }

  int? get _priceValue => int.tryParse(_price.trim());

  int? get _prepValue => int.tryParse(_prep.trim());

  String? get _nameProblem {
    final trimmed = _name.trim();
    if (trimmed.isEmpty) return 'Nhập tên món.';
    final slug = slugify(trimmed);
    if (slug.isEmpty) return 'Tên món cần có chữ hoặc số.';
    if (isNew && slug == _takenSlug) return 'Món này đã có trong thực đơn.';
    return null;
  }

  String? get _priceProblem {
    if (_price.trim().isEmpty) return 'Nhập giá món.';
    final value = _priceValue;
    if (value == null || value <= 0) return 'Giá món phải lớn hơn 0.';
    if (value > maxPriceVnd) return 'Giá món tối đa ${formatVnd(maxPriceVnd)}.';
    return null;
  }

  String? get _prepProblem {
    if (_prep.trim().isEmpty) return 'Nhập thời gian chuẩn bị, tính bằng phút.';
    final value = _prepValue;
    if (value == null || value < 0) return 'Thời gian chuẩn bị không hợp lệ.';
    if (value > maxPrepMinutes) return 'Thời gian chuẩn bị tối đa $maxPrepMinutes phút.';
    return null;
  }

  /// The errors appear once saving has been tried, so an empty form is not shouted at.
  String? get nameError => _attempted ? _nameProblem : null;
  String? get priceError => _attempted ? _priceProblem : null;
  String? get prepError => _attempted ? _prepProblem : null;

  bool get isValid => _nameProblem == null && _priceProblem == null && _prepProblem == null;

  /// Editing: something differs from the saved item. A new item can always be saved (and then checked).
  bool get hasChanges {
    final saved = _loaded;
    if (saved == null) return true;
    return saved.name != _name.trim() ||
        saved.priceVnd != _priceValue ||
        saved.prepMinutes != _prepValue ||
        saved.description != _description.trim() ||
        saved.category != _category ||
        inStock == saved.soldOut ||
        _picked != null ||
        (_photoRemoved && (saved.imageUrl ?? '').isNotEmpty);
  }

  /// Not while Gemini is still answering: the answer would change the form after the item was saved (CR-F01).
  bool get canSave => hasChanges && !suggest.running;

  Future<Result<String>> _save() async {
    if (suggest.running) return const Result.error(ValidationException(waitForAiMessage));
    _attempted = true;
    notifyListeners();
    if (!isValid) return const Result.error(ValidationException(invalidMessage));
    final kiosk = kioskId!;
    final name = _name.trim();
    final description = _description.trim();
    final photo = await _uploadPhoto(kiosk);
    if (photo case Err(:final error)) return Result.error(error);
    final newUrl = photo.valueOrNull;
    final MenuItem item;
    if (isNew) {
      final slug = slugify(name);
      switch (await menu.getItem('$kiosk-$slug')) {
        case Ok():
          _takenSlug = slug;
          notifyListeners();
          return const Result.error(ValidationException('Món này đã có trong thực đơn.'));
        case Err(error: NotFoundException()):
          break;
        case Err(:final error):
          crash.recordNonFatal(error, error.stackTrace, 'menuItemForm.checkName');
          return Result.error(error);
      }
      item = MenuItem(
        id: '',
        name: name,
        priceVnd: _priceValue!,
        category: _category,
        prepMinutes: _prepValue!,
        kioskId: kiosk,
        description: description,
        imageUrl: newUrl,
      ).withSoldOut(!inStock);
    } else {
      // Start from the item as it is now, so a sold-out switch flipped meanwhile in K08 is not undone by this
      // save, unless the "Còn hàng" switch was touched here.
      final current = await menu.getItem(itemId!);
      final base = current.valueOrNull ?? _loaded!;
      final choice = _inStockChoice;
      final changed = MenuItem(
        id: base.id,
        name: name,
        priceVnd: _priceValue!,
        category: _category,
        prepMinutes: _prepValue!,
        dishId: base.dishId,
        soldOut: base.soldOut,
        kioskId: base.kioskId,
        description: description,
        imageUrl: _photoRemoved ? null : (newUrl ?? base.imageUrl),
        availableAgainAt: base.availableAgainAt,
        soldOutReason: base.soldOutReason,
      );
      item = choice == null || choice == !base.soldOut ? changed : changed.withSoldOut(!choice);
    }
    final result = await menu.upsertItem(item);
    switch (result) {
      case Ok() when _aiFilledCount > 0:
        // The staff member saved an item the AI helped fill: how much of the suggestion did they keep?
        unawaited(
          analytics.logEvent(AnalyticsEvents.aiResultAccepted, {
            'feature': aiFeature,
            'fields_kept': _aiFields.length,
            'fields_changed': _aiFilledCount - _aiFields.length,
          }),
        );
      case Ok():
        break;
      case Err(:final error):
        crash.recordNonFatal(error, error.stackTrace, 'menuItemForm.save');
    }
    return result;
  }

  /// Sends the chosen photo to Cloudinary (`menu/<kioskId>/`) and returns its link; `Ok(null)` when no new photo
  /// was chosen. A failure stops the save before anything is written.
  Future<Result<String?>> _uploadPhoto(String kiosk) async {
    final photo = _picked;
    if (photo == null) return const Result.ok(null);
    final done = _uploaded;
    if (done != null && identical(done.photo, photo)) return Result.ok(done.url);
    _uploadProgress = 0;
    notifyListeners();
    try {
      final result = await storage.upload(
        folder: UploadFolder.menu,
        ownerId: kiosk,
        fileName: photo.fileName,
        bytes: photo.bytes,
        onProgress: (value) {
          _uploadProgress = value;
          notifyListeners();
        },
      );
      switch (result) {
        case Ok(:final value):
          _uploaded = (photo: photo, url: value.url);
          return Result.ok(value.url);
        case Err(:final error):
          crash.recordNonFatal(error, error.stackTrace, 'menuItemForm.uploadPhoto');
          return Result.error(error);
      }
    } finally {
      _uploadProgress = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_configSub?.cancel());
    save.dispose();
    suggest
      ..removeListener(notifyListeners)
      ..dispose();
    super.dispose();
  }
}
