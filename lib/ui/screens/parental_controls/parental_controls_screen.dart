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
import 'package:mindful/config/hero_tags.dart';
import 'package:mindful/core/enums/item_position.dart';
import 'package:mindful/core/extensions/ext_build_context.dart';
import 'package:mindful/core/extensions/ext_num.dart';
import 'package:mindful/core/extensions/ext_widget.dart';
import 'package:mindful/core/services/auth_service.dart';
import 'package:mindful/core/utils/widget_utils.dart';
import 'package:mindful/providers/system/parental_controls_provider.dart';
import 'package:mindful/providers/system/permissions_provider.dart';
import 'package:mindful/ui/common/content_section_header.dart';
import 'package:mindful/ui/common/default_list_tile.dart';
import 'package:mindful/ui/common/rounded_container.dart';
import 'package:mindful/ui/common/scaffold_shell.dart';
import 'package:mindful/ui/common/sliver_tabs_bottom_padding.dart';
import 'package:mindful/ui/common/styled_text.dart';
import 'package:mindful/ui/common/time_period_start_end_cards.dart';
import 'package:mindful/ui/permissions/admin_permission_tile.dart';
import 'package:mindful/ui/screens/parental_controls/invincible_mode_settings.dart';

class ParentalControlsScreen extends ConsumerWidget {
  const ParentalControlsScreen({super.key});

  void _toggleProtectedAccess(
    BuildContext context,
    WidgetRef ref,
    bool isAccessProtected,
  ) async {
    try {
      if (!isAccessProtected) {
        final isAuthenticated = await AuthService.instance.authenticate();

        /// Return if not mounted
        if (!context.mounted) return;

        /// If no locks available
        if (isAuthenticated == null) {
          context.showSnackAlert(
            context.locale.protected_access_no_lock_snack_alert,
            icon: FluentIcons.fingerprint_20_filled,
          );
          return;
        }

        /// If aborted the auth
        if (!isAuthenticated) {
          context.showSnackAlert(
            context.locale.protected_access_failed_lock_snack_alert,
            icon: FluentIcons.fingerprint_20_filled,
          );

          return;
        }
      }

      ref.read(parentalControlsProvider.notifier).switchProtectedAccess();
    } catch (e) {
      debugPrint("Failed to authenticate: ${e.toString()}");
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentalControls = ref.watch(parentalControlsProvider);
    final isAdminEnabled =
        ref.watch(permissionProvider.select((v) => v.haveAdminPermission));

    return ScaffoldShell(
      items: [
        NavbarItem(
          icon: FluentIcons.shield_keyhole_20_regular,
          filledIcon: FluentIcons.shield_keyhole_20_filled,
          titleText: context.locale.parental_controls_tab_title,
          sliverBody: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              /// Invincible mode
              const InvincibleModeSettings(),

              /// Parental controls
              ContentSectionHeader(
                title: context.locale.parental_controls_tab_title,
              ).sliver,

              /// Protected access
              DefaultListTile(
                position: ItemPosition.top,
                switchValue: parentalControls.protectedAccess,
                leadingIcon: FluentIcons.fingerprint_20_regular,
                titleText: context.locale.protected_access_tile_title,
                subtitleText: context.locale.protected_access_tile_subtitle,
                onPressed: () => _toggleProtectedAccess(
                  context,
                  ref,
                  parentalControls.protectedAccess,
                ),
              ).sliver,

              /// Tamper protection
              const AdminPermissionTile().sliver,

              /// Shared modification window (start + end) — the daily window
              /// during which Mindful can be uninstalled and invincible-mode /
              /// restriction settings can be changed.
              RoundedContainer(
                borderRadius: getBorderRadiusFromPosition(ItemPosition.bottom),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StyledText(
                      context.locale.uninstall_window_tile_title,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    4.vBox,
                    StyledText(
                      context.locale.uninstall_window_tile_subtitle,
                      fontSize: 13,
                      isSubtitle: true,
                    ),
                    16.vBox,
                    TimePeriodStartEndCards(
                      startTime: parentalControls.uninstallWindowTime,
                      endTime: parentalControls.invincibleWindowTime,
                      startHeroTag: HeroTags.uninstallWindowTileTag,
                      endHeroTag: HeroTags.invincibleWindowTileTag,
                      isModifiable: () {
                        final protectionActive = isAdminEnabled ||
                            parentalControls.isInvincibleModeOn;
                        final allowed = !protectionActive ||
                            ref
                                .read(parentalControlsProvider.notifier)
                                .isBetweenWindow;
                        if (!allowed) {
                          context.showSnackAlert(
                            context.locale.permission_admin_snack_alert,
                          );
                        }
                        return allowed;
                      },
                      onStartTimeChanged: ref
                          .read(parentalControlsProvider.notifier)
                          .changeWindowStartTime,
                      onEndTimeChanged: ref
                          .read(parentalControlsProvider.notifier)
                          .changeWindowEndTime,
                    ),
                  ],
                ),
              ).sliver,

              const SliverTabsBottomPadding(),
            ],
          ),
        )
      ],
    );
  }
}
