import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/core/services/systems_repository.dart';
import 'package:mindful/models/life_system.dart';
import 'package:mindful/providers/systems/systems_provider.dart';
import 'package:mindful/ui/common/mindful_background.dart';

class SystemEditorScreen extends ConsumerStatefulWidget {
  const SystemEditorScreen({super.key, this.system});

  final LifeSystem? system;

  @override
  ConsumerState<SystemEditorScreen> createState() => _SystemEditorScreenState();
}

class _SystemEditorScreenState extends ConsumerState<SystemEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _direction;
  late final TextEditingController _identity;
  late final TextEditingController _minimum;
  late final TextEditingController _accountability;
  late final TextEditingController _comeback;
  late final TextEditingController _nextAction;
  late LifeSystemStatus _status;
  late int _priority;
  late int _reviewEveryDays;
  late List<_VictoryInput> _victories;
  late List<_RuleInput> _rules;
  late List<_FrictionInput> _frictions;
  int _step = 0;
  bool _saving = false;

  bool get _editing => widget.system != null;

  @override
  void initState() {
    super.initState();
    final system = widget.system;
    _name = TextEditingController(text: system?.name);
    _direction = TextEditingController(text: system?.direction);
    _identity = TextEditingController(text: system?.identity);
    _minimum = TextEditingController(text: system?.minimumVersion);
    _accountability = TextEditingController(text: system?.accountabilityName);
    _comeback = TextEditingController(text: system?.comebackRule);
    _nextAction = TextEditingController(text: system?.nextAction);
    _status = system?.status ?? LifeSystemStatus.active;
    _priority = system?.priority ?? 3;
    _reviewEveryDays = system?.reviewEveryDays ?? 7;
    _victories = system?.victories
            .map(
              (item) => _VictoryInput(
                id: item.id,
                title: item.title,
                target: item.targetCount,
                important: item.isImportant,
              ),
            )
            .toList() ??
        [_VictoryInput()];
    _rules = system?.rules
            .map(
              (item) => _RuleInput(
                id: item.id,
                text: item.text,
                active: item.isActive,
              ),
            )
            .toList() ??
        [_RuleInput()];
    _frictions = system?.frictions
            .map(
              (item) => _FrictionInput(
                id: item.id,
                text: item.text,
                type: item.type,
                status: item.status,
              ),
            )
            .toList() ??
        [_FrictionInput(type: SystemFrictionType.remove)];
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _direction,
      _identity,
      _minimum,
      _accountability,
      _comeback,
      _nextAction,
    ]) {
      controller.dispose();
    }
    for (final item in _victories) {
      item.dispose();
    }
    for (final item in _rules) {
      item.dispose();
    }
    for (final item in _frictions) {
      item.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: .96),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(_editing ? 'Modifier le système' : 'Nouveau système'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('${_step + 1}/10'),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MindfulBackground(),
          SafeArea(
            top: false,
            child: Stepper(
              currentStep: _step,
              type: StepperType.vertical,
              elevation: 0,
              margin: const EdgeInsets.only(left: 18, right: 14, bottom: 110),
              onStepTapped: (value) => setState(() => _step = value),
              controlsBuilder: (context, details) => Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _saving
                          ? null
                          : _step == 9
                              ? _save
                              : _next,
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _step == 9
                                  ? FluentIcons.checkmark_20_filled
                                  : FluentIcons.arrow_right_20_filled,
                            ),
                      label: Text(
                        _step == 9
                            ? (_editing ? 'Enregistrer' : 'Créer le système')
                            : 'Continuer',
                      ),
                    ),
                    if (_step > 0) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed:
                            _saving ? null : () => setState(() => _step--),
                        child: const Text('Retour'),
                      ),
                    ],
                  ],
                ),
              ),
              steps: [
                Step(
                  title: const Text('Nom et direction'),
                  subtitle:
                      const Text('La destination, sans en faire un score'),
                  isActive: _step >= 0,
                  content: Column(
                    children: [
                      _field(
                        controller: _name,
                        label: 'Nom du système',
                        hint: 'Ex. Activité entrepreneuriale',
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _direction,
                        label: 'Direction à long terme',
                        hint:
                            'Ex. Construire une activité rentable qui augmente progressivement ma liberté.',
                        lines: 4,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<LifeSystemStatus>(
                        initialValue: _status,
                        decoration: _decoration('État initial'),
                        items: LifeSystemStatus.values
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(status.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _status = value ?? _status),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<int>(
                        initialValue: _priority,
                        decoration: _decoration('Priorité'),
                        items: const [
                          DropdownMenuItem(
                              value: 1, child: Text('1 · Essentiel')),
                          DropdownMenuItem(
                              value: 2, child: Text('2 · Important')),
                          DropdownMenuItem(value: 3, child: Text('3 · Normal')),
                          DropdownMenuItem(
                              value: 4, child: Text('4 · Secondaire')),
                          DropdownMenuItem(
                              value: 5, child: Text('5 · Entretien')),
                        ],
                        onChanged: (value) =>
                            setState(() => _priority = value ?? _priority),
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Identité'),
                  subtitle: const Text('Observable et atteignable maintenant'),
                  isActive: _step >= 1,
                  content: _field(
                    controller: _identity,
                    label: 'Je suis une personne qui…',
                    hint:
                        'Ex. travaille sur le principal goulot d’étranglement et confronte son offre au marché.',
                    lines: 5,
                  ),
                ),
                Step(
                  title: const Text('Victoires hebdomadaires'),
                  subtitle: const Text(
                      'Des actions contrôlables, jamais des résultats'),
                  isActive: _step >= 2,
                  content: _victoriesEditor(),
                ),
                Step(
                  title: const Text('Version minimale'),
                  subtitle: const Text(
                      'Ce qui reste possible lors d’une semaine difficile'),
                  isActive: _step >= 3,
                  content: Column(
                    children: [
                      _field(
                        controller: _minimum,
                        label: 'Version minimale',
                        hint:
                            'Ex. travailler cinq minutes sur la prochaine action.',
                        lines: 3,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _nextAction,
                        label: 'Prochaine action concrète',
                        hint:
                            'Ex. envoyer le brouillon de l’offre à trois prospects.',
                        lines: 3,
                      ),
                    ],
                  ),
                ),
                Step(
                  title: const Text('Règles de vie'),
                  subtitle:
                      const Text('Des décisions prises avant la tentation'),
                  isActive: _step >= 4,
                  content: _rulesEditor(),
                ),
                Step(
                  title: const Text('Frictions'),
                  subtitle: const Text('Retirer un obstacle ou en ajouter un'),
                  isActive: _step >= 5,
                  content: _frictionsEditor(),
                ),
                Step(
                  title: const Text('Redevabilité'),
                  subtitle:
                      const Text('Une personne extérieure, si elle existe'),
                  isActive: _step >= 6,
                  content: _field(
                    controller: _accountability,
                    label: 'Prénom ou nom de la personne',
                    hint: 'Facultatif',
                  ),
                ),
                Step(
                  title: const Text('Règle de reprise'),
                  subtitle: const Text(
                      'La reprise compte davantage que la perfection'),
                  isActive: _step >= 7,
                  content: _field(
                    controller: _comeback,
                    label: 'Après une interruption…',
                    hint:
                        'Ex. reprendre à la prochaine occurrence prévue sans compenser excessivement.',
                    lines: 5,
                  ),
                ),
                Step(
                  title: const Text('Fréquence de révision'),
                  subtitle: const Text('Un système doit pouvoir évoluer'),
                  isActive: _step >= 8,
                  content: DropdownButtonFormField<int>(
                    initialValue: _reviewEveryDays,
                    decoration: _decoration('Rythme de revue'),
                    items: const [
                      DropdownMenuItem(value: 7, child: Text('Chaque semaine')),
                      DropdownMenuItem(
                          value: 14, child: Text('Toutes les deux semaines')),
                      DropdownMenuItem(value: 30, child: Text('Chaque mois')),
                    ],
                    onChanged: (value) => setState(
                      () => _reviewEveryDays = value ?? _reviewEveryDays,
                    ),
                  ),
                ),
                Step(
                  title: const Text('Résumé'),
                  subtitle: const Text(
                      'Le système doit rester au service de la vie réelle'),
                  isActive: _step >= 9,
                  content: _summary(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _victoriesEditor() => Column(
        children: [
          for (var index = 0; index < _victories.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EditorCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            controller: _victories[index].title,
                            label: 'Victoire ${index + 1}',
                            hint: 'Ex. réaliser quatre blocs de travail',
                          ),
                        ),
                        if (_victories.length > 1)
                          IconButton(
                            tooltip: 'Retirer',
                            onPressed: () => _removeVictory(index),
                            icon: const Icon(FluentIcons.delete_20_regular),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Text('Cible par semaine'),
                        const Spacer(),
                        IconButton.filledTonal(
                          onPressed: _victories[index].target <= 1
                              ? null
                              : () =>
                                  setState(() => _victories[index].target--),
                          icon: const Icon(FluentIcons.subtract_20_regular),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text(
                            '${_victories[index].target}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: _victories[index].target >= 99
                              ? null
                              : () =>
                                  setState(() => _victories[index].target++),
                          icon: const Icon(FluentIcons.add_20_regular),
                        ),
                      ],
                    ),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Victoire importante'),
                      subtitle: const Text(
                          '20 XP au lieu de 10, une fois par occurrence'),
                      value: _victories[index].important,
                      onChanged: (value) =>
                          setState(() => _victories[index].important = value),
                    ),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _victories.add(_VictoryInput())),
              icon: const Icon(FluentIcons.add_20_regular),
              label: const Text('Ajouter une victoire'),
            ),
          ),
        ],
      );

  Widget _rulesEditor() => Column(
        children: [
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: _rules.length,
            onReorderItem: (oldIndex, newIndex) {
              setState(
                  () => _rules.insert(newIndex, _rules.removeAt(oldIndex)));
              HapticFeedback.selectionClick();
            },
            itemBuilder: (context, index) => Padding(
              key: ValueKey(_rules[index]),
              padding: const EdgeInsets.only(bottom: 10),
              child: _EditorCard(
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child:
                            Icon(FluentIcons.re_order_dots_vertical_20_regular),
                      ),
                    ),
                    Expanded(
                      child: _field(
                        controller: _rules[index].text,
                        label: 'Règle ${index + 1}',
                        hint: 'Ex. le téléphone reste hors de portée.',
                        lines: 2,
                      ),
                    ),
                    Switch.adaptive(
                      value: _rules[index].active,
                      onChanged: (value) =>
                          setState(() => _rules[index].active = value),
                    ),
                    IconButton(
                      onPressed: () => _removeRule(index),
                      icon: const Icon(FluentIcons.delete_20_regular),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _rules.add(_RuleInput())),
              icon: const Icon(FluentIcons.add_20_regular),
              label: const Text('Ajouter une règle'),
            ),
          ),
        ],
      );

  Widget _frictionsEditor() => Column(
        children: [
          for (var index = 0; index < _frictions.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _EditorCard(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _field(
                            controller: _frictions[index].text,
                            label: 'Friction ${index + 1}',
                            hint: 'Ex. préparer le sac la veille.',
                            lines: 2,
                          ),
                        ),
                        IconButton(
                          onPressed: () => _removeFriction(index),
                          icon: const Icon(FluentIcons.delete_20_regular),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SegmentedButton<SystemFrictionType>(
                      segments: const [
                        ButtonSegment(
                          value: SystemFrictionType.remove,
                          label: Text('Retirer'),
                          icon: Icon(FluentIcons.subtract_circle_20_regular),
                        ),
                        ButtonSegment(
                          value: SystemFrictionType.add,
                          label: Text('Ajouter'),
                          icon: Icon(FluentIcons.add_circle_20_regular),
                        ),
                      ],
                      selected: {_frictions[index].type},
                      onSelectionChanged: (value) =>
                          setState(() => _frictions[index].type = value.first),
                    ),
                  ],
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => setState(
                () => _frictions.add(
                  _FrictionInput(type: SystemFrictionType.remove),
                ),
              ),
              icon: const Icon(FluentIcons.add_20_regular),
              label: const Text('Ajouter une friction'),
            ),
          ),
        ],
      );

  Widget _summary() {
    final validVictories =
        _victories.where((v) => v.title.text.trim().isNotEmpty);
    return _EditorCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SummaryLine(label: 'Nom', value: _name.text.trim()),
          _SummaryLine(label: 'État', value: _status.label),
          _SummaryLine(label: 'Identité', value: _identity.text.trim()),
          _SummaryLine(
            label: 'Victoires',
            value:
                '${validVictories.length} définie${validVictories.length > 1 ? 's' : ''}',
          ),
          _SummaryLine(label: 'Version minimale', value: _minimum.text.trim()),
          _SummaryLine(
            label: 'Redevabilité',
            value: _accountability.text.trim().isEmpty
                ? 'Aucune personne'
                : _accountability.text.trim(),
          ),
          const SizedBox(height: 8),
          Text(
            'Mindful ne récompensera jamais l’ouverture de cette page. Seules les preuves produites dans la vie réelle comptent.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  TextField _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    int lines = 1,
  }) =>
      TextField(
        controller: controller,
        minLines: lines,
        maxLines: lines == 1 ? 1 : lines + 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: _decoration(label).copyWith(hintText: hint),
      );

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      );

  void _next() {
    final error = _stepError(_step);
    if (error != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    setState(() => _step++);
  }

  String? _stepError(int step) {
    if (step == 0 &&
        (_name.text.trim().isEmpty || _direction.text.trim().isEmpty)) {
      return 'Ajoute un nom et une direction claire.';
    }
    if (step == 1 && _identity.text.trim().isEmpty) {
      return 'Décris une identité observable et atteignable.';
    }
    if (step == 2 &&
        !_victories.any((victory) => victory.title.text.trim().isNotEmpty)) {
      return 'Ajoute au moins une victoire hebdomadaire.';
    }
    if (step == 3 && _minimum.text.trim().isEmpty) {
      return 'Prévois une version minimale pour les jours difficiles.';
    }
    if (step == 7 && _comeback.text.trim().isEmpty) {
      return 'Définis une règle de reprise explicite.';
    }
    return null;
  }

  Future<void> _save() async {
    for (var step = 0; step < 9; step++) {
      final error = _stepError(step);
      if (error != null) {
        setState(() => _step = step);
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error)));
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final id = await ref.read(systemsProvider.notifier).save(
            LifeSystemDraft(
              name: _name.text,
              direction: _direction.text,
              identity: _identity.text,
              status: _status,
              priority: _priority,
              minimumVersion: _minimum.text,
              accountabilityName: _accountability.text,
              comebackRule: _comeback.text,
              nextAction: _nextAction.text,
              reviewEveryDays: _reviewEveryDays,
              victories: _victories
                  .where((item) => item.title.text.trim().isNotEmpty)
                  .map(
                    (item) => SystemVictoryDraft(
                      id: item.id,
                      title: item.title.text,
                      targetCount: item.target,
                      isImportant: item.important,
                    ),
                  )
                  .toList(),
              rules: _rules
                  .where((item) => item.text.text.trim().isNotEmpty)
                  .map(
                    (item) => SystemRuleDraft(
                      id: item.id,
                      text: item.text.text,
                      isActive: item.active,
                    ),
                  )
                  .toList(),
              frictions: _frictions
                  .where((item) => item.text.text.trim().isNotEmpty)
                  .map(
                    (item) => SystemFrictionDraft(
                      id: item.id,
                      text: item.text.text,
                      type: item.type,
                      status: item.status,
                    ),
                  )
                  .toList(),
            ),
            id: widget.system?.id,
          );
      if (mounted) Navigator.of(context).pop(id);
    } on SystemsLimitException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _removeVictory(int index) {
    _victories.removeAt(index).dispose();
    setState(() {});
  }

  void _removeRule(int index) {
    _rules.removeAt(index).dispose();
    setState(() {});
  }

  void _removeFriction(int index) {
    _frictions.removeAt(index).dispose();
    setState(() {});
  }
}

class _VictoryInput {
  _VictoryInput(
      {this.id, String title = '', this.target = 1, this.important = false})
      : title = TextEditingController(text: title);

  final int? id;
  final TextEditingController title;
  int target;
  bool important;

  void dispose() => title.dispose();
}

class _RuleInput {
  _RuleInput({this.id, String text = '', this.active = true})
      : text = TextEditingController(text: text);

  final int? id;
  final TextEditingController text;
  bool active;

  void dispose() => text.dispose();
}

class _FrictionInput {
  _FrictionInput({
    this.id,
    String text = '',
    required this.type,
    this.status = SystemFrictionStatus.proposed,
  }) : text = TextEditingController(text: text);

  final int? id;
  final TextEditingController text;
  SystemFrictionType type;
  SystemFrictionStatus status;

  void dispose() => text.dispose();
}

class _EditorCard extends StatelessWidget {
  const _EditorCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainer
              .withValues(alpha: .72),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .outlineVariant
                .withValues(alpha: .45),
          ),
        ),
        child: child,
      );
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 2),
            Text(value.isEmpty ? 'Non défini' : value),
          ],
        ),
      );
}
