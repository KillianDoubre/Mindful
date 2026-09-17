import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/core/services/systems_repository.dart';
import 'package:mindful/models/life_system.dart';
import 'package:mindful/providers/systems/systems_provider.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/ui/common/mindful_background.dart';
import 'package:mindful/ui/common/page_app_bar.dart';

const _defaultComebackRule =
    'Ne jamais manquer deux fois : si je rate un jour, je fais au moins la version 2 minutes le lendemain.';

const _identityIdeas = [
  'lit un peu chaque jour',
  'prend soin de son corps',
  'termine ce qu’il commence',
  'se couche à l’heure',
  'apprend quelque chose chaque jour',
  'reste concentré sur l’essentiel',
];

/// System creation and editing, built on Atomic Habits.
///
/// Creating a system takes three light steps (identity, habit, environment);
/// everything else lives in collapsed advanced options. Editing shows the
/// same sections on a single page.
class SystemEditorScreen extends ConsumerStatefulWidget {
  const SystemEditorScreen({super.key, this.system});

  final LifeSystem? system;

  @override
  ConsumerState<SystemEditorScreen> createState() => _SystemEditorScreenState();
}

class _SystemEditorScreenState extends ConsumerState<SystemEditorScreen> {
  static const _stepTitles = [
    'Qui veux-tu devenir ?',
    'Quelle est la plus petite action ?',
    'Rends-le évident et satisfaisant',
  ];

  late final TextEditingController _name;
  late final TextEditingController _identity;
  late final TextEditingController _minimum;
  late final TextEditingController _intention;
  late final TextEditingController _reward;
  late final TextEditingController _accountability;
  late final TextEditingController _comeback;
  late final TextEditingController _notes;
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
    _identity = TextEditingController(text: system?.identity);
    _minimum = TextEditingController(text: system?.minimumVersion);
    _intention = TextEditingController(text: system?.intention);
    _reward = TextEditingController(text: system?.reward);
    _accountability = TextEditingController(text: system?.accountabilityName);
    _comeback = TextEditingController(text: system?.comebackRule);
    _notes = TextEditingController(text: system?.notes);
    _status = system?.status ?? LifeSystemStatus.active;
    _priority = system?.priority ?? 3;
    _reviewEveryDays = system?.reviewEveryDays ?? 7;
    _victories = system?.victories
            .map(
              (item) => _VictoryInput(
                id: item.id,
                title: item.title,
                target: item.perPeriodTarget,
                important: item.isImportant,
                frequency: item.frequency,
              ),
            )
            .toList() ??
        [_VictoryInput()];
    if (_victories.isEmpty) _victories.add(_VictoryInput());
    _rules = system?.rules
            .map(
              (item) => _RuleInput(
                id: item.id,
                text: item.text,
                active: item.isActive,
              ),
            )
            .toList() ??
        [];
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
      _identity,
      _minimum,
      _intention,
      _reward,
      _accountability,
      _comeback,
      _notes,
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
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final sections = [_identitySection, _habitSection, _environmentSection];

