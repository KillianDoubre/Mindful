/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

import 'dart:math';

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mindful/config/hero_tags.dart';
import 'package:mindful/core/extensions/ext_build_context.dart';
import 'package:mindful/core/extensions/ext_duration.dart';
import 'package:mindful/core/extensions/ext_num.dart';
import 'package:mindful/providers/restrictions/wellbeing_provider.dart';
import 'package:mindful/ui/common/rounded_container.dart';
import 'package:mindful/ui/common/styled_text.dart';
import 'package:mindful/ui/common/time_text_short.dart';
import 'package:mindful/ui/dialogs/timer_picker_dialog.dart';
import 'package:mindful/ui/transitions/default_hero.dart';

class DatingTimerChart extends ConsumerWidget {
  const DatingTimerChart({
    super.key,
    required this.appName,
    required this.appPackage,
    required this.logoAsset,
    required this.allowedMinutes,
    required this.usedTimeSec,
    required this.enabled,
  });

  final String appName;
  final String appPackage;
  final String logoAsset;
  final int allowedMinutes;
  final int usedTimeSec;
  final bool enabled;

  Future<void> _editAllowedTime(BuildContext context, WidgetRef ref) async {
    final allowedTimeSec = allowedMinutes * 60;
    final newTimerSec = await showDatingTimerPicker(
      context: context,
      heroTag: HeroTags.datingAppTimerPickerTag(appPackage),
      appName: appName,
      initialTime: allowedTimeSec,
    );

    if (newTimerSec == null || newTimerSec == allowedTimeSec) return;
    final newAllowedMinutes = max(1, newTimerSec ~/ 60);
    ref.read(wellBeingProvider.notifier).setDatingAppBlock(
          appPackage,
          allowedMinutes: newAllowedMinutes,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const dimension = 176.0;
    final allowedTimeSec = max(1, allowedMinutes) * 60;
    final remainingTimeSec = max(0, allowedTimeSec - usedTimeSec);
    final progress = (remainingTimeSec / allowedTimeSec).clamp(0.0, 1.0);
    final progressColor = Color.lerp(
      Theme.of(context).colorScheme.errorContainer,
      Theme.of(context).colorScheme.primaryContainer,
      progress,
    );

    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox.square(
            dimension: dimension,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.square(
                  dimension: dimension,
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 16,
                    strokeAlign: BorderSide.strokeAlignCenter,
                    color: progressColor,
                  ),
                ),
                SizedBox.square(
                  dimension: dimension,
                  child: RotatedBox(
                    quarterTurns: 2,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      strokeCap: StrokeCap.round,
                      strokeAlign: BorderSide.strokeAlignCenter,
                    ),
                  ),
                ),
                DefaultHero(
                  tag: HeroTags.datingAppTimerPickerTag(appPackage),
                  child: RoundedContainer(
                    width: dimension * 0.84,
                    height: dimension * 0.84,
                    circularRadius: dimension,
                    padding: const EdgeInsets.all(12),
                    color: Theme.of(context).colorScheme.surfaceContainerHigh,
                    onPressed:
                        enabled ? () => _editAllowedTime(context, ref) : null,
                    child: FittedBox(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            logoAsset,
                            width: 38,
                            height: 38,
                          ),
                          8.vBox,
                          TimeTextShort(
                            timeDuration: Duration(seconds: remainingTimeSec),
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                          4.vBox,
                          StyledText(
                            context.locale.dating_time_left_from(
                              Duration(seconds: allowedTimeSec)
                                  .toTimeShort(context),
                            ),
                            fontSize: 13,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                          ),
                          12.vBox,
                          const Icon(FluentIcons.edit_20_regular, size: 18),
                        ],
                      ),
                    ),
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
