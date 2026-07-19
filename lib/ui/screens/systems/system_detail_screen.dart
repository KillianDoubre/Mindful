import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/models/life_system.dart';
import 'package:mindful/providers/systems/systems_provider.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/ui/common/mindful_background.dart';
import 'package:mindful/ui/screens/systems/system_editor_screen.dart';
import 'package:mindful/ui/screens/systems/system_history_screen.dart';
import 'package:mindful/ui/screens/systems/system_review_screen.dart';
import 'package:mindful/ui/screens/systems/systems_tab.dart';

class SystemDetailScreen extends ConsumerWidget {
  const SystemDetailScreen({super.key, required this.systemId});

  final int systemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(systemsProvider);
    LifeSystem? system;
    for (final item in state.valueOrNull ?? const <LifeSystem>[]) {
      if (item.id == systemId) system = item;
    }

    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: .96),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text(system?.name ?? 'Système'),
        actions: [
          if (system != null)
            IconButton(
              tooltip: 'Modifier le système',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SystemEditorScreen(system: system),
                ),
              ),
              icon: const Icon(FluentIcons.edit_20_regular),
            ),
          if (system != null)
            PopupMenuButton<String>(
              tooltip: 'Plus d’options',
              onSelected: (value) => _handleMenu(context, ref, system!, value),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'status',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(FluentIcons.status_20_regular),
                    title: Text('Changer l’état'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(FluentIcons.delete_20_regular,
                        color: colors.error),
                    title: Text('Supprimer',
                        style: TextStyle(color: colors.error)),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MindfulBackground(),
          if (state.isLoading && system == null)
            const Center(child: CircularProgressIndicator())
          else if (system == null)
            const Center(child: Text('Ce système n’existe plus.'))
          else
            _SystemView(system: system),
        ],
      ),
    );
  }

  Future<void> _handleMenu(
    BuildContext context,
    WidgetRef ref,
    LifeSystem system,
    String action,
  ) async {
    if (action == 'status') {
      final status = await showModalBottomSheet<LifeSystemStatus>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 22),
            child: RadioGroup<LifeSystemStatus>(
              groupValue: system.status,
              onChanged: (selected) => Navigator.pop(context, selected),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('État du système',
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  for (final value in LifeSystemStatus.values)
                    RadioListTile<LifeSystemStatus>(
                      value: value,
                      title: Text(value.label),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
      if (status != null) {
        await ref
            .read(systemsProvider.notifier)
            .changeStatus(system.id, status);
      }
      return;
    }

    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer ce système ?'),
            content: const Text(
              'Ses semaines, ses preuves et son historique seront supprimés de cet appareil.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm) return;
    await ref.read(systemsProvider.notifier).delete(system.id);
    if (context.mounted) Navigator.of(context).pop();
  }
}

class _SystemView extends ConsumerWidget {
  const _SystemView({required this.system});

  final LifeSystem system;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 42),
      children: [
        _IdentityHeader(system: system),
        if (system.shouldOfferComeback) ...[
          const SizedBox(height: 12),
          _ComebackCard(system: system),
        ],
        const SizedBox(height: 18),
        _Section(
          icon: FluentIcons.compass_northwest_20_regular,
          title: 'Direction',
          child: Text(system.direction),
        ),
        _Section(
          icon: FluentIcons.person_heart_20_regular,
          title: 'Identité',
          child: Text(system.identity),
        ),
        if (system.nextAction.isNotEmpty)
          _Section(
            icon: FluentIcons.arrow_step_in_right_20_regular,
            title: 'Prochaine action',
            child: Text(system.nextAction),
          ),
        _VictoriesSection(system: system),
        _MinimumSection(system: system),
        if (system.rules.isNotEmpty) _RulesSection(system: system),
        if (system.frictions.isNotEmpty) _FrictionsSection(system: system),
        _Section(
          icon: FluentIcons.people_community_20_regular,
          title: 'Redevabilité',
          child: Text(
            system.accountabilityName.isEmpty
                ? 'Aucune personne définie.'
                : system.accountabilityName,
          ),
        ),
        _Section(
          icon: FluentIcons.arrow_reset_20_regular,
          title: 'Règle de reprise',
          child: Text(system.comebackRule),
        ),
        _ProgressSection(system: system),
        _HistoryPreview(system: system),
        const SizedBox(height: 5),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SystemReviewScreen(systemId: system.id),
            ),
          ),
          icon: const Icon(FluentIcons.clipboard_task_20_regular),
          label: const Text('Faire une revue'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => showComebackSheet(context, ref, system),
          icon: const Icon(FluentIcons.arrow_reset_20_regular),
          label: const Text('J’ai décroché'),
        ),
      ],
    );
  }
}