    return Stack(
      fit: StackFit.expand,
      children: [
        const MindfulBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PageAppBar(
            title: Text(_editing ? 'Modifier le système' : 'Nouveau système'),
            bottom: _editing
                ? null
                : PreferredSize(
                    preferredSize: const Size.fromHeight(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: (_step + 1) / sections.length),
                          duration: const Duration(milliseconds: 300),
                          builder: (context, value, _) =>
                              LinearProgressIndicator(
                            value: value,
                            minHeight: 6,
                            backgroundColor:
                                colors.onSurface.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          body: BackdropGroup(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: _editing
                  ? [
                      for (var i = 0; i < sections.length; i++) ...[
                        _StepTitle(title: _stepTitles[i]),
                        sections[i](),
                        const SizedBox(height: 22),
                      ],
                    ]
                  : [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) => FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: Tween(
                              begin: const Offset(0.06, 0),
                              end: Offset.zero,
                            ).animate(animation),
                            child: child,
                          ),
                        ),
                        child: Column(
                          key: ValueKey(_step),
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Étape ${_step + 1} sur ${sections.length}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            _StepTitle(title: _stepTitles[_step]),
                            sections[_step](),
                          ],
                        ),
                      ),
                    ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Row(
              children: [
                if (!_editing && _step > 0) ...[
                  OutlinedButton(
                    onPressed: () => setState(() => _step--),
                    child: const Text('Retour'),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: _saving
                        ? null
                        : _editing || _step == sections.length - 1
                            ? _save
                            : _next,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _editing || _step == sections.length - 1
                                ? FluentIcons.checkmark_20_filled
                                : FluentIcons.arrow_right_20_filled,
                          ),
                    label: Text(
                      _editing
                          ? 'Enregistrer'
                          : _step == sections.length - 1
                              ? 'Créer mon système'
                              : 'Continuer',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Sections
  // ---------------------------------------------------------------------------

  Widget _identitySection() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Hint(
            'Les habitudes durables partent de l’identité, pas du résultat. '
            'Chaque action devient un vote pour cette personne.',
          ),
          const SizedBox(height: 14),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(
                  controller: _name,
                  label: 'Nom du système',
                  hint: 'Lecture, Sport, Sommeil…',
                  autofocus: !_editing,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _identity,
                  label: 'Je suis quelqu’un qui…',
                  hint: 'lit un peu chaque jour',
                  lines: 2,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final idea in _identityIdeas)
                      ActionChip(
                        label: Text(idea),
                        onPressed: () => setState(() => _identity.text = idea),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );

  Widget _habitSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Hint(
            'Commence ridiculement petit. Une habitude doit pouvoir se faire '
            'même les mauvais jours.',
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < _victories.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _victoryEditor(index),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _victories.add(_VictoryInput())),
              icon: const Icon(FluentIcons.add_20_regular),
              label: const Text('Ajouter une habitude'),
            ),
          ),
          const SizedBox(height: 8),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(
                  controller: _minimum,
                  label: 'Version 2 minutes',
                  hint: 'Lire une page · enfiler ses baskets',
                  icon: FluentIcons.timer_2_20_regular,
                ),
                const SizedBox(height: 6),
                const _Hint(
                  'La version à faire quand tout va mal. Elle compte comme un vote.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(
                  controller: _intention,
                  label: 'Intention · quand et où ?',
                  hint: 'Après mon café du matin, je lis au salon',
                  icon: FluentIcons.link_20_regular,
                  lines: 2,
                ),
                const SizedBox(height: 6),
                const _Hint(
                  'Accroche la nouvelle habitude à une habitude existante : '
                  '« Après [habitude actuelle], je [nouvelle habitude]. »',
                ),
              ],
            ),
          ),
        ],
      );

  Widget _victoryEditor(int index) {
    final victory = _victories[index];
    final colors = Theme.of(context).colorScheme;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _field(
                  controller: victory.title,
                  label:
                      'Habitude${_victories.length > 1 ? ' ${index + 1}' : ''}',
                  hint: 'Lire 10 pages',
                  icon: FluentIcons.checkmark_starburst_20_regular,
                ),
              ),
              if (_victories.length > 1)
                IconButton(
                  tooltip: 'Retirer',
                  onPressed: () => setState(
                    () => _victories.removeAt(index).dispose(),
                  ),
                  icon: const Icon(FluentIcons.delete_20_regular),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: SegmentedButton<SystemVictoryFrequency>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: SystemVictoryFrequency.daily,
                      label: Text('Chaque jour'),
                    ),
                    ButtonSegment(
                      value: SystemVictoryFrequency.weekly,
                      label: Text('Par semaine'),
                    ),
                  ],
                  selected: {victory.frequency},
                  onSelectionChanged: (value) =>
                      setState(() => victory.frequency = value.first),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Fois par ${victory.frequency.unit}',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const Spacer(),
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                onPressed: victory.target <= 1
                    ? null
                    : () => setState(() => victory.target--),
                icon: const Icon(FluentIcons.subtract_16_regular),
              ),
              SizedBox(
                width: 36,
                child: Text(
                  '${victory.target}',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              IconButton.filledTonal(
                visualDensity: VisualDensity.compact,
                onPressed: victory.target >= 99
                    ? null
                    : () => setState(() => victory.target++),
                icon: const Icon(FluentIcons.add_16_regular),
              ),
            ],
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text('Habitude clé ★'),
            subtitle: const Text('Vaut deux votes d’XP'),
            value: victory.important,
            onChanged: (value) => setState(() => victory.important = value),
          ),
        ],
      ),
    );
  }

  Widget _environmentSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Hint(
            'L’environnement bat la motivation : rends la bonne habitude '
            'visible et facile, la mauvaise invisible et pénible.',
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < _frictions.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _frictionEditor(index),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(
                () => _frictions.add(
                  _FrictionInput(type: SystemFrictionType.remove),
                ),
              ),
              icon: const Icon(FluentIcons.add_20_regular),
              label: const Text('Ajouter un réglage d’environnement'),
            ),
          ),
          const SizedBox(height: 8),
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _field(
                  controller: _reward,
                  label: 'Récompense immédiate (facultatif)',
                  hint: 'Un bon thé après ma séance',
                  icon: FluentIcons.gift_20_regular,
                ),
                const SizedBox(height: 6),
                const _Hint(
                  'Ce qui est récompensé est répété : termine sur une note agréable.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _Card(
            padding: EdgeInsets.zero,
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: _editing,
                leading: const Icon(FluentIcons.options_20_regular),
                title: const Text('Options avancées'),
                subtitle: const Text(
                  'État, règles, redevabilité, reprise, révision, notes',
                ),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                children: [_advancedOptions()],
              ),
            ),
          ),
        ],
      );

  Widget _frictionEditor(int index) {
    final friction = _frictions[index];
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<SystemFrictionType>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(
                value: SystemFrictionType.remove,
                label: Text('Faciliter le bon'),
                icon: Icon(FluentIcons.subtract_circle_20_regular),
              ),
              ButtonSegment(
                value: SystemFrictionType.add,
                label: Text('Freiner le mauvais'),
                icon: Icon(FluentIcons.add_circle_20_regular),
              ),
            ],
            selected: {friction.type},
            onSelectionChanged: (value) =>
                setState(() => friction.type = value.first),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _field(
                  controller: friction.text,
                  label: friction.type == SystemFrictionType.remove
                      ? 'Obstacle à retirer'
                      : 'Obstacle à ajouter',
                  hint: friction.type == SystemFrictionType.remove
                      ? 'Laisser le livre sur l’oreiller'
                      : 'Téléphone rangé dans une autre pièce',
                  lines: 2,
                ),
              ),
              IconButton(
                tooltip: 'Retirer',
                onPressed: () => setState(
                  () => _frictions.removeAt(index).dispose(),
                ),
                icon: const Icon(FluentIcons.delete_20_regular),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _advancedOptions() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 4),
          DropdownButtonFormField<LifeSystemStatus>(
            initialValue: _status,
            decoration: _decoration('État'),
            items: LifeSystemStatus.values
                .map(
                  (status) => DropdownMenuItem(
                    value: status,
                    child: Text(status.label),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _priority,
            decoration: _decoration('Priorité'),
            items: const [
              DropdownMenuItem(value: 1, child: Text('1 · Essentiel')),
              DropdownMenuItem(value: 2, child: Text('2 · Important')),
              DropdownMenuItem(value: 3, child: Text('3 · Normal')),
              DropdownMenuItem(value: 4, child: Text('4 · Secondaire')),
              DropdownMenuItem(value: 5, child: Text('5 · Entretien')),
            ],
            onChanged: (value) =>
                setState(() => _priority = value ?? _priority),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _reviewEveryDays,
            decoration: _decoration('Revue du système'),
            items: const [
              DropdownMenuItem(value: 7, child: Text('Chaque semaine')),
              DropdownMenuItem(
                  value: 14, child: Text('Toutes les deux semaines')),
              DropdownMenuItem(value: 30, child: Text('Chaque mois')),
            ],
            onChanged: (value) =>
                setState(() => _reviewEveryDays = value ?? _reviewEveryDays),
          ),
          const SizedBox(height: 12),
          _field(
            controller: _comeback,
            label: 'Règle de reprise',
            hint: _defaultComebackRule,
            lines: 2,
          ),
          const SizedBox(height: 12),
          _field(
            controller: _accountability,
            label: 'Partenaire de redevabilité',
            hint: 'Une personne qui suit tes progrès',
          ),
          const SizedBox(height: 16),
          Text(
            'Règles de vie',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const _Hint('Des décisions prises à l’avance, avant la tentation.'),
          const SizedBox(height: 8),
          for (var index = 0; index < _rules.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _rules[index].text,
                      label: 'Règle ${index + 1}',
                      hint: 'Pas d’écran après 22 h',
                    ),
                  ),
                  Switch.adaptive(
                    value: _rules[index].active,
                    onChanged: (value) =>
                        setState(() => _rules[index].active = value),
                  ),
                  IconButton(
                    onPressed: () =>
                        setState(() => _rules.removeAt(index).dispose()),
                    icon: const Icon(FluentIcons.delete_20_regular),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _rules.add(_RuleInput())),
              icon: const Icon(FluentIcons.add_20_regular),
              label: const Text('Ajouter une règle'),
            ),
          ),
          const SizedBox(height: 8),
          _field(
            controller: _notes,
            label: 'Notes',
            hint: 'Notes libres',
            lines: 3,
          ),
        ],
      );

  TextField _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    int lines = 1,
    bool autofocus = false,
  }) =>
      TextField(
        controller: controller,
        autofocus: autofocus,
        minLines: 1,
        maxLines: lines == 1 ? 1 : lines + 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: _decoration(label).copyWith(
          hintText: hint,
          prefixIcon: icon == null ? null : Icon(icon, size: 20),
        ),
      );

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest
            .withValues(alpha: 0.45),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      );

  // ---------------------------------------------------------------------------
  // Flow
  // ---------------------------------------------------------------------------

  String? _stepError(int step) {
    if (step == 0 && _name.text.trim().isEmpty) {
      return 'Donne un nom à ton système.';
    }
    if (step == 0 && _identity.text.trim().isEmpty) {
      return 'Décris la personne que tu deviens.';
    }
    if (step == 1 &&
        !_victories.any((victory) => victory.title.text.trim().isNotEmpty)) {
      return 'Ajoute au moins une habitude.';
    }
    return null;
  }

  void _showError(String error) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(error)));

  void _next() {
    final error = _stepError(_step);
    if (error != null) {
      _showError(error);
      return;
    }
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() => _step++);
  }

  Future<void> _save() async {
    for (var step = 0; step < 3; step++) {
      final error = _stepError(step);
      if (error != null) {
        if (!_editing) setState(() => _step = step);
        _showError(error);
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final comeback =
          _comeback.text.trim().isEmpty ? _defaultComebackRule : _comeback.text;
      final id = await ref.read(systemsProvider.notifier).save(
            LifeSystemDraft(
              name: _name.text,
              identity: _identity.text,
              status: _status,
              priority: _priority,
              minimumVersion: _minimum.text,
              intention: _intention.text,
              reward: _reward.text,
              accountabilityName: _accountability.text,
              comebackRule: comeback,
              notes: _notes.text,
              reviewEveryDays: _reviewEveryDays,
              victories: _victories
                  .where((item) => item.title.text.trim().isNotEmpty)
                  .map(
                    (item) => SystemVictoryDraft(
                      id: item.id,
                      title: item.title.text,
                      targetCount: item.target,
                      isImportant: item.important,
                      frequency: item.frequency,
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
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop(id);
    } on SystemsLimitException catch (error) {
      if (mounted) _showError(error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
        ),
      );
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
}

class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => GlassSurface(
        showShadow: false,
        borderRadius: BorderRadius.circular(22),
        padding: padding,
        child: Material(color: Colors.transparent, child: child),
      );
}

class _VictoryInput {
  _VictoryInput({
    this.id,
    String title = '',
    this.target = 1,
    this.important = false,
    this.frequency = SystemVictoryFrequency.daily,
  }) : title = TextEditingController(text: title);

  final int? id;
  final TextEditingController title;

  /// Target in the chosen unit (per day when [frequency] is daily).
  int target;
  bool important;
  SystemVictoryFrequency frequency;

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
