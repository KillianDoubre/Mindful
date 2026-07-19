import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:mindful/models/productivity_item.dart';
import 'package:mindful/ui/common/glass_surface.dart';

const productivityNoteColors = <int>[
  0,
  0xFFFFD9DE,
  0xFFFFE1C7,
  0xFFFFF0B8,
  0xFFD9F2DF,
  0xFFD7EBFF,
  0xFFE9DDFB,
];

class ProductivityEditorResult {
  const ProductivityEditorResult.save(this.draft) : shouldDelete = false;
  const ProductivityEditorResult.delete()
      : draft = null,
        shouldDelete = true;

  final ProductivityItemDraft? draft;
  final bool shouldDelete;
}

Future<ProductivityEditorResult?> showProductivityEditor({
  required BuildContext context,
  required ProductivityItemType type,
  ProductivityItem? item,
}) =>
    showModalBottomSheet<ProductivityEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (context) => _ProductivityEditorSheet(type: type, item: item),
    );

class _ProductivityEditorSheet extends StatefulWidget {
  const _ProductivityEditorSheet({required this.type, this.item});

  final ProductivityItemType type;
  final ProductivityItem? item;

  @override
  State<_ProductivityEditorSheet> createState() =>
      _ProductivityEditorSheetState();
}

class _ProductivityEditorSheetState extends State<_ProductivityEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _detailsController;
  late int _colorValue;
  late bool _isCompleted;
  late DateTime? _dueAt;
  String? _titleError;

  bool get _isTask => widget.type == ProductivityItemType.task;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item?.title);
    _detailsController = TextEditingController(text: widget.item?.details);
    _colorValue = widget.item?.colorValue ?? 0;
    _isCompleted = widget.item?.isCompleted ?? false;
    _dueAt = widget.item?.dueAt;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final colors = Theme.of(context).colorScheme;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.fromLTRB(8, 24, 8, keyboardInset + 8),
      child: FractionallySizedBox(
        heightFactor: 0.94,
        alignment: Alignment.bottomCenter,
        child: GlassSurface(
          blur: 24,
          color: colors.surfaceContainer,
          borderRadius: BorderRadius.circular(30),
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Fermer',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(FluentIcons.dismiss_24_regular),
                      ),
                      Expanded(
                        child: Text(
                          widget.item == null
                              ? (_isTask ? 'Nouvelle tâche' : 'Nouvelle note')
                              : (_isTask
                                  ? 'Modifier la tâche'
                                  : 'Modifier la note'),
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      if (widget.item != null)
                        IconButton(
                          tooltip: 'Supprimer',
                          onPressed: _confirmDelete,
                          icon: Icon(
                            FluentIcons.delete_24_regular,
                            color: colors.error,
                          ),
                        )
                      else
                        const SizedBox(width: 48),
                    ],
                  ),
                ),
                Divider(height: 1, color: colors.outlineVariant),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _titleController,
                          autofocus: widget.item == null,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.next,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                          decoration: _inputDecoration(
                            context,
                            label: 'Titre',
                            icon: _isTask
                                ? FluentIcons.checkmark_circle_20_regular
                                : FluentIcons.text_header_1_20_regular,
                            errorText: _titleError,
                          ),
                          onChanged: (_) {
                            if (_titleError != null) {
                              setState(() => _titleError = null);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _detailsController,
                          minLines: _isTask ? 5 : 10,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _inputDecoration(
                            context,
                            label:
                                _isTask ? 'Détails (facultatif)' : 'Votre note',
                            icon: FluentIcons.text_align_left_20_regular,
                            alignLabelWithHint: true,
                          ),
                        ),
                        if (_isTask) ...[
                          const SizedBox(height: 18),
                          _TaskOptionsCard(
                            isCompleted: _isCompleted,
                            dueAt: _dueAt,
                            onCompletedChanged: (value) =>
                                setState(() => _isCompleted = value),
                            onDueChanged: (value) =>
                                setState(() => _dueAt = value),
                          ),
                        ] else ...[
                          const SizedBox(height: 20),
                          Text(
                            'Couleur',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              for (final value in productivityNoteColors)
                                _ColorChoice(
                                  value: value,
                                  isSelected: value == _colorValue,
                                  onSelected: () =>
                                      setState(() => _colorValue = value),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _save,
                      icon: const Icon(FluentIcons.checkmark_20_filled),
                      label: const Text('Enregistrer'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    BuildContext context, {
    required String label,
    required IconData icon,
    String? errorText,
    bool alignLabelWithHint = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      errorText: errorText,
      alignLabelWithHint: alignLabelWithHint,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: colors.surfaceContainerHigh.withValues(alpha: 0.72),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20),
        borderSide: BorderSide(
          color: colors.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
    );
  }

  void _save() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Ajoutez un titre');
      return;
    }
    Navigator.pop(
      context,
      ProductivityEditorResult.save(
        ProductivityItemDraft(
          title: title,
          details: _detailsController.text,
          colorValue: _isTask ? 0 : _colorValue,
          isCompleted: _isTask && _isCompleted,
          dueAt: _isTask ? _dueAt : null,
        ),
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(FluentIcons.delete_24_regular),
        title: Text(
            _isTask ? 'Supprimer cette tâche ?' : 'Supprimer cette note ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.pop(context, const ProductivityEditorResult.delete());
    }
  }
}

class _ColorChoice extends StatelessWidget {
  const _ColorChoice({
    required this.value,
    required this.isSelected,
    required this.onSelected,
  });

  final int value;
  final bool isSelected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = value == 0 ? colors.surfaceContainerHighest : Color(value);
    return Semantics(
      button: true,
      selected: isSelected,
      label: value == 0 ? 'Couleur automatique' : 'Couleur de note',
      child: InkWell(
        onTap: onSelected,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(
              color: isSelected ? colors.primary : colors.outlineVariant,
              width: isSelected ? 3 : 1,
            ),
          ),
          child: isSelected
              ? Icon(FluentIcons.checkmark_16_filled, color: colors.onSurface)
              : null,
        ),
      ),
    );
  }
}

