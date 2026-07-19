/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

import 'package:flutter/material.dart';
import 'package:mindful/config/app_constants.dart';
import 'package:mindful/core/extensions/ext_widget.dart';
import 'package:mindful/ui/common/rounded_container.dart';
import 'package:mindful/ui/common/styled_text.dart';

/// A row of 7 tappable weekday bubbles ordered Monday → Sunday.
///
/// [selectedDays] must contain exactly 7 booleans (index 0 = Monday). Tapping a
/// bubble invokes [onDayToggled] with its index. When [enabled] is false the
/// bubbles are shown greyed out and are not tappable.
class WeekdaysSelector extends StatelessWidget {
  const WeekdaysSelector({
    super.key,
    required this.selectedDays,
    required this.onDayToggled,
    this.enabled = true,
  });

  final List<bool> selectedDays;
  final ValueChanged<int> onDayToggled;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final shortDays = AppConstants.daysShort(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        7,
        (index) => Expanded(
          child: RoundedContainer(
            circularRadius: 200,
            height: 44,
            width: 44,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: selectedDays[index]
                ? enabled
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).disabledColor
                : Colors.transparent,
            onPressed: enabled ? () => onDayToggled(index) : null,
            child: StyledText(
              shortDays[index],
              fontSize: 12,
              isSubtitle: !enabled,
              textAlign: TextAlign.center,
              color: selectedDays[index]
                  ? Theme.of(context).colorScheme.surface
                  : null,
            ).centered,
          ),
        ),
      ),
    );
  }
}
