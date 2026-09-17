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
import 'package:mindful/core/services/weekly_review_repository.dart';
import 'package:mindful/models/weekly_review.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/ui/common/mindful_background.dart';
import 'package:mindful/ui/common/page_app_bar.dart';
import 'package:mindful/ui/screens/weekly_review/weekly_review_screen.dart';

/// Every saved Sunday review, newest first.
class WeeklyReviewHistoryScreen extends StatefulWidget {
  const WeeklyReviewHistoryScreen({super.key});

  @override
  State<WeeklyReviewHistoryScreen> createState() =>
      _WeeklyReviewHistoryScreenState();
}

class _WeeklyReviewHistoryScreenState extends State<WeeklyReviewHistoryScreen> {
  late Future<List<WeeklyReview>> _reviews;

  static const _moods = ['😣', '😕', '😐', '🙂', '🤩'];

  @override
  void initState() {
    super.initState();
    _reviews = WeeklyReviewRepository.instance.loadAll();
  }

  Future<void> _open(WeeklyReview review) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WeeklyReviewScreen(weekStart: review.weekStart),
      ),
    );
    if (mounted) {
      setState(() => _reviews = WeeklyReviewRepository.instance.loadAll());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        const MindfulBackground(),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: PageAppBar(
            title: const Text('Historique des bilans'),
          ),
          body: BackdropGroup(
            child: FutureBuilder<List<WeeklyReview>>(
              future: _reviews,
              builder: (context, snapshot) {
                final reviews = snapshot.data;
                if (reviews == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (reviews.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            FluentIcons.calendar_checkmark_24_regular,
                            size: 48,
                            color: colors.primary,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Aucun bilan pour l’instant',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Chaque dimanche, prends cinq minutes pour regarder ta semaine.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: colors.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                  itemCount: reviews.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    final stats = review.stats;
                    final intention = review.intention.trim();
                    return GlassSurface(
                      showShadow: false,
                      borderRadius: BorderRadius.circular(24),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => _open(review),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        formatWeekRange(review.weekStart),
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    if (review.rating > 0)
                                      Text(
                                        _moods[review.rating - 1],
                                        style: const TextStyle(fontSize: 22),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${formatSeconds(stats.screenTime)} d’écran · '
                                  '${stats.totalVotes} votes · '
                                  '${stats.completedTasks.length} tâches',
                                  style: TextStyle(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                                if (intention.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    '→ $intention',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