class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({required this.system});

  final LifeSystem system;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GlassSurface(
      blur: 10,
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              SystemStatusPill(status: system.status),
              _Badge(text: 'Priorité ${system.priority}'),
              _Badge(text: '${system.totalXp} XP'),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      system.evidenceLevel,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${system.completedThisWeek}/${system.targetThisWeek} preuves prévues cette semaine',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(system.momentum * 100).round()} %',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: system.momentum,
              minHeight: 8,
              backgroundColor: colors.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            system.momentumLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _VictoriesSection extends ConsumerWidget {
  const _VictoriesSection({required this.system});

  final LifeSystem system;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Section(
        icon: FluentIcons.trophy_20_regular,
        title: 'Victoires de la semaine',
        child: system.victories.isEmpty
            ? const Text('Aucune victoire définie.')
            : Column(
                children: [
                  for (var index = 0;
                      index < system.victories.length;
                      index++) ...[
                    if (index > 0) const Divider(height: 18),
                    _VictoryRow(
                        system: system, victory: system.victories[index]),
                  ],
                ],
              ),
      );
}

class _VictoryRow extends ConsumerWidget {
  const _VictoryRow({required this.system, required this.victory});

  final LifeSystem system;
  final SystemVictory victory;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
        children: [
          Icon(
            victory.isCompleted
                ? FluentIcons.checkmark_circle_20_filled
                : FluentIcons.circle_20_regular,
            color: victory.isCompleted
                ? Theme.of(context).colorScheme.primary
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(victory.title),
                Text(
                  '${victory.completedCount} sur ${victory.targetCount}${victory.isImportant ? ' · importante' : ''}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Retirer une occurrence',
            onPressed: victory.completedCount <= 0
                ? null
                : () => ref.read(systemsProvider.notifier).setVictoryProgress(
                      system.id,
                      victory,
                      victory.completedCount - 1,
                    ),
            icon: const Icon(FluentIcons.subtract_16_regular),
          ),
          const SizedBox(width: 5),
          IconButton.filled(
            tooltip: 'Ajouter une occurrence',
            onPressed: victory.completedCount >= victory.targetCount
                ? null
                : () => ref.read(systemsProvider.notifier).setVictoryProgress(
                      system.id,
                      victory,
                      victory.completedCount + 1,
                    ),
            icon: const Icon(FluentIcons.add_16_regular),
          ),
        ],
      );
}

class _MinimumSection extends ConsumerWidget {
  const _MinimumSection({required this.system});

  final LifeSystem system;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Section(
        icon: FluentIcons.sparkle_20_regular,
        title: 'Version minimale',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(system.minimumVersion),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: system.currentWeek.minimumUsed
                  ? null
                  : () => ref
                      .read(systemsProvider.notifier)
                      .completeMinimumVersion(system.id),
              icon: Icon(
                system.currentWeek.minimumUsed
                    ? FluentIcons.checkmark_20_filled
                    : FluentIcons.play_20_regular,
              ),
              label: Text(
                system.currentWeek.minimumUsed
                    ? 'Utilisée cette semaine'
                    : 'J’ai réalisé la version minimale',
              ),
            ),
          ],
        ),
      );
}

class _RulesSection extends ConsumerWidget {
  const _RulesSection({required this.system});

  final LifeSystem system;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Section(
        icon: FluentIcons.shield_task_20_regular,
        title: 'Règles de vie',
        child: Column(
          children: system.rules
              .map(
                (rule) => SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(rule.text),
                  value: rule.isActive,
                  onChanged: (_) => ref
                      .read(systemsProvider.notifier)
                      .toggleRule(system.id, rule),
                ),
              )
              .toList(),
        ),
      );
}

class _FrictionsSection extends ConsumerWidget {
  const _FrictionsSection({required this.system});

