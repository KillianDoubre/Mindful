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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mindful/config/hero_tags.dart';
import 'package:mindful/core/database/adapters/time_of_day_adapter.dart';
import 'package:mindful/core/enums/item_position.dart';
import 'package:mindful/core/extensions/ext_build_context.dart';
import 'package:mindful/core/extensions/ext_duration.dart';
import 'package:mindful/core/extensions/ext_num.dart';
import 'package:mindful/core/extensions/ext_widget.dart';
import 'package:mindful/core/utils/widget_utils.dart';
import 'package:mindful/models/dating_app_block.dart';
import 'package:mindful/providers/restrictions/wellbeing_provider.dart';
import 'package:mindful/providers/system/permissions_provider.dart';
import 'package:mindful/providers/usage/dating_screen_times_provider.dart';
import 'package:mindful/ui/common/content_section_header.dart';
import 'package:mindful/ui/common/default_list_tile.dart';
import 'package:mindful/ui/common/scaffold_shell.dart';
import 'package:mindful/ui/common/sliver_tabs_bottom_padding.dart';
import 'package:mindful/ui/common/styled_text.dart';
import 'package:mindful/ui/permissions/accessibility_permission_card.dart';
import 'package:mindful/ui/dialogs/time_picker_dialog.dart';
import 'package:mindful/ui/screens/dating_blocking/dating_timer_chart.dart';
import 'package:mindful/ui/transitions/default_hero.dart';

const _kDatingApps = <({String name, String package, String logoAsset})>[
  (
    name: "Tinder",
    package: "com.tinder",
    logoAsset: "assets/vectors/dating_tinder.svg",
  ),
  (
    name: "Hinge",
    package: "co.hinge.app",
    logoAsset: "assets/vectors/dating_hinge.svg",
  ),
  (
    name: "Bumble",
    package: "com.bumble.app",
    logoAsset: "assets/vectors/dating_bumble.svg",
  ),
  (
    name: "Happn",
    package: "com.ftw_and_co.happn",
    logoAsset: "assets/vectors/dating_happn.svg",
  ),
];

class DatingBlockingScreen extends ConsumerWidget {
  const DatingBlockingScreen({super.key});

  Future<void> _pickResetTime(
    BuildContext context,
    WidgetRef ref,
    TimeOfDayAdapter currentTime,
  ) async {
    final pickedTime = await showCustomTimePickerDialog(
      context: context,
      heroTag: HeroTags.datingResetTimePickerTag,
      initialTime: currentTime,
      info: context.locale.dating_reset_time_picker_info,
    );

    if (!context.mounted || pickedTime == null || pickedTime == currentTime) {
      return;
    }
    ref.read(wellBeingProvider.notifier).setDatingResetTime(pickedTime);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final haveAccessibilityPermission = ref.watch(
      permissionProvider.select((v) => v.haveAccessibilityPermission),
    );
    final screenTimes = ref.watch(datingScreenTimesProvider).value ?? const {};
    final resetTime = ref.watch(
      wellBeingProvider.select((value) => value.datingResetTime),
    );

    return ScaffoldShell(
      items: [
        NavbarItem(
          icon: FluentIcons.heart_20_regular,
          filledIcon: FluentIcons.heart_20_filled,
          titleText: context.locale.dating_blocking_tab_title,
          sliverBody: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              StyledText(context.locale.dating_blocking_tab_info).sliver,
              const AccessibilityPermissionCard(),
              ContentSectionHeader(
                title: context.locale.dating_reset_heading,
              ).sliver,
              DefaultHero(
                tag: HeroTags.datingResetTimePickerTag,
                child: DefaultListTile(
                  leadingIcon: FluentIcons.arrow_clockwise_20_regular,
                  titleText: context.locale.dating_reset_time_tile_title,
                  subtitleText: context.locale.dating_reset_time_tile_subtitle,
                  trailing: StyledText(
                    resetTime.format(context),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  onPressed: () => _pickResetTime(context, ref, resetTime),
                ),
              ).sliver,
              ContentSectionHeader(
                title: context.locale.dating_apps_heading,
              ).sliver,
              ...List.generate(_kDatingApps.length, (index) {
                final app = _kDatingApps[index];
                return _DatingAppTile(
                  name: app.name,
                  package: app.package,
                  logoAsset: app.logoAsset,
                  position: getItemPositionInList(index, _kDatingApps.length),
                  enabled: haveAccessibilityPermission,
                  usedTimeSec: screenTimes[app.package] ?? 0,
                ).sliver;
              }),
              const SliverTabsBottomPadding(),
            ],
          ),
        ),
      ],
    );
  }
}

class _DatingAppTile extends ConsumerWidget {
  const _DatingAppTile({
    required this.name,
    required this.package,
    required this.logoAsset,
    required this.position,
    required this.enabled,
    required this.usedTimeSec,
  });

  final String name;
  final String package;
  final String logoAsset;
  final ItemPosition position;
  final bool enabled;
  final int usedTimeSec;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(
      wellBeingProvider.select(
        (v) => v.datingBlocks.firstWhere(
          (e) => e.appPackage == package,
          orElse: () => DatingAppBlock(
            appPackage: package,
            allowedMinutes: 30,
            isEnabled: false,
          ),
        ),
      ),
    );
    final notifier = ref.read(wellBeingProvider.notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DefaultListTile(
          position: config.isEnabled ? ItemPosition.top : position,
          enabled: enabled,
          leading: Opacity(
            opacity: enabled ? 1 : 0.42,
            child: SvgPicture.asset(
              logoAsset,
              width: 42,
              height: 42,
            ),
          ),
          titleText: name,
          subtitleText: config.isEnabled
              ? context.locale.dating_daily_limit(
                  Duration(minutes: config.allowedMinutes).toTimeShort(context),
                )
              : context.locale.app_limit_status_not_set,
          switchValue: config.isEnabled,
          onPressed: () => notifier.setDatingAppBlock(
            package,
            isEnabled: !config.isEnabled,
          ),
        ),
        if (config.isEnabled)
          DatingTimerChart(
            appName: name,
            appPackage: package,
            logoAsset: logoAsset,
            allowedMinutes: config.allowedMinutes,
            usedTimeSec: usedTimeSec,
            enabled: enabled,
          ),
        6.vBox,
      ],
    );
  }
}
