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
import 'package:mindful/config/navigation/app_routes.dart';
import 'package:mindful/ui/common/glass_surface.dart';

/// Dashboard shortcut to the Sunday review, highlighted at the weekend.
class WeeklyReviewEntryCard extends StatelessWidget {
  const WeeklyReviewEntryCard({super.key});

  /// Saturday and Sunday are review days.
  static bool isReviewDay(DateTime day) => day.weekday >= DateTime.saturday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final highlight = isReviewDay(DateTime.now());

    return GlassSurface(
      showShadow: false,
      color: highlight ? colors.primaryContainer.withValues(alpha: 0.55) : null,
      borderRadius: BorderRadius.circular(24),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () =>
              Navigator.of(context).pushNamed(AppRoutes.weeklyReviewPath),
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                Icon(
                  FluentIcons.calendar_checkmark_24_regular,
                  size: 32,
                  color: colors.primary,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bilan de la semaine',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        highlight
                            ? 'C’est le moment : 5 minutes pour regarder ta semaine.'
                            : 'Écran, systèmes, tâches : ta semaine en un coup d’œil.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
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