  final LifeSystem system;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _Section(
        icon: FluentIcons.settings_cog_multiple_20_regular,
        title: 'Frictions',
        child: Column(
          children: system.frictions
              .map(
                (friction) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Icon(
                        friction.type == SystemFrictionType.remove
                            ? FluentIcons.subtract_circle_20_regular
                            : FluentIcons.add_circle_20_regular,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(friction.text),
                            Text(
                              friction.type.label,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      DropdownButton<SystemFrictionStatus>(
                        value: friction.status,
                        underline: const SizedBox.shrink(),
                        items: SystemFrictionStatus.values
                            .map(
                              (status) => DropdownMenuItem(
                                value: status,
                                child: Text(status.label),
                              ),
                            )
                            .toList(),
                        onChanged: (status) {
                          if (status != null) {
                            ref
                                .read(systemsProvider.notifier)
                                .changeFrictionStatus(
                                  system.id,
                                  friction,
                                  status,
                                );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      );
}

class _ProgressSection extends StatelessWidget {
  const _ProgressSection({required this.system});

  final LifeSystem system;

  @override
  Widget build(BuildContext context) => _Section(
        icon: FluentIcons.sparkle_20_regular,
        title: 'Preuves accumulées',
        child: Row(
          children: [
            Expanded(
              child: _Metric(
                value: '${system.totalXp}',
                label: 'XP local',
              ),
            ),
            Expanded(
              child: _Metric(
                value: system.evidenceLevel,
                label: 'Phase du système',
              ),
            ),
          ],
        ),
      );
}

class _HistoryPreview extends StatelessWidget {
  const _HistoryPreview({required this.system});

  final LifeSystem system;

  @override
  Widget build(BuildContext context) => _Section(
        icon: FluentIcons.history_20_regular,
        title: 'Historique',
        trailing: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => SystemHistoryScreen(systemId: system.id),
            ),
          ),
          child: const Text('Tout voir'),
        ),
        child: system.recentEvents.isEmpty
            ? const Text('Les changements importants apparaîtront ici.')
            : Column(
                children: system.recentEvents
                    .take(4)
                    .map(
                      (event) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(_eventIcon(event.type)),
                        title: Text(event.title),
                        subtitle:
                            event.details.isEmpty ? null : Text(event.details),
                        trailing: event.xp > 0 ? Text('+${event.xp} XP') : null,
                      ),
                    )
                    .toList(),
              ),
      );
}

class _ComebackCard extends ConsumerWidget {
  const _ComebackCard({required this.system});

  final LifeSystem system;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GlassSurface(
        showShadow: false,
        color: Theme.of(context).colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(24),
        padding: const EdgeInsets.all(17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(FluentIcons.arrow_reset_20_filled),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ce système semble plus difficile en ce moment.',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                      'Tu peux le simplifier sans perdre les preuves déjà acquises.'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.tonal(
                        onPressed: () =>
                            showComebackSheet(context, ref, system),
                        child: const Text('Reprendre'),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(systemsProvider.notifier)
                            .changeStatus(system.id, LifeSystemStatus.paused),
                        child: const Text('Mettre en pause'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

Future<void> showComebackSheet(
  BuildContext context,
  WidgetRef ref,
  LifeSystem system,
) async {
  const difficulties = [
    'Objectif trop difficile',
    'Manque d’énergie',
    'Mauvais horaire',
    'Prochaine action imprécise',
    'Friction environnementale',
    'Manque de sens',
    'Manque de pression extérieure',
    'Objectif ou méthode mal choisis',
    'Autre',
  ];
  const actions = [
    'Réduire temporairement la cible',
    'Utiliser la version minimale',
    'Changer l’horaire',
    'Modifier une friction',
    'Définir une prochaine action',
    'Ajouter une personne de redevabilité',
    'Passer le système en entretien',
    'Mettre le système en pause',
    'Planifier une date de révision',
  ];
  var difficulty = difficulties.first;
  var action = actions.first;
  final confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            0,
            18,
            18 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Reprendre sans rattraper',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 5),
                const Text(
                    'Qu’est-ce qui rend ce système difficile actuellement ?'),
                const SizedBox(height: 12),
                RadioGroup<String>(
                  groupValue: difficulty,
                  onChanged: (selected) =>
                      setSheetState(() => difficulty = selected ?? difficulty),
                  child: Column(
                    children: difficulties
                        .map(
                          (value) => RadioListTile<String>(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            value: value,
                            title: Text(value),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: action,
                  decoration: const InputDecoration(
                    labelText: 'Ajustement choisi',
                    border: OutlineInputBorder(),
                  ),
                  items: actions
                      .map((value) =>
                          DropdownMenuItem(value: value, child: Text(value)))
                      .toList(),
                  onChanged: (selected) =>
                      setSheetState(() => action = selected ?? action),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  icon: const Icon(FluentIcons.arrow_reset_20_regular),
                  label: const Text('Engager la reprise'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: const Text('Pas maintenant'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  if (confirmed == true) {
    await ref.read(systemsProvider.notifier).recordComeback(
          systemId: system.id,
          difficulty: difficulty,
          action: action,
        );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GlassSurface(
          showShadow: false,
          borderRadius: BorderRadius.circular(24),
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon,
                      size: 20, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(text, style: Theme.of(context).textTheme.labelMedium),
      );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      );
}

IconData _eventIcon(SystemEventType type) => switch (type) {
      SystemEventType.weeklyVictory => FluentIcons.trophy_20_regular,
      SystemEventType.minimumVersion => FluentIcons.sparkle_20_regular,
      SystemEventType.focusSession => FluentIcons.timer_20_regular,
      SystemEventType.comeback => FluentIcons.arrow_reset_20_regular,
      SystemEventType.review => FluentIcons.clipboard_task_20_regular,
      SystemEventType.frictionImproved => FluentIcons.settings_20_regular,
      SystemEventType.accountability => FluentIcons.people_20_regular,
      SystemEventType.milestone => FluentIcons.flag_20_regular,
      SystemEventType.interruption => FluentIcons.pause_20_regular,
      SystemEventType.statusChanged => FluentIcons.status_20_regular,
      SystemEventType.systemChanged => FluentIcons.edit_20_regular,
    };
