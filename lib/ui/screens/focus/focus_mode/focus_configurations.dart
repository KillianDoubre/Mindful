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
import 'package:mindful/core/enums/item_position.dart';
import 'package:mindful/core/services/systems_repository.dart';
import 'package:mindful/core/extensions/ext_build_context.dart';
import 'package:mindful/core/extensions/ext_duration.dart';
import 'package:mindful/core/extensions/ext_widget.dart';
import 'package:mindful/config/hero_tags.dart';
import 'package:mindful/providers/focus/focus_mode_provider.dart';
import 'package:mindful/models/life_system.dart';
import 'package:mindful/providers/systems/systems_provider.dart';
import 'package:mindful/ui/common/default_dropdown_tile.dart';
import 'package:mindful/ui/common/default_expandable_list_tile.dart';
import 'package:mindful/ui/common/default_list_tile.dart';
import 'package:mindful/ui/common/device_dnd_tile.dart';
import 'package:mindful/ui/common/content_section_header.dart';
import 'package:mindful/ui/common/styled_text.dart';
import 'package:mindful/ui/dialogs/timer_picker_dialog.dart';
import 'package:mindful/ui/permissions/dnd_switch_tile.dart';
import 'package:mindful/ui/transitions/default_hero.dart';
import 'package:sliver_tools/sliver_tools.dart';

class FocusConfigurations extends ConsumerWidget {
  const FocusConfigurations({super.key});

  void _pickSessionDuration(
    BuildContext context,
    WidgetRef ref,
    int prevTimer,
  ) async {
    final newTimer = await showFocusTimerPicker(
      heroTag: HeroTags.focusModeTimerTileTag,
      context: context,
      initialTime: prevTimer,
    );

    if (newTimer == null || newTimer == prevTimer) return;
    ref.read(focusModeProvider.notifier).setSessionDuration(newTimer);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSessionActive = ref
        .watch(focusModeProvider.select((v) => v.activeSession.value != null));

    final profile = ref.watch(focusModeProvider.select((v) => v.focusProfile));
    final systems = ref
            .watch(systemsProvider)
            .valueOrNull
            ?.where(
              (system) =>
                  system.status == LifeSystemStatus.active ||
                  system.status == LifeSystemStatus.maintenance,
            )
            .toList() ??
        const <LifeSystem>[];
    final selectedSystemId =
        ref.watch(selectedFocusSystemProvider).valueOrNull ??
            (systems.isEmpty ? 0 : systems.first.id);
    final focusItems = systems.isEmpty
        ? [DefaultDropdownItem<int>(label: 'Travail', value: 0)]
        : systems
            .map(
              (system) => DefaultDropdownItem<int>(
                label: system.name,
                value: system.id,
              ),
            )
            .toList();

    return MultiSliver(
      children: [
        ContentSectionHeader(
          title: context.locale.quick_actions_heading,
        ).sliver,

        /// Session tag
        DefaultDropdownTile<int>(
          position: ItemPosition.top,
          enabled: !isSessionActive && focusItems.length > 1,
          titleText: 'Système de concentration',
          dialogIcon: FluentIcons.door_tag_20_filled,
          value: selectedSystemId,
          onSelected: (systemId) async {
            await SystemsRepository.instance.selectFocusSystem(
              systemId == 0 ? null : systemId,
            );
            ref.invalidate(selectedFocusSystemProvider);
          },
          items: focusItems,
        ).sliver,

        /// Session timer
        DefaultHero(
          tag: HeroTags.focusModeTimerTileTag,
          child: DefaultListTile(
            position: ItemPosition.mid,
            enabled: !isSessionActive,
            titleText: context.locale.focus_session_duration_tile_title,
            subtitle: StyledText(
              profile.sessionDuration > 0
                  ? profile.sessionDuration.seconds.toTimeFull(context)
                  : context.locale.focus_session_duration_tile_subtitle,
              fontSize: 14,
              isSubtitle: true,
            ),
            onPressed: () => _pickSessionDuration(
              context,
              ref,
              profile.sessionDuration,
            ),
          ),
        ),

        DefaultExpandableListTile(
          position: ItemPosition.mid,
          titleText: context.locale.focus_profile_customization_tile_title,
          subtitleText:
              context.locale.focus_profile_customization_tile_subtitle,
          content: Column(
            children: [
              /// Enforce focus mode
              DefaultListTile(
                position: ItemPosition.mid,
                enabled: !isSessionActive,
                switchValue: profile.enforceSession,
                titleText: context.locale.focus_enforce_tile_title,
                subtitleText: context.locale.focus_enforce_tile_subtitle,
                onPressed: () => ref
                    .read(focusModeProvider.notifier)
                    .setEnforceFocus(!profile.enforceSession),
              ),

              /// Should start dnd
              DndSwitchTile(
                enabled: !isSessionActive,
                switchValue: profile.shouldStartDnd,
                position: ItemPosition.mid,
                onPressed: () => ref
                    .read(focusModeProvider.notifier)
                    .setShouldStartDnd(!profile.shouldStartDnd),
              ),

              /// Manage Dnd settings
              const DeviceDndTile(
                position: ItemPosition.mid,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