class _TaskOptionsCard extends StatelessWidget {
  const _TaskOptionsCard({
    required this.isCompleted,
    required this.dueAt,
    required this.onCompletedChanged,
    required this.onDueChanged,
  });

  final bool isCompleted;
  final DateTime? dueAt;
  final ValueChanged<bool> onCompletedChanged;
  final ValueChanged<DateTime?> onDueChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: isCompleted,
            onChanged: onCompletedChanged,
            secondary: const Icon(FluentIcons.checkmark_circle_20_regular),
            title: const Text('Tâche terminée'),
          ),
          Divider(color: colors.outlineVariant),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: dueAt != null,
            onChanged: (enabled) {
              if (!enabled) {
                onDueChanged(null);
                return;
              }
              final tomorrow = DateTime.now().add(const Duration(days: 1));
              onDueChanged(
                DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 18),
              );
            },
            secondary: const Icon(FluentIcons.calendar_clock_20_regular),
            title: const Text('Ajouter une échéance'),
            subtitle: const Text('Date et heure facultatives'),
          ),
          if (dueAt != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(context),
                    icon: const Icon(FluentIcons.calendar_20_regular),
                    label: Text(MaterialLocalizations.of(context)
                        .formatMediumDate(dueAt!)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(context),
                    icon: const Icon(FluentIcons.clock_20_regular),
                    label: Text(MaterialLocalizations.of(context)
                        .formatTimeOfDay(TimeOfDay.fromDateTime(dueAt!))),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final current = dueAt!;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      onDueChanged(DateTime(
        picked.year,
        picked.month,
        picked.day,
        current.hour,
        current.minute,
      ));
    }
  }

  Future<void> _pickTime(BuildContext context) async {
    final current = dueAt!;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked != null) {
      onDueChanged(DateTime(
        current.year,
        current.month,
        current.day,
        picked.hour,
        picked.minute,
      ));
    }
  }
}
