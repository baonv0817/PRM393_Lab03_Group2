import 'package:breakbite_core/domain/models/option_group.dart';
import 'package:breakbite_core/ui/core/theme/app_colors.dart';
import 'package:breakbite_core/ui/core/theme/app_dimens.dart';
import 'package:breakbite_core/ui/core/widgets/buttons.dart';
import 'package:breakbite_core/ui/core/widgets/test_id.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The staff's form for the option groups of an item (size, topping, spice level): shared by the seller app (K14,
/// K15) and the web admin (W02). The parent owns the list; every change calls [onChanged] with the new list, and
/// [OptionGroup.problem] / `optionGroupsProblem` say whether it can be saved.
class OptionGroupsEditor extends StatelessWidget {
  const OptionGroupsEditor({super.key, required this.groups, required this.onChanged, this.problem});

  final List<OptionGroup> groups;
  final ValueChanged<List<OptionGroup>> onChanged;

  /// What is wrong with the groups, shown under the list in the error colour.
  final String? problem;

  static int _counter = 0;

  /// An id that is not used by another group or choice of the item. Ids only have to be unique inside one item.
  static String newId(String prefix) =>
      '$prefix${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_counter++}';

  /// Ready-made groups, so staff do not type the usual ones every time.
  static final presets = <({String label, OptionGroup Function() build})>[
    (
      label: 'Size S/M/L',
      build: () => OptionGroup(
        id: newId('g'),
        name: 'Size',
        required: true,
        choices: [
          OptionChoice(id: newId('c'), name: 'Size S'),
          OptionChoice(id: newId('c'), name: 'Size M', extraVnd: 5000),
          OptionChoice(id: newId('c'), name: 'Size L', extraVnd: 10000),
        ],
      ),
    ),
    (
      label: 'Topping',
      build: () => OptionGroup(
        id: newId('g'),
        name: 'Topping',
        maxChoices: 3,
        choices: [
          OptionChoice(id: newId('c'), name: 'Trân châu', extraVnd: 5000),
          OptionChoice(id: newId('c'), name: 'Thạch', extraVnd: 5000),
          OptionChoice(id: newId('c'), name: 'Pudding', extraVnd: 7000),
        ],
      ),
    ),
    (
      label: 'Mức cay',
      build: () => OptionGroup(
        id: newId('g'),
        name: 'Mức cay',
        required: true,
        choices: [
          OptionChoice(id: newId('c'), name: 'Không cay'),
          OptionChoice(id: newId('c'), name: 'Cay vừa'),
          OptionChoice(id: newId('c'), name: 'Cay nhiều'),
        ],
      ),
    ),
  ];

  void _replace(int index, OptionGroup group) => onChanged([...groups]..[index] = group);

  void _remove(int index) => onChanged([...groups]..removeAt(index));

  void _add(OptionGroup group) => onChanged([...groups, group]);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final full = groups.length >= OptionGroup.maxPerItem;
    return TestId(
      'options.editor',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('Tuỳ chọn (size, topping…)', style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Khách chọn trước khi thêm món vào giỏ. Giá thêm cộng vào giá món. Tối đa ${OptionGroup.maxPerItem} nhóm.',
            style: text.bodySmall?.copyWith(color: colors.muted),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final (index, group) in groups.indexed) ...[
            _GroupCard(
              key: ValueKey(group.id),
              index: index,
              group: group,
              onChanged: (g) => _replace(index, g),
              onRemove: () => _remove(index),
            ),
            const SizedBox(height: AppSpacing.xs),
          ],
          if (problem case final message?)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: TestId(
                'options.problem',
                child: Text(message, style: text.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
              ),
            ),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              TestId(
                'options.add',
                child: AppButton(
                  label: 'Thêm nhóm',
                  icon: Icons.add,
                  variant: AppButtonVariant.secondary,
                  onPressed: full
                      ? null
                      : () => _add(
                          OptionGroup(
                            id: newId('g'),
                            name: '',
                            choices: [OptionChoice(id: newId('c'), name: '')],
                          ),
                        ),
                ),
              ),
              for (final (i, preset) in presets.indexed)
                TestId(
                  'options.preset.$i',
                  child: ActionChip(label: Text(preset.label), onPressed: full ? null : () => _add(preset.build())),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupCard extends StatefulWidget {
  const _GroupCard({
    super.key,
    required this.index,
    required this.group,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final OptionGroup group;
  final ValueChanged<OptionGroup> onChanged;
  final VoidCallback onRemove;

  @override
  State<_GroupCard> createState() => _GroupCardState();
}

class _GroupCardState extends State<_GroupCard> {
  late final _name = TextEditingController(text: widget.group.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  OptionGroup _with({String? name, bool? required, int? maxChoices, List<OptionChoice>? choices}) {
    final g = widget.group;
    final nextChoices = choices ?? g.choices;
    return OptionGroup(
      id: g.id,
      name: name ?? g.name,
      required: required ?? g.required,
      maxChoices: (maxChoices ?? g.maxChoices).clamp(1, nextChoices.isEmpty ? 1 : nextChoices.length),
      choices: nextChoices,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = context.appColors;
    final g = widget.group;
    final id = 'options.group.${widget.index}';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TestId(
                  '$id.name',
                  child: TextField(
                    controller: _name,
                    maxLength: OptionGroup.maxNameLength,
                    decoration: const InputDecoration(labelText: 'Tên nhóm', hintText: 'Ví dụ: Size', counterText: ''),
                    onChanged: (v) => widget.onChanged(_with(name: v)),
                  ),
                ),
              ),
              AppIconButton(
                icon: Icons.delete_outline,
                semanticLabel: 'Xoá nhóm ${g.name}',
                onPressed: widget.onRemove,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(child: Text('Bắt buộc chọn', style: text.bodyMedium)),
              TestId(
                '$id.required',
                child: Switch(
                  value: g.required,
                  onChanged: (v) => widget.onChanged(_with(required: v)),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(child: Text('Cho chọn nhiều (tối đa ${g.maxChoices})', style: text.bodyMedium)),
              TestId(
                '$id.multiple',
                child: Switch(
                  value: g.multiple,
                  onChanged: (v) => widget.onChanged(_with(maxChoices: v ? (g.choices.length < 2 ? 1 : 2) : 1)),
                ),
              ),
            ],
          ),
          if (g.multiple)
            Row(
              children: [
                Expanded(child: Text('Tối đa', style: text.bodyMedium)),
                AppIconButton(
                  icon: Icons.remove,
                  semanticLabel: 'Giảm số lựa chọn tối đa',
                  onPressed: g.maxChoices > 2 ? () => widget.onChanged(_with(maxChoices: g.maxChoices - 1)) : null,
                ),
                Text('${g.maxChoices}', style: text.titleMedium),
                AppIconButton(
                  icon: Icons.add,
                  semanticLabel: 'Tăng số lựa chọn tối đa',
                  onPressed: g.maxChoices < g.choices.length
                      ? () => widget.onChanged(_with(maxChoices: g.maxChoices + 1))
                      : null,
                ),
              ],
            ),
          const Divider(),
          for (final (i, choice) in g.choices.indexed)
            _ChoiceRow(
              key: ValueKey(choice.id),
              id: '$id.choice.$i',
              choice: choice,
              canRemove: g.choices.length > 1,
              onChanged: (c) => widget.onChanged(_with(choices: [...g.choices]..[i] = c)),
              onRemove: () => widget.onChanged(_with(choices: [...g.choices]..removeAt(i))),
            ),
          TestId(
            '$id.addChoice',
            child: TextButton.icon(
              onPressed: g.choices.length >= OptionGroup.maxChoicesPerGroup
                  ? null
                  : () => widget.onChanged(
                      _with(
                        choices: [
                          ...g.choices,
                          OptionChoice(id: OptionGroupsEditor.newId('c'), name: ''),
                        ],
                      ),
                    ),
              icon: const Icon(Icons.add),
              label: const Text('Thêm lựa chọn'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatefulWidget {
  const _ChoiceRow({
    super.key,
    required this.id,
    required this.choice,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final String id;
  final OptionChoice choice;
  final bool canRemove;
  final ValueChanged<OptionChoice> onChanged;
  final VoidCallback onRemove;

  @override
  State<_ChoiceRow> createState() => _ChoiceRowState();
}

class _ChoiceRowState extends State<_ChoiceRow> {
  late final _name = TextEditingController(text: widget.choice.name);
  late final _extra = TextEditingController(text: widget.choice.extraVnd == 0 ? '' : '${widget.choice.extraVnd}');

  @override
  void dispose() {
    _name.dispose();
    _extra.dispose();
    super.dispose();
  }

  void _changed() =>
      widget.onChanged(OptionChoice(id: widget.choice.id, name: _name.text, extraVnd: int.tryParse(_extra.text) ?? 0));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TestId(
              '${widget.id}.name',
              child: TextField(
                controller: _name,
                maxLength: OptionGroup.maxNameLength,
                decoration: const InputDecoration(labelText: 'Lựa chọn', counterText: ''),
                onChanged: (_) => _changed(),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            flex: 2,
            child: TestId(
              '${widget.id}.extra',
              child: TextField(
                controller: _extra,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                decoration: const InputDecoration(labelText: 'Thêm (đ)', hintText: '0', counterText: ''),
                onChanged: (_) => _changed(),
              ),
            ),
          ),
          AppIconButton(
            icon: Icons.close,
            semanticLabel: 'Xoá lựa chọn ${widget.choice.name}',
            onPressed: widget.canRemove ? widget.onRemove : null,
          ),
        ],
      ),
    );
  }
}
