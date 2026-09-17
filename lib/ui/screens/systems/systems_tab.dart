import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/core/services/systems_repository.dart';
import 'package:mindful/models/life_system.dart';
import 'package:mindful/providers/systems/systems_provider.dart';
import 'package:mindful/ui/common/default_fab_button.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/ui/common/sliver_tabs_bottom_padding.dart';
import 'package:mindful/ui/screens/systems/system_detail_screen.dart';
import 'package:mindful/ui/screens/systems/system_editor_screen.dart';
import 'package:mindful/ui/screens/systems/system_widgets.dart';

/// Systems home, built around Atomic Habits: what to do today first, then
/// the identities being built.
class SystemsTab extends ConsumerWidget {
  const SystemsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systems = ref.watch(systemsProvider);
    return RefreshIndicator(
      onRefresh: ref.read(systemsProvider.notifier).refresh,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          ...systems.when(
            loading: () => const [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
            error: (_, __) => [
              SliverToBoxAdapter(
                child: _LoadError(
                  onRetry: ref.read(systemsProvider.notifier).refresh,
                ),
              ),
            ],
            data: (items) => items.isEmpty
                ? [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptySystems(
                        onCreate: () => openSystemEditor(context, ref),
                      ),
                    ),
                  ]
                : _content(context, items),
          ),
          const SliverTabsBottomPadding(),
        ],
      ),
    );
  }

  List<Widget> _content(BuildContext context, List<LifeSystem> systems) {
    final playable = systems
        .where((system) => system.isPlayable && system.victories.isNotEmpty)
        .toList();
    return [
      if (playable.isNotEmpty) ...[
        SliverToBoxAdapter(child: _TodayHub(systems: playable)),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
      ],
      const SliverToBoxAdapter(child: _SectionLabel('Tes identités')),
      SliverList.builder(
        itemCount: systems.length,
        itemBuilder: (context, index) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SystemCard(
            system: systems[index],
            onTap: () => openSystemDetail(context, systems[index].id),
          ),
        ),
      ),
    ];
  }
}

void openSystemDetail(BuildContext context, int systemId) =>
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SystemDetailScreen(systemId: systemId),
      ),
    );

class SystemsAddFab extends ConsumerWidget {
  const SystemsAddFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The empty state already shows its own create button.
    final isEmpty = ref.watch(
      systemsProvider.select((systems) => systems.valueOrNull?.isEmpty ?? true),
    );
    if (isEmpty) return const SizedBox.shrink();
    return DefaultFabButton(
      heroTag: 'newSystemFab',
      label: 'Nouveau système',
      icon: FluentIcons.add_20_filled,
      onPressed: () => openSystemEditor(context, ref),
    );
  }
}

Future<void> openSystemEditor(
  BuildContext context,
  WidgetRef ref, {
  LifeSystem? system,
}) async {
  final count = ref.read(systemsProvider).valueOrNull?.length ?? 0;
  if (system == null && count >= SystemsRepository.maximumSystems) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Cinq systèmes au maximum : mieux vaut peu d’habitudes bien ancrées. Supprimes-en un pour en créer un autre.',
          ),
        ),
      );
    return;
  }
  final createdId = await Navigator.of(context).push<int>(
    MaterialPageRoute<int>(
      builder: (_) => SystemEditorScreen(system: system),
    ),
  );
  if (system == null && createdId != null && context.mounted) {
    openSystemDetail(context, createdId);
  }
}

/// "Aujourd'hui": the daily check-in across every running system.
class _TodayHub extends StatelessWidget {
  const _TodayHub({required this.systems});

  final List<LifeSystem> systems;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    var dailyGoal = 0;
    var dailyDone = 0;
    var votesToday = 0;
    var weeklyTarget = 0;
    var weeklyDone = 0;
    for (final system in systems) {
      votesToday += system.todayVotes.values.fold(0, (a, b) => a + b);
      for (final victory in system.victories) {
        if (victory.frequency == SystemVictoryFrequency.daily) {
          dailyGoal += victory.perPeriodTarget;
          dailyDone +=
              system.todayVotesFor(victory).clamp(0, victory.perPeriodTarget);
        } else {
          weeklyTarget += victory.targetCount;
          weeklyDone += victory.completedCount.clamp(0, victory.targetCount);
        }
      }
    }
    final progress = dailyGoal > 0
        ? dailyDone / dailyGoal
        : weeklyTarget == 0
            ? 0.0
            : weeklyDone / weeklyTarget;
    final isAllDone = progress >= 1;
    final atRisk = systems.where((system) => system.isStreakAtRisk).toList();

    return GlassSurface(
      borderRadius: BorderRadius.circular(28),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProgressRing(
                progress: progress,
                child: isAllDone
                    ? Icon(
                        FluentIcons.checkmark_starburst_24_filled,
                        color: colors.primary,
                        size: 34,
                      )
                    : Text(
                        '${(progress * 100).round()}%',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Aujourd’hui',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isAllDone
                          ? 'Journée gagnée · $votesToday vote${votesToday > 1 ? 's' : ''}'
                          : votesToday == 0
                              ? 'Un seul vote suffit pour lancer la journée'
                              : '$votesToday vote${votesToday > 1 ? 's' : ''} · continue sur ta lancée',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (atRisk.isNotEmpty) ...[
            const SizedBox(height: 14),
            _NeverMissTwiceBanner(systems: atRisk),
          ],
          for (final system in systems) ...[
            const SizedBox(height: 16),
            InkWell(
              onTap: () => openSystemDetail(context, system.id),
              borderRadius: BorderRadius.circular(10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      system.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StreakBadge(system: system, compact: true),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final victory in system.victories)
                  VoteChip(system: system, victory: victory),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const VoteHint(),
        ],
      ),
    );
  }
}

class _NeverMissTwiceBanner extends StatelessWidget {
  const _NeverMissTwiceBanner({required this.systems});

