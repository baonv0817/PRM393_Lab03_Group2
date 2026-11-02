import 'dart:async';

import 'package:breakbite/data/repositories/repositories.dart';
import 'package:breakbite/data/services/services.dart';
import 'package:breakbite/domain/app_exception.dart';
import 'package:breakbite/domain/models/models.dart';
import 'package:breakbite/ui/core/view_state.dart';
import 'package:breakbite/utils/command.dart';
import 'package:breakbite/utils/format.dart';
import 'package:breakbite/utils/result.dart';
import 'package:breakbite/utils/safe_change_notifier.dart';
import 'package:breakbite/utils/text.dart';
import 'package:flutter/foundation.dart';

/// K14 (add an item) and K15 (edit one): the same form. The field errors show once the staff member has
/// tried to save (K14-ERR); nothing is written until every field is valid.
class MenuItemFormViewModel extends ChangeNotifier with SafeChangeNotifier {
  MenuItemFormViewModel({required this.menu, required this.crash, required this.kioskId, this.itemId}) {
    save = Command0(_save);
    load();
  }

  static const maxNameLength = 60;
  static const maxDescriptionLength = 200;
  static const maxPriceVnd = 1000000;
  static const maxPrepMinutes = 120;
  static const defaultPrepMinutes = 5;

  static const noKioskMessage = 'Tài khoản này chưa được gán kiosk nên chưa thêm hay sửa món được.';
  static const notFoundMessage = 'Không tìm thấy món này.';
  static const notYoursMessage = 'Món này không thuộc kiosk của bạn.';
  static const invalidMessage = 'Kiểm tra lại các ô báo lỗi.';

  /// The kinds of item, in the order they are offered.
  static const categories = ItemCategory.values;

  final MenuRepository menu;
  final CrashService crash;

  /// The kiosk of the staff member; a new item belongs to it.
  final String? kioskId;

  /// The item being edited, `null` when adding a new one.
  final String? itemId;

  bool get isNew => itemId == null;

  /// Saves the item and returns its id.
  late final Command0<String> save;

  ViewState<MenuItem?> _state = const ViewLoading();
  MenuItem? _loaded;
  String _name = '';
  String _price = '';
  String _prep = '$defaultPrepMinutes';
  String _description = '';
  ItemCategory _category = ItemCategory.food;
  bool _attempted = false;
  String? _takenSlug;

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

  void setName(String value) {
    _name = value.length > maxNameLength ? value.substring(0, maxNameLength) : value;
    notifyListeners();
  }

  void setPrice(String value) {
    _price = value;
    notifyListeners();
  }

  void setPrepMinutes(String value) {
    _prep = value;
    notifyListeners();
  }

  void setDescription(String value) {
    _description = value.length > maxDescriptionLength ? value.substring(0, maxDescriptionLength) : value;
    notifyListeners();
  }

  void setCategory(ItemCategory value) {
    if (value == _category) return;
    _category = value;
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
        saved.category != _category;
  }

  bool get canSave => hasChanges;

  Future<Result<String>> _save() async {
    _attempted = true;
    notifyListeners();
    if (!isValid) return const Result.error(ValidationException(invalidMessage));
    final kiosk = kioskId!;
    final name = _name.trim();
    final description = _description.trim();
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
      );
    } else {
      // Start from the item as it is now, so a sold-out switch flipped meanwhile is not undone by this save.
      final current = await menu.getItem(itemId!);
      final base = current.valueOrNull ?? _loaded!;
      item = MenuItem(
        id: base.id,
        name: name,
        priceVnd: _priceValue!,
        category: _category,
        prepMinutes: _prepValue!,
        dishId: base.dishId,
        soldOut: base.soldOut,
        kioskId: base.kioskId,
        description: description,
        imageUrl: base.imageUrl,
        availableAgainAt: base.availableAgainAt,
        soldOutReason: base.soldOutReason,
      );
    }
    final result = await menu.upsertItem(item);
    if (result case Err(:final error)) crash.recordNonFatal(error, error.stackTrace, 'menuItemForm.save');
    return result;
  }

  @override
  void dispose() {
    save.dispose();
    super.dispose();
  }
}
