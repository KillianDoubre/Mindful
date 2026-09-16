/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mindful/core/services/task_reminders_service.dart';
import 'package:mindful/ui/common/glass_surface.dart';

enum _DelayUnit {
  minutes('min', 1),
  hours('heures', 60),
  days('jours', 1440);

  const _DelayUnit(this.label, this.factor);

  final String label;

  /// Minutes in one unit.
  final int factor;
}

const _presets = <int>[0, 5, 15, 30, 60, 120, 1440, 2880, 10080];

/// Asks how long before the due time to remind. Returns minutes.
Future<int?> showTaskReminderPicker(
  BuildContext context, {
  required List<int> existing,
}) =>
    showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReminderPickerSheet(existing: existing),
    );

class _ReminderPickerSheet extends StatefulWidget {
  const _ReminderPickerSheet({required this.existing});

  final List<int> existing;

  @override
  State<_ReminderPickerSheet> createState() => _ReminderPickerSheetState();
}

class _ReminderPickerSheetState extends State<_ReminderPickerSheet> {
  final _amountController = TextEditingController(text: '10');
  _DelayUnit _unit = _DelayUnit.minutes;

  int? get _customMinutes {
    final amount = int.tryParse(_amountController.text.trim());
    if (amount == null || amount < 0 || amount > 999) return null;
    return amount * _unit.factor;
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _pick(int minutes) {
    HapticFeedback.selectionClick();
    Navigator.pop(context, minutes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final custom = _customMinutes;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        8,
        0,
        8,
        MediaQuery.viewInsetsOf(context).bottom + 8,
      ),
      child: GlassSurface(
        groupBlur: false,
        blur: 28,
        color: colors.surfaceContainer.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Me rappeler…',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final preset in _presets)
                    ChoiceChip(
                      label: Text(formatReminderOffset(preset)),
                      selected: widget.existing.contains(preset),
                      onSelected: widget.existing.contains(preset)
                          ? null
                          : (_) => _pick(preset),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Personnalisé',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  SizedBox(
                    width: 76,
                    child: TextField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      textAlign: TextAlign.center,
                      onChanged: (_) => setState(() {}),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SegmentedButton<_DelayUnit>(
                      showSelectedIcon: false,
                      segments: [
                        for (final unit in _DelayUnit.values)
                          ButtonSegment(value: unit, label: Text(unit.label)),
                      ],
                      selected: {_unit},
                      onSelectionChanged: (value) =>
                          setState(() => _unit = value.first),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: custom == null || widget.existing.contains(custom)
                    ? null
                    : () => _pick(custom),
                icon: const Icon(Icons.add_alert_rounded),
                label: Text(
                  custom == null
                      ? 'Ajouter le rappel'
                      : 'Ajouter · ${formatReminderOffset(custom)}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
