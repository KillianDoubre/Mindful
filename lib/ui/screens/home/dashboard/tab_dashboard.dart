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
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/config/navigation/app_routes.dart';
import 'package:mindful/core/enums/default_home_tab.dart';
import 'package:mindful/core/enums/item_position.dart';
import 'package:mindful/core/extensions/ext_build_context.dart';
import 'package:mindful/core/extensions/ext_list.dart';
import 'package:mindful/core/extensions/ext_num.dart';
import 'package:mindful/models/productivity_item.dart';
import 'package:mindful/providers/productivity/productivity_items_provider.dart';
import 'package:mindful/providers/usage/todays_apps_usage_provider.dart';
import 'package:mindful/providers/usage/opening_intent_history_provider.dart';
import 'package:mindful/ui/common/content_section_header.dart';
import 'package:mindful/ui/common/default_list_tile.dart';
import 'package:mindful/ui/common/sliver_active_session_alert.dart';
import 'package:mindful/ui/common/default_refresh_indicator.dart';
import 'package:mindful/ui/common/sliver_tabs_bottom_padding.dart';
import 'package:mindful/ui/common/opening_intent_history_card.dart';
import 'package:mindful/ui/controllers/tab_controller_provider.dart';
import 'package:mindful/ui/screens/home/dashboard/glance_cards/focus_daily_glance.dart';
import 'package:mindful/ui/screens/home/dashboard/glance_cards/screen_time_glance.dart';
import 'package:mindful/ui/screens/systems/systems_tab.dart';
import 'package:mindful/ui/transitions/default_effects.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:sliver_tools/sliver_tools.dart';

class TabDashboard extends ConsumerWidget {
  const TabDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUsageLoading =
        ref.watch(todaysAppsUsageProvider.select((v) => v.isLoading));
    final tasks = ref
        .watch(productivityItemsProvider(ProductivityItemType.task))
        .valueOrNull;
    final notesCount = ref
        .watch(productivityItemsProvider(ProductivityItemType.note))
        .valueOrNull
        ?.length;
    final todoCount = tasks?.where((task) => !task.isCompleted).length;

    return DefaultRefreshIndicator(
      onRefresh: () async {
        ref.invalidate(openingIntentHistoryProvider);
        await Future.wait([
          ref
              .read(todaysAppsUsageProvider.notifier)
              .refreshTodaysUsage(resetState: true),
          ref.read(openingIntentHistoryProvider.future),
        ]);
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          /// Active session
          const SliverActiveSessionAlert(),

          MultiSliver(
            children: [
              8.vBox,
              Skeletonizer.zone(
                enabled: isUsageLoading,
                enableSwitchAnimation: true,
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      /// Screen time
                      const Expanded(child: ScreenTimeGlance()),
                      4.hBox,

                      /// Data usage
                      const Expanded(child: FocusDailyGlance()),
                    ],
                  ),
                ),
              ),

              12.vBox,
              const OpeningIntentHistoryCard(),

              12.vBox,
              const SystemsNextActionCard(),

              /// Parental controls
              DefaultListTile(
                position: ItemPosition.bottom,
                leadingIcon: FluentIcons.shield_keyhole_20_regular,
                titleText: context.locale.parental_controls_tab_title,
                subtitleText: context.locale.parental_controls_tile_subtitle,
                color: Theme.of(context).colorScheme.secondaryContainer,
                trailing: const Icon(FluentIcons.chevron_right_20_regular),
                onPressed: () => Navigator.of(context)
                    .pushNamed(AppRoutes.parentalControlsPath),
              ),

              /// Productivity
              ..._productivity(
                context,
                todoCount: todoCount,
                notesCount: notesCount,
              ),

              /// Restrictions
              ..._restrictions(context),
            ].animateListOnce(
              ref: ref,
              uniqueKey: "home.dashboard",
              delay: 100.ms,
              effects: DefaultEffects.transitionIn,
              interval: 100.ms,
            ),
          ),

          const SliverTabsBottomPadding(),
        ],
      ),
    );
  }

  static List<Widget> _restrictions(BuildContext context) => [
        /// Restrictions
        ContentSectionHeader(
          title: context.locale.restrictions_heading,
        ),

        /// Apps blocking
        DefaultListTile(
          position: ItemPosition.top,
          leadingIcon: FluentIcons.app_title_20_regular,
          titleText: context.locale.apps_blocking_tile_title,
          subtitleText: context.locale.apps_blocking_tile_subtitle,
          onPressed: () => TabControllerProvider.maybeOf(context)?.animateToTab(
            DefaultHomeTab.statistics.navigationIndex,
          ),
        ),

        /// Grouped apps blocking
        DefaultListTile(
          position: ItemPosition.mid,
          leadingIcon: FluentIcons.app_recent_20_regular,
          titleText: context.locale.grouped_apps_blocking_tile_title,
          subtitleText: context.locale.grouped_apps_blocking_tile_subtitle,
          trailing: const Icon(FluentIcons.chevron_right_20_regular),
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.restrictionGroupsPath),
        ),

        /// Shorts restrictions
        DefaultListTile(
          position: ItemPosition.mid,
          leadingIcon: FluentIcons.resize_video_20_regular,
          titleText: context.locale.shorts_blocking_tab_title,
          subtitleText: context.locale.shorts_blocking_tile_subtitle,
          trailing: const Icon(FluentIcons.chevron_right_20_regular),
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.shortsBlockingPath),
        ),

        /// Dating restrictions
        DefaultListTile(
          position: ItemPosition.mid,
          leadingIcon: FluentIcons.heart_20_regular,
          titleText: context.locale.dating_blocking_tab_title,
          subtitleText: context.locale.dating_blocking_dashboard_subtitle,
          trailing: const Icon(FluentIcons.chevron_right_20_regular),
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.datingBlockingPath),
        ),

        /// Website restrictions
        DefaultListTile(
          position: ItemPosition.bottom,
          leadingIcon: FluentIcons.earth_20_regular,
          titleText: context.locale.websites_blocking_tab_title,
          subtitleText: context.locale.websites_blocking_tile_subtitle,
          trailing: const Icon(FluentIcons.chevron_right_20_regular),
          onPressed: () =>
              Navigator.of(context).pushNamed(AppRoutes.websitesBlockingPath),
        ),
      ];

  static List<Widget> _productivity(
    BuildContext context, {
    required int? todoCount,
    required int? notesCount,
  }) =>
      [
        /// Productivity
        ContentSectionHeader(title: context.locale.productivity_heading),

        /// Tasks and todos
        DefaultListTile(
          position: ItemPosition.top,
          leadingIcon: FluentIcons.reading_list_20_regular,
          titleText: context.locale.tasks_tile_title,
          subtitleText: context.locale.tasks_tile_subtitle,
          trailing: _CountTrailing(count: todoCount),
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.tasksPath),
        ),

        /// Notes & lists
        DefaultListTile(
          position: ItemPosition.bottom,
          leadingIcon: FluentIcons.note_20_regular,
          titleText: context.locale.notes_tile_title,
          subtitleText: context.locale.notes_tile_subtitle,
          trailing: _CountTrailing(count: notesCount),
          onPressed: () => Navigator.of(context).pushNamed(AppRoutes.notesPath),
        ),
      ];
}

class _CountTrailing extends StatelessWidget {
  const _CountTrailing({required this.count});

  final int? count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 30),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            count?.toString() ?? '–',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(width: 7),
        const Icon(FluentIcons.chevron_right_20_regular),
      ],
    );
  }
}
