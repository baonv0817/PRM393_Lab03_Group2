/// One thing a customer can pick in an [OptionGroup]: "Size L", "Thêm trứng". [extraVnd] is added to the price of one
/// portion and is 0 for a choice that costs nothing.
class OptionChoice {
  const OptionChoice({required this.id, required this.name, this.extraVnd = 0});

  final String id;
  final String name;
  final int extraVnd;
}

/// A question the customer answers before adding a dish, like on a food-delivery app: "Size" (pick one), "Topping"
/// (pick up to three). Staff define the groups on the item (docs/data-model.md, `optionGroups`); at most
/// [maxPerItem] groups per item, so the Security Rules can bound the document.
class OptionGroup {
  const OptionGroup({
    required this.id,
    required this.name,
    required this.choices,
    this.required = false,
    this.maxChoices = 1,
  });

  static const maxPerItem = 5;
  static const maxChoicesPerGroup = 10;
  static const maxNameLength = 30;
  static const maxExtraVnd = 500000;

  final String id;
  final String name;
  final List<OptionChoice> choices;

  /// The customer must pick at least one choice before the dish can be added.
  final bool required;

  /// How many choices can be picked: 1 is "pick one" (radio buttons), more is "pick up to N" (check boxes).
  final int maxChoices;

  bool get multiple => maxChoices > 1;

  OptionChoice? choice(String id) => choices.where((c) => c.id == id).firstOrNull;

  /// What is wrong with [picked] (choice ids) for this group, in words for the customer; `null` when it is fine.
  String? problemWith(Set<String> picked) {
    if (required && picked.isEmpty) return 'Chọn $name';
    if (picked.length > maxChoices) return '$name: chọn tối đa $maxChoices';
    return null;
  }

  /// A short line under the group's name: "Chọn 1", "Chọn tối đa 3", "Không bắt buộc".
  String get hint {
    if (!multiple) return required ? 'Chọn 1 · bắt buộc' : 'Chọn 1 · không bắt buộc';
    return required ? 'Chọn từ 1 đến $maxChoices · bắt buộc' : 'Chọn tối đa $maxChoices · không bắt buộc';
  }

  /// What staff typed, or `null` when the group can be saved. Used by the editor and again before the write.
  String? get problem {
    if (name.trim().isEmpty) return 'Nhóm tuỳ chọn cần có tên.';
    if (name.trim().length > maxNameLength) return 'Tên nhóm tối đa $maxNameLength ký tự.';
    if (choices.isEmpty) return 'Nhóm "${name.trim()}" cần ít nhất một lựa chọn.';
    if (choices.length > maxChoicesPerGroup) {
      return 'Nhóm "${name.trim()}" tối đa $maxChoicesPerGroup lựa chọn.';
    }
    if (maxChoices < 1 || maxChoices > choices.length) {
      return 'Nhóm "${name.trim()}": số lựa chọn tối đa phải từ 1 đến ${choices.length}.';
    }
    final names = <String>{};
    for (final c in choices) {
      if (c.name.trim().isEmpty) return 'Nhóm "${name.trim()}" có lựa chọn chưa có tên.';
      if (c.name.trim().length > maxNameLength) return 'Tên lựa chọn tối đa $maxNameLength ký tự.';
      if (c.extraVnd < 0 || c.extraVnd > maxExtraVnd) return 'Giá thêm của "${c.name.trim()}" không hợp lệ.';
      if (!names.add(c.name.trim().toLowerCase())) return 'Nhóm "${name.trim()}" có hai lựa chọn trùng tên.';
    }
    return null;
  }
}

/// A choice the customer picked, copied onto the cart line and then the order line, so an old order still reads the
/// same after staff change the item's options.
class SelectedChoice {
  const SelectedChoice({
    required this.groupId,
    required this.groupName,
    required this.choiceId,
    required this.name,
    this.extraVnd = 0,
  });

  final String groupId;
  final String groupName;
  final String choiceId;
  final String name;
  final int extraVnd;
}

/// What is wrong with the option groups of one item, or `null` when they can be saved.
String? optionGroupsProblem(List<OptionGroup> groups) {
  if (groups.length > OptionGroup.maxPerItem) return 'Mỗi món tối đa ${OptionGroup.maxPerItem} nhóm tuỳ chọn.';
  final names = <String>{};
  final ids = <String>{};
  for (final group in groups) {
    if (group.problem case final problem?) return problem;
    if (!names.add(group.name.trim().toLowerCase())) return 'Hai nhóm tuỳ chọn trùng tên "${group.name.trim()}".';
    if (!ids.add(group.id) || group.choices.map((c) => c.id).toSet().length != group.choices.length) {
      return 'Mã của các nhóm hoặc lựa chọn bị trùng.';
    }
  }
  return null;
}