  final List<LifeSystem> systems;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final names = systems.map((system) => system.name).join(', ');
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.fire_20_filled, color: colors.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ne rate pas deux fois : un seul vote aujourd’hui sauve ta série ($names). La version 2 minutes compte.',
              style: TextStyle(
                color: colors.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SystemCard extends StatelessWidget {
  const SystemCard({super.key, required this.system, required this.onTap});

  final LifeSystem system;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final identity = system.identity.trim();
    final target = system.targetThisWeek;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: system.isPlayable ? 1 : 0.6,
      child: GlassSurface(
        showShadow: false,
        borderRadius: BorderRadius.circular(26),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(26),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LevelRing(system: system, size: 52),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              system.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.35,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              system.evidenceLevel +
                                  (system.isMaxLevel
                                      ? ''
                                      : ' · ${system.xpToNextLevel} XP avant « ${system.nextLevelName} »'),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      StreakBadge(system: system),
                    ],
                  ),
                  if (identity.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '« $identity »',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  ChainDots(system: system),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (!system.isPlayable) ...[
                        SystemStatusPill(status: system.status),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          target == 0
                              ? 'Aucune victoire définie'
                              : '${system.completedThisWeek}/$target votes cette semaine',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Text(
                        '${system.totalVotes} votes',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      minHeight: 5,
                      value: system.currentWeekRatio,
                      backgroundColor: colors.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SystemStatusPill extends StatelessWidget {
  const SystemStatusPill({super.key, required this.status});

  final LifeSystemStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final color = switch (status) {
      LifeSystemStatus.active => colors.primary,
      LifeSystemStatus.maintenance => colors.tertiary,
      LifeSystemStatus.paused => colors.outline,
      LifeSystemStatus.draft => colors.secondary,
      LifeSystemStatus.archived => colors.onSurfaceVariant,
    };
    return SoftPill(label: status.label, color: color);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 0, 6, 10),
        child: Text(
          label.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
        ),
      );
}

/// Systems summary card ("Mes systèmes") used on the home dashboard.
/// Watches [systemsProvider] and, when [onTap] is provided, becomes a
/// tappable shortcut (e.g. to switch to the Systems tab).
class SystemsSummaryCard extends ConsumerWidget {
  const SystemsSummaryCard({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(systemsProvider);
    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (systems) => _SystemsSummary(systems: systems, onTap: onTap),
    );
  }
}

class _SystemsSummary extends StatelessWidget {
  const _SystemsSummary({required this.systems, this.onTap});

  final List<LifeSystem> systems;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final votesToday = systems.fold<int>(
      0,
      (sum, system) => sum + system.todayVotes.values.fold(0, (a, b) => a + b),
    );
    final bestStreak = systems.fold<int>(
      0,
      (best, system) => system.streakDays > best ? system.streakDays : best,
    );
    final atRisk = systems.any((system) => system.isStreakAtRisk);

    final content = Row(
      children: [
        Icon(
          FluentIcons.leaf_two_24_regular,
          size: 34,
          color: colors.primary,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mes systèmes',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                systems.isEmpty
                    ? 'Deviens la personne que tu veux être, un vote à la fois.'
                    : atRisk
                        ? 'Ne rate pas deux fois : un vote aujourd’hui sauve ta série.'
                        : votesToday == 0
                            ? 'Aucun vote aujourd’hui pour l’instant.'
                            : '$votesToday vote${votesToday > 1 ? 's' : ''} aujourd’hui',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: atRisk ? colors.error : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (bestStreak > 0) ...[
          const SizedBox(width: 8),
          SoftPill(
            icon: FluentIcons.fire_20_filled,
            label: '$bestStreak j',
            color: const Color(0xFFFF8A3D),
          ),
        ],
        if (onTap != null)
          const Padding(
            padding: EdgeInsets.only(left: 6),
            child: Icon(FluentIcons.chevron_right_20_regular),
          ),
      ],
    );

    return GlassSurface(
      showShadow: false,
      padding: onTap == null ? const EdgeInsets.all(17) : EdgeInsets.zero,
      borderRadius: BorderRadius.circular(24),
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(17),
                  child: content,
                ),
              ),
            ),
    );
  }
}

class _EmptySystems extends StatelessWidget {
  const _EmptySystems({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.leaf_two_24_regular,
                size: 58,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Qui veux-tu devenir ?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Chaque action est un vote pour cette personne. Commence par une identité et une toute petite habitude.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(FluentIcons.add_20_filled),
                label: const Text('Créer mon premier système'),
              ),
            ],
          ),
        ),
      );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => GlassSurface(
        showShadow: false,
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Text('Impossible de charger les systèmes.'),
            TextButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      );
}
