/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

/// Default initial home tab
enum DefaultHomeTab {
  dashboard,
  statistics,
  notifications,
  bedtime,
  systems,
}

extension DefaultHomeTabNavigation on DefaultHomeTab {
  /// Visual position in the label-free home footer. Persisted enum indices stay
  /// stable so an existing preference never changes meaning after the update.
  int get navigationIndex => switch (this) {
        DefaultHomeTab.dashboard => 0,
        DefaultHomeTab.systems => 1,
        DefaultHomeTab.statistics => 2,
        DefaultHomeTab.notifications => 3,
        DefaultHomeTab.bedtime => 0,
      };
}
