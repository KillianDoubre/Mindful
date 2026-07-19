import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mindful/models/life_system.dart';
import 'package:mindful/providers/systems/systems_provider.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/ui/common/mindful_background.dart';

class SystemHistoryScreen extends ConsumerStatefulWidget {
  const SystemHistoryScreen({super.key, required this.systemId});

  final int systemId;

  @override
  ConsumerState<SystemHistoryScreen> createState() =>
      _SystemHistoryScreenState();
}

class _SystemHistoryScreenState extends ConsumerState<SystemHistoryScreen> {
  bool _showWeeks = true;

  @override
  Widget build(BuildContext context) {
    LifeSystem? system;
    for (final item
        in ref.watch(systemsProvider).valueOrNull ?? const <LifeSystem>[]) {
      if (item.id == widget.systemId) system = item;
    }
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: colors.surface.withValues(alpha: .96),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text('Historique'),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MindfulBackground(),
          if (system == null)
            const Center(child: CircularProgressIndicator())
          else
            ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
              children: [
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: true,
                      icon: Icon(FluentIcons.calendar_week_numbers_20_regular),
                      label: Text('Semaines'),
                    ),
                    ButtonSegment(
                      value: false,
                      icon: Icon(FluentIcons.history_20_regular),
                      label: Text('Événements'),
                    ),
                  ],
                  selected: {_showWeeks},
                  onSelectionChanged: (value) =>
                      setState(() => _showWeeks = value.first),
                ),
                const SizedBox(height: 14),
                if (_showWeeks)
                  ...system.recentWeeks.map((week) => _WeekCard(week: week))
                else if (system.recentEvents.isEmpty)
                  const _EmptyHistory()
                else
                  ...system.recentEvents
                      .map((event) => _EventCard(event: event)),
              ],
            ),
        ],
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.week});

  final SystemWeek week;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final formatter = DateFormat('d MMM', 'fr');
    final isCurrent = week.weekStart == systemWeekStart(DateTime.now());
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: GlassSurface(
        showShadow: false,
        padding: const EdgeInsets.all(17),
        borderRadius: BorderRadius.circular(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Du ${formatter.format(week.weekStart)} au ${formatter.format(week.weekEnd)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('En cours'),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
                '${week.completedCount} sur ${week.targetCount} victoires prévues'),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: week.completionRatio,
                minHeight: 7,
                backgroundColor: colors.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _WeekBadge(text: week.statusAtEnd.label),
                if (week.minimumUsed)
                  const _WeekBadge(text: 'Version minimale utilisée'),
                if (week.interruptionCount > 0)
                  _WeekBadge(text: '${week.interruptionCount} interruption'),
                if (week.comebackCount > 0)
                  _WeekBadge(text: '${week.comebackCount} reprise'),
              ],
            ),
            if (week.reflection.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'Réflexion',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(week.reflection),
            ],
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final SystemEvent event;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat("d MMM · HH'h'mm", 'fr');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassSurface(
        showShadow: false,
        padding: const EdgeInsets.all(15),
        borderRadius: BorderRadius.circular(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(_icon(event.type), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.title,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                      if (event.xp > 0)
                        Text(
                          '+${event.xp} XP',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    formatter.format(event.occurredAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (event.details.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(event.details),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon(SystemEventType type) => switch (type) {
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
}

class _WeekBadge extends StatelessWidget {
  const _WeekBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: Theme.of(context).textTheme.labelMedium),
      );
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: Text('Les preuves et ajustements apparaîtront ici.'),
        ),
      );
}
