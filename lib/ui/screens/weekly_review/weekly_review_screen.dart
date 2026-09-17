/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/config/navigation/app_routes.dart';
import 'package:mindful/core/services/weekly_review_repository.dart';
import 'package:mindful/models/weekly_review.dart';
import 'package:mindful/providers/apps/apps_info_provider.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/ui/common/mindful_background.dart';
import 'package:mindful/ui/common/page_app_bar.dart';

/// The Sunday review: a whole-week summary across every module, and a short
/// reflection saved with a snapshot of the numbers.
class WeeklyReviewScreen extends StatefulWidget {
  const WeeklyReviewScreen({super.key, this.weekStart});

  /// Week to review; the current one by default.
  final DateTime? weekStart;

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  final _repository = WeeklyReviewRepository.instance;
  final _wins = TextEditingController();
  final _adjustments = TextEditingController();
  final _intention = TextEditingController();

  late DateTime _weekStart;
  WeeklyStats? _stats;
  WeeklyReview? _saved;
  int _rating = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  bool get _isCurrentWeek => _weekStart == weekStartOf(DateTime.now());

  @override
  void initState() {
    super.initState();
    _weekStart = weekStartOf(widget.weekStart ?? DateTime.now());
    _load();
  }

  @override
  void dispose() {
    _wins.dispose();
    _adjustments.dispose();
    _intention.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final saved = await _repository.load(_weekStart);
    // A past week keeps the numbers frozen at review time; the current week
    // is always measured live
    final stats = saved != null && !_isCurrentWeek
        ? saved.stats
        : await _repository.computeStats(_weekStart);
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _stats = stats;
      _rating = saved?.rating ?? 0;
      _wins.text = saved?.wins ?? '';
      _adjustments.text = saved?.adjustments ?? '';
      _intention.text = saved?.intention ?? '';
      _isLoading = false;
    });
  }

  void _changeWeek(int weeks) {
    final next = DateTime(
      _weekStart.year,
      _weekStart.month,
      _weekStart.day + 7 * weeks,
    );
    if (next.isAfter(weekStartOf(DateTime.now()))) return;
    _weekStart = next;
    _load();
  }

  Future<void> _save() async {
    final stats = _stats;
    if (stats == null) return;
    setState(() => _isSaving = true);
    await _repository.save(
      stats: stats,
      rating: _rating,
      wins: _wins.text,
      adjustments: _adjustments.text,
      intention: _intention.text,
    );
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Bilan enregistré. Belle semaine à venir !')),
      );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final stats = _stats;
    return Stack(
      fit: StackFit.expand,
      children: [
        const MindfulBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PageAppBar(
            title: const Text('Bilan de la semaine'),
            actions: [
              IconButton(
                tooltip: 'Historique des bilans',
                onPressed: () => Navigator.of(context)
                    .pushNamed(AppRoutes.weeklyReviewHistoryPath),
                icon: const Icon(FluentIcons.history_20_regular),
              ),
            ],
          ),
          body: BackdropGroup(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _WeekSwitcher(
                  weekStart: _weekStart,
                  isSaved: _saved != null,
                  canGoForward: !_isCurrentWeek,
                  onPrevious: () => _changeWeek(-1),
                  onNext: () => _changeWeek(1),
                ),
                const SizedBox(height: 14),
                if (_isLoading || stats == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else ...[
                  WeeklyStatsView(stats: stats),
                  const SizedBox(height: 18),
                  _ReflectionCard(
                    rating: _rating,
                    onRatingChanged: (value) => setState(() => _rating = value),
                    wins: _wins,
                    adjustments: _adjustments,
                    intention: _intention,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    onPressed: _isSaving ? null : _save,
                    icon: const Icon(FluentIcons.checkmark_20_filled),
                    label: Text(
                      _saved == null
                          ? 'Enregistrer mon bilan'
                          : 'Mettre à jour mon bilan',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekSwitcher extends StatelessWidget {
  const _WeekSwitcher({
    required this.weekStart,
    required this.isSaved,
    required this.canGoForward,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime weekStart;
  final bool isSaved;
  final bool canGoForward;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        IconButton.filledTonal(
          tooltip: 'Semaine précédente',
          onPressed: onPrevious,
          icon: const Icon(FluentIcons.chevron_left_20_regular),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                formatWeekRange(weekStart),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                isSaved ? 'Bilan enregistré' : 'Pas encore de bilan',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isSaved ? colors.primary : colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          tooltip: 'Semaine suivante',
          onPressed: canGoForward ? onNext : null,
          icon: const Icon(FluentIcons.chevron_right_20_regular),
        ),
      ],
    );
  }
}

/// The week's numbers, shared by the review and the history detail.
class WeeklyStatsView extends ConsumerWidget {
  const WeeklyStatsView({super.key, required this.stats});

  final WeeklyStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final apps = ref.watch(appsInfoProvider).valueOrNull ?? const {};
    final trend = stats.screenTimeTrend;
    final maxDay = stats.dailyScreenTime.fold(1, (a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassSurface(
          borderRadius: BorderRadius.circular(26),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _CardTitle(
                icon: FluentIcons.phone_screen_time_20_regular,
                title: 'Temps d’écran',
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatSeconds(stats.screenTime),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (trend != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        '${trend <= 0 ? '▼' : '▲'} ${(trend.abs() * 100).round()} % vs semaine passée',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: trend <= 0 ? colors.primary : colors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              Text(
                '${formatSeconds(stats.averageDailyScreenTime(DateTime.now()))} par jour en moyenne',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 70,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Flexible(
                              child: FractionallySizedBox(
                                heightFactor:
                                    (stats.dailyScreenTime[i] / maxDay)
                                        .clamp(0.04, 1.0),
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 5),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    gradient: LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        colors.primary,
                                        colors.tertiary,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              const ['L', 'M', 'M', 'J', 'V', 'S', 'D'][i],
                              style: theme.textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (stats.topApps.isNotEmpty) ...[
                const SizedBox(height: 14),
                for (final app in stats.topApps)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            apps[app.packageName]?.name.isNotEmpty == true
                                ? apps[app.packageName]!.name
                                : app.packageName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          formatSeconds(app.seconds),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                icon: FluentIcons.target_20_regular,
                value: formatSeconds(stats.focusSeconds),
                label: 'de concentration',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: FluentIcons.alert_20_regular,
                value: '${stats.notificationsCount}',
                label: 'notifications reçues',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GlassSurface(
          showShadow: false,
          borderRadius: BorderRadius.circular(26),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardTitle(
                icon: FluentIcons.checkmark_starburst_20_regular,
                title: 'Systèmes · ${stats.totalVotes} votes',
              ),
              const SizedBox(height: 8),
              if (stats.systems.isEmpty)
                Text(
                  'Aucun système actif cette semaine.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                )
              else
                for (final system in stats.systems)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            system.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${system.votes} votes · ${system.activeDays}/7 j',
                          style: TextStyle(
                            color: system.votes == 0
                                ? colors.error
                                : colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassSurface(
          showShadow: false,
          borderRadius: BorderRadius.circular(26),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CardTitle(
                icon: FluentIcons.task_list_square_ltr_20_regular,
                title: 'Tâches · ${stats.completedTasks.length} accomplies',
              ),
              if (stats.overdueTasks > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${stats.overdueTasks} en retard à reprendre',
                    style: TextStyle(
                      color: colors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 6),
              for (final title in stats.completedTasks
                  .take(WeeklyStats.completedTitlesCount))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: colors.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (stats.completedTasks.length > WeeklyStats.completedTitlesCount)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+ ${stats.completedTasks.length - WeeklyStats.completedTitlesCount} autres',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassSurface(
      showShadow: false,
      borderRadius: BorderRadius.circular(24),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReflectionCard extends StatelessWidget {
  const _ReflectionCard({
    required this.rating,
    required this.onRatingChanged,
    required this.wins,
    required this.adjustments,
    required this.intention,
  });

  static const _moods = ['😣', '😕', '😐', '🙂', '🤩'];

  final int rating;
  final ValueChanged<int> onRatingChanged;
  final TextEditingController wins;
  final TextEditingController adjustments;
  final TextEditingController intention;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return GlassSurface(
      borderRadius: BorderRadius.circular(26),
      padding: const EdgeInsets.all(18),
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _CardTitle(
              icon: FluentIcons.chat_bubbles_question_20_regular,
              title: 'Ton regard sur la semaine',
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < _moods.length; i++)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onRatingChanged(rating == i + 1 ? 0 : i + 1);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: rating == i + 1
                            ? colors.primary.withValues(alpha: 0.22)
                            : Colors.transparent,
                      ),
                      child: AnimatedScale(
                        scale: rating == i + 1 ? 1.2 : 1,
                        duration: const Duration(milliseconds: 180),
                        child: Text(
                          _moods[i],
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _ReflectionField(
              controller: wins,
              label: 'Ce qui a bien marché',
              hint: 'Une victoire, même petite',
            ),
            const SizedBox(height: 10),
            _ReflectionField(
              controller: adjustments,
              label: 'Ce que j’ajuste',
              hint: 'Un obstacle à retirer, une habitude à simplifier',
            ),
            const SizedBox(height: 10),
            _ReflectionField(
              controller: intention,
              label: 'Mon intention pour la semaine prochaine',
              hint: 'Une seule chose qui compte',
            ),
          ],
        ),
      ),
    );
  }
}

class _ReflectionField extends StatelessWidget {
  const _ReflectionField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        minLines: 1,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
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
        ),
      );
}
