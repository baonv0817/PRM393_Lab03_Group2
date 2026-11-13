import 'package:breakbite_core/domain/models/option_group.dart';

enum ItemCategory { food, drink, other }

/// Why staff marked an item sold out (K09); stored as the enum name.
enum SoldOutReason { outOfIngredients, machineBroken, other }

class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.priceVnd,
    required this.category,
    required this.prepMinutes,
    this.dishId = '',
    this.soldOut = false,
    this.kioskId = '',
    this.description = '',
    this.imageUrl,
    this.availableAgainAt,
    this.soldOutReason,
    this.archived = false,
    this.optionGroups = const [],
  });

  final String id;
  final String name;
  final int priceVnd;
  final ItemCategory category;
  final int prepMinutes;
  final String dishId;
  final bool soldOut;
  final String kioskId;
  final String description;
  final String? imageUrl;
  final DateTime? availableAgainAt;

  /// Set only while the item is sold out.
  final SoldOutReason? soldOutReason;

  /// Archived from the web admin: hidden from customers and the seller menu, kept for old orders and reviews.
  /// Items are never deleted (docs/data-model.md section 3.3).
  final bool archived;

  /// What the customer picks before adding the dish (size, toppings); empty for a dish that is just added.
  final List<OptionGroup> optionGroups;

  bool get hasOptions => optionGroups.isNotEmpty;

  /// The choices that [picked] (group id to choice ids) stands for, in the order of the groups; choices that are not
  /// in the groups are left out.
  List<SelectedChoice> choicesFor(Map<String, Set<String>> picked) => [
    for (final group in optionGroups)
      for (final choice in group.choices)
        if (picked[group.id]?.contains(choice.id) ?? false)
          SelectedChoice(
            groupId: group.id,
            groupName: group.name,
            choiceId: choice.id,
            name: choice.name,
            extraVnd: choice.extraVnd,
          ),
  ];

  /// The first thing wrong with [picked] (a required group left empty, too many choices), or `null` when the dish can
  /// be added with it.
  String? optionsProblem(Map<String, Set<String>> picked) {
    for (final group in optionGroups) {
      final problem = group.problemWith(picked[group.id] ?? const {});
      if (problem != null) return problem;
    }
    return null;
  }

  /// The price of one portion with the picked choices.
  int priceWith(Map<String, Set<String>> picked) => priceVnd + choicesFor(picked).fold(0, (sum, c) => sum + c.extraVnd);

  /// Customers can order it: on sale and not archived.
  bool get orderable => !soldOut && !archived;

  MenuItem copyWith({bool? soldOut, int? priceVnd}) => MenuItem(
    id: id,
    name: name,
    priceVnd: priceVnd ?? this.priceVnd,
    category: category,
    prepMinutes: prepMinutes,
    dishId: dishId,
    soldOut: soldOut ?? this.soldOut,
    kioskId: kioskId,
    description: description,
    imageUrl: imageUrl,
    availableAgainAt: (soldOut ?? this.soldOut) ? availableAgainAt : null,
    soldOutReason: (soldOut ?? this.soldOut) ? soldOutReason : null,
    archived: archived,
    optionGroups: optionGroups,
  );

  /// The item as it stands at [now]: a sold-out item whose "có lại lúc" time has passed is on sale again, so
  /// customers can order it without staff flipping the switch. The stored document is not changed.
  MenuItem availableAt(DateTime now) {
    final back = availableAgainAt;
    if (!soldOut || back == null || back.isAfter(now)) return this;
    return withSoldOut(false);
  }

  /// When the earliest sold-out item of [items] is due back after [now], or `null` when none has a time.
  static DateTime? nextReturn(Iterable<MenuItem> items, DateTime now) {
    DateTime? next;
    for (final item in items) {
      final back = item.availableAgainAt;
      if (!item.soldOut || back == null || !back.isAfter(now)) continue;
      if (next == null || back.isBefore(next)) next = back;
    }
    return next;
  }

  /// The item as it is after staff set it sold out (K09) or available again: the reason and the expected
  /// time are replaced, not kept, and both are dropped when the item is available.
  MenuItem withSoldOut(bool soldOut, {SoldOutReason? reason, DateTime? availableAgainAt}) => MenuItem(
    id: id,
    name: name,
    priceVnd: priceVnd,
    category: category,
    prepMinutes: prepMinutes,
    dishId: dishId,
    soldOut: soldOut,
    kioskId: kioskId,
    description: description,
    imageUrl: imageUrl,
    availableAgainAt: soldOut ? availableAgainAt : null,
    soldOutReason: soldOut ? reason : null,
    archived: archived,
    optionGroups: optionGroups,
  );

  /// The item after the web admin archives it or brings it back; nothing else changes.
  MenuItem withArchived(bool archived) => MenuItem(
    id: id,
    name: name,
    priceVnd: priceVnd,
    category: category,
    prepMinutes: prepMinutes,
    dishId: dishId,
    soldOut: soldOut,
    kioskId: kioskId,
    description: description,
    imageUrl: imageUrl,
    availableAgainAt: availableAgainAt,
    soldOutReason: soldOutReason,
    archived: archived,
    optionGroups: optionGroups,
  );
}
