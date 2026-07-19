import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mindful/core/services/systems_repository.dart';
import 'package:mindful/models/life_system.dart';
import 'package:mindful/providers/systems/systems_provider.dart';
import 'package:mindful/ui/common/default_fab_button.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/ui/common/sliver_tabs_bottom_padding.dart';
import 'package:mindful/ui/screens/systems/system_detail_screen.dart';
import 'package:mindful/ui/screens/systems/system_editor_screen.dart';

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
          SliverToBoxAdapter(
            child: systems.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (_, __) => _LoadError(
                onRetry: ref.read(systemsProvider.notifier).refresh,
              ),
              data: (items) => _SystemsSummary(systems: items),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          ...systems.when(
            loading: () => const <Widget>[],
            error: (_, __) => const <Widget>[],
            data: (items) => items.isEmpty
                ? [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _EmptySystems(
                          onCreate: () => openSystemEditor(context, ref)),
                    ),
                  ]
                : [
                    SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 11),
                        child: SystemCard(
                          system: items[index],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => SystemDetailScreen(
                                systemId: items[index].id,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
          ),
          const SliverTabsBottomPadding(),
        ],
      ),
    );
  }
}

class SystemsAddFab extends ConsumerWidget {
  const SystemsAddFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultFabButton(
        heroTag: 'newSystemFab',
        label: 'Nouveau système',
        icon: FluentIcons.add_20_filled,
        onPressed: () => openSystemEditor(context, ref),
      );
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
            'Vous avez atteint la limite de cinq systèmes. Supprimez-en un pour en créer un autre.',
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
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SystemDetailScreen(systemId: createdId),
      ),
    );
  }
}

class SystemsNextActionCard extends ConsumerWidget {
  const SystemsNextActionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(systemsProvider);
    return state.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (systems) {
        if (systems.isEmpty) {
          return _CreateFirstSystemCard(
            onTap: () => openSystemEditor(context, ref),
          );
        }
        LifeSystem? selected;
        for (final system in systems) {
          final canAct = system.status == LifeSystemStatus.active ||
              system.status == LifeSystemStatus.maintenance;
          if (canAct && system.nextAction.trim().isNotEmpty) {
            selected = system;
            break;
          }
        }
        if (selected == null) {
          for (final system in systems) {
            final canAct = system.status == LifeSystemStatus.active ||
                system.status == LifeSystemStatus.maintenance;
            if (canAct && system.minimumVersion.trim().isNotEmpty) {
              selected = system;
              break;
            }
          }
        }
        if (selected == null) return const SizedBox.shrink();
        final system = selected;
        final action = system.nextAction.trim().isNotEmpty
            ? system.nextAction
            : system.minimumVersion;
        final colors = Theme.of(context).colorScheme;
        return GlassSurface(
          showShadow: false,
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SystemDetailScreen(systemId: system.id),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(17),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        FluentIcons.arrow_step_in_right_20_filled,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Prochaine action réelle',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: colors.primary),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            action,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            system.name,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Icon(FluentIcons.chevron_right_20_regular),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CreateFirstSystemCard extends StatelessWidget {
  const _CreateFirstSystemCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return GlassSurface(
      showShadow: false,
      color: colors.primaryContainer,
      borderRadius: BorderRadius.circular(24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: SvgPicture.asset(
                    'assets/vectors/systems.svg',
                    width: 21,
                    height: 21,
                    colorFilter: ColorFilter.mode(
                      colors.primary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Systèmes',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: colors.primary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Créer mon premier système',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                      ),
                    ],
                  ),
                ),
                const Icon(FluentIcons.chevron_right_20_regular),
              ],
            ),
          ),
        ),
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
    final colors = Theme.of(context).colorScheme;
    final target = system.targetThisWeek;
    return GlassSurface(
      showShadow: false,
      borderRadius: BorderRadius.circular(24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            system.name,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -.35,
                                ),
                          ),
                          const SizedBox(height: 7),
                          Wrap(
                            spacing: 7,
                            runSpacing: 7,
                            children: [
                              SystemStatusPill(status: system.status),
                              _SoftPill(
                                icon: FluentIcons.sparkle_20_regular,
                                label:
                                    '${system.totalXp} XP · ${system.evidenceLevel}',
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(FluentIcons.chevron_right_20_regular),
                  ],
                ),
                if (system.nextAction.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'Prochaine action',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Text(system.nextAction,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        target == 0
                            ? 'Aucune victoire définie'
                            : '${system.completedThisWeek} sur $target cette semaine',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      system.momentumLabel,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    minHeight: 7,
                    value: system.status == LifeSystemStatus.paused
                        ? system.momentum
                        : system.currentWeekRatio,
                    backgroundColor: colors.surfaceContainerHighest,
                  ),
                ),
              ],
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.status, required this.count});

  final LifeSystemStatus status;
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          '${status.label} · $count',
          style: Theme.of(context).textTheme.labelMedium,
        ),
      );
}

class _SoftPill extends StatelessWidget {
  const _SoftPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(50),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 5),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
      );
}

class _SystemsSummary extends StatelessWidget {
  const _SystemsSummary({required this.systems});

  final List<LifeSystem> systems;

  @override
  Widget build(BuildContext context) => GlassSurface(
        showShadow: false,
        padding: const EdgeInsets.all(17),
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Des preuves, pas des séries.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              systems.isEmpty
                  ? 'Construisez un environnement qui rend l’action réelle plus simple.'
                  : '${systems.length}/5 systèmes · chacun conserve son propre rythme.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (systems.isNotEmpty) ...[
              const SizedBox(height: 13),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: LifeSystemStatus.values
                    .map(
                      (status) => _CountPill(
                        status: status,
                        count: systems.where((s) => s.status == status).length,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      );
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
              SvgPicture.asset(
                'assets/vectors/systems.svg',
                width: 58,
                height: 58,
                colorFilter: ColorFilter.mode(
                  Theme.of(context).colorScheme.primary,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Quel système veux-tu construire ?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Commence par une direction, une identité observable et quelques victoires contrôlables.',
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
