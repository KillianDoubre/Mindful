import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/models/life_system.dart';
import 'package:mindful/providers/systems/systems_provider.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/ui/common/mindful_background.dart';
import 'package:mindful/ui/screens/systems/system_editor_screen.dart';
import 'package:mindful/ui/screens/systems/system_history_screen.dart';
import 'package:mindful/ui/screens/systems/system_review_screen.dart';
import 'package:mindful/ui/screens/systems/system_widgets.dart';
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
    return Stack(
      fit: StackFit.expand,
      children: [
        const MindfulBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
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
                  onSelected: (value) =>
                      _handleMenu(context, ref, system!, value),
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
          body: BackdropGroup(
            child: state.isLoading && system == null
                ? const Center(child: CircularProgressIndicator())
                : system == null
                    ? const Center(child: Text('Ce système n’existe plus.'))
                    : _SystemView(system: system),
          ),
        ),
      ],
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
    final intention = system.intention.trim();
    final reward = system.reward.trim();
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 42),
      children: [
        _IdentityHero(system: system),
        if (system.isStreakAtRisk) ...[
          const SizedBox(height: 12),
          _NeverMissTwiceCard(system: system),
        ] else if (system.shouldOfferComeback) ...[
          const SizedBox(height: 12),
          _ComebackCard(system: system),
        ],
        const SizedBox(height: 14),
        if (system.victories.isNotEmpty)
          _Section(
            icon: FluentIcons.checkmark_starburst_20_regular,
            title: 'Voter aujourd’hui',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final victory in system.victories)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: VoteChip(
                      system: system,
                      victory: victory,
                      expanded: true,
                    ),
                  ),
                const VoteHint(),
              ],
            ),
          ),
        _MinimumSection(system: system),
        if (intention.isNotEmpty)
          _Section(
            icon: FluentIcons.link_20_regular,
            title: 'Intention · rends-le évident',
            child: Text(
              intention,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        if (system.frictions.isNotEmpty) _FrictionsSection(system: system),
        if (reward.isNotEmpty)
          _Section(
            icon: FluentIcons.gift_20_regular,
            title: 'Récompense · rends-le satisfaisant',
            child: Text(
              reward,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        if (system.rules.isNotEmpty) _RulesSection(system: system),
        if (system.accountabilityName.trim().isNotEmpty)
          _Section(
            icon: FluentIcons.people_community_20_regular,
            title: 'Partenaire de redevabilité',
            child: Text(system.accountabilityName),
          ),
        if (system.comebackRule.trim().isNotEmpty)
          _Section(
            icon: FluentIcons.arrow_reset_20_regular,
            title: 'Règle de reprise',
            child: Text(system.comebackRule),
          ),
        if (system.notes.trim().isNotEmpty)
          _Section(
            icon: FluentIcons.note_20_regular,
            title: 'Notes',
            child: Text(system.notes),
          ),
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

/// Who the user is becoming, and the evidence so far.
class _IdentityHero extends StatelessWidget {
  const _IdentityHero({required this.system});

  final LifeSystem system;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final identity = system.identity.trim();
    return GlassSurface(
      borderRadius: BorderRadius.circular(30),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LevelRing(system: system, size: 72),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      system.evidenceLevel,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      system.isMaxLevel
                          ? 'Niveau maximal atteint'
                          : '${system.xpToNextLevel} XP avant « ${system.nextLevelName} »',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        StreakBadge(system: system, compact: true),
                        if (!system.isPlayable)
                          SystemStatusPill(status: system.status),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (identity.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Je suis quelqu’un qui…',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              identity,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
          ],
          const SizedBox(height: 18),
          ChainDots(system: system),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  value: '${system.totalVotes}',
                  label: 'votes pour ton identité',
                ),
              ),
              Expanded(
                child: _Metric(
                  value: '${system.lifetimeActiveDays}',
                  label: 'jours actifs',
                ),
              ),
              Expanded(
                child: _Metric(
                  value: formatGrowth(system.compoundedGrowth),
                  label: 'à 1 % par jour',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            dailyHabitQuote(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _NeverMissTwiceCard extends ConsumerWidget {
  const _NeverMissTwiceCard({required this.system});

  final LifeSystem system;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return GlassSurface(
      showShadow: false,
      color: colors.errorContainer.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(FluentIcons.fire_24_filled, color: colors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ne rate pas deux fois',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hier a été manqué. Ta série de ${system.streakDays} jours tient à un seul vote aujourd’hui, même minuscule.',
                ),
                if (system.minimumVersion.trim().isNotEmpty &&
                    !system.currentWeek.minimumUsed) ...[
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    onPressed: () => ref
                        .read(systemsProvider.notifier)
                        .completeMinimumVersion(system.id),
                    icon: const Icon(FluentIcons.timer_2_20_regular),
                    label: const Text('Faire la version 2 minutes'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimumSection extends ConsumerWidget {
  const _MinimumSection({required this.system});

  final LifeSystem system;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minimum = system.minimumVersion.trim();
    if (minimum.isEmpty) return const SizedBox.shrink();
    final used = system.currentWeek.minimumUsed;
    return _Section(
      icon: FluentIcons.timer_2_20_regular,
      title: 'Version 2 minutes · rends-le facile',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(minimum, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Pour les jours sans énergie : se présenter compte plus que la performance.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: used || !system.isPlayable
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    ref
                        .read(systemsProvider.notifier)
                        .completeMinimumVersion(system.id);
                  },
            icon: Icon(
              used
                  ? FluentIcons.checkmark_20_filled
                  : FluentIcons.play_20_regular,
            ),
            label: Text(
              used ? 'Faite cette semaine' : 'J’ai fait la version 2 minutes',
            ),
          ),
        ],
      ),
    );
  }
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
        title: 'Environnement · frictions',
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
                        trailing: event.xp > 0
                            ? SoftPill(
                                label: '+${event.xp} XP',
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
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
