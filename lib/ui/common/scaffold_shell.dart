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
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mindful/config/app_constants.dart';
import 'package:mindful/config/navigation/app_routes.dart';
import 'package:mindful/core/extensions/ext_build_context.dart';
import 'package:mindful/core/extensions/ext_num.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/ui/common/mindful_background.dart';
import 'package:mindful/ui/common/styled_text.dart';
import 'package:mindful/ui/controllers/tab_controller_provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

@immutable
class NavbarItem {
  final IconData icon;
  final IconData filledIcon;
  final String? titleText;
  final Widget Function(double collapsingPercentage)? titleBuilder;
  final Widget? fab;
  final Widget sliverBody;
  final Widget? appBarBg;
  final List<Widget>? actions;
  final String? svgAsset;

  const NavbarItem({
    required this.icon,
    required this.filledIcon,
    required this.sliverBody,
    this.titleText,
    this.titleBuilder,
    this.fab,
    this.appBarBg,
    this.actions,
    this.svgAsset,
  }) : assert(titleText != null || titleBuilder != null,
            "Title and TitleBuilder both can't be null, Specify at least one of them");
}

/// Global Scaffold navigation bar and tab bar used throughout the app for consistent ui/ux
class ScaffoldShell extends StatefulWidget {
  const ScaffoldShell({
    super.key,
    this.initialTab,
    this.canGoBack = true,
    this.appBarExpandedHeight = 184,
    this.bodyPadding = const EdgeInsets.symmetric(horizontal: 16),
    required this.items,
  });

  final int? initialTab;
  final bool canGoBack;
  final double appBarExpandedHeight;
  final EdgeInsets bodyPadding;
  final List<NavbarItem> items;

  @override
  State<ScaffoldShell> createState() => _ScaffoldShellState();
}

class _ScaffoldShellState extends State<ScaffoldShell>
    with SingleTickerProviderStateMixin {
  final _isBottomNavVisible = ValueNotifier<bool>(true);
  final _appBarScrollOffSet = ValueNotifier<double>(0);
  late final TabController _tabController;

  late final bool _haveMultiTabs = widget.items.length > 1;
  int _selectedTabIndex = 0;
  double _wholeScreenScrollOffSet = 0;

  @override
  void initState() {
    super.initState();

    /// Resolve initial tab index
    _selectedTabIndex = (widget.initialTab ?? 0) % widget.items.length;

    /// Handle tab controller
    _tabController = TabController(
      length: widget.items.length,
      initialIndex: _selectedTabIndex,
      vsync: this,
    );

    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          _selectedTabIndex = _tabController.index;
          _isBottomNavVisible.value = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton:
          widget.items[_selectedTabIndex].fab ?? const SizedBox.shrink(),
      floatingActionButtonAnimator: FloatingActionButtonAnimator.scaling,
      extendBody: true,
      extendBodyBehindAppBar: true,
      bottomNavigationBar: _haveMultiTabs ? _bottomNavBar() : null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const MindfulBackground(),
          TabBarView(
            controller: _tabController,
            physics: const BouncingScrollPhysics(),
            children: List.generate(
              widget.items.length,
              (i) => NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  // Always restore the expanded header when the outer scroll
                  // position reaches the top, including after an overscroll.
                  if (notification.depth == 0 &&
                      notification.metrics.pixels <= 0) {
                    _appBarScrollOffSet.value = 0;
                  }

                  if (notification is ScrollUpdateNotification) {
                    /// Add app bar offset if current scroll offset is from body
                    final currentOffset = notification.metrics.pixels +
                        (notification.depth == 1
                            ? _appBarScrollOffSet.value
                            : 0);

                    /// Show/Hide bottom bar
                    if (currentOffset >= widget.appBarExpandedHeight &&
                        (currentOffset >= _wholeScreenScrollOffSet + 1)) {
                      _isBottomNavVisible.value = false;
                    } else if (currentOffset <= _wholeScreenScrollOffSet - 1) {
                      _isBottomNavVisible.value = true;
                    }

                    final normalizedOffset =
                        currentOffset < 0 ? 0.0 : currentOffset;

                    /// Cache offset for whole screen
                    _wholeScreenScrollOffSet = normalizedOffset;

                    /// Cache offset for just the app bar only
                    if (notification.depth == 0) {
                      _appBarScrollOffSet.value = normalizedOffset;
                    }
                  }
                  return false;
                },
                child: NestedScrollView(
                  physics: const BouncingScrollPhysics(),
                  headerSliverBuilder: (_, innerBoxIsScrolled) =>
                      [_sliverAppBar(i, innerBoxIsScrolled)],
                  body: TabControllerProvider(
                    controller: _tabController,
                    child: Padding(
                      padding: widget.bodyPadding,
                      child: widget.items[i].sliverBody,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sliverAppBar(
    int tabIndex,
    bool innerBoxIsScrolled,
  ) {
    final navItem = widget.items[tabIndex];
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return AnimatedBuilder(
      animation: _appBarScrollOffSet,
      builder: (context, constraints) {
        // Calculate the scroll percentage
        final percentage = (_appBarScrollOffSet.value /
                (widget.appBarExpandedHeight - kToolbarHeight))
            .clamp(0.0, 1.0);

        final colors = Theme.of(context).colorScheme;

        // Keep the expanded bar airy and progressively strengthen its surface.
        final appBarColor = Color.lerp(
          Colors.transparent,
          colors.surface.withValues(alpha: 0.94),
          percentage,
        );

        // Interpolate left padding for the AppBar's title
        final leftPadding = widget.canGoBack ? 44 * percentage : 0.0;

        return SliverAppBar(
          expandedHeight: widget.appBarExpandedHeight,
          collapsedHeight: kToolbarHeight,
          pinned: true,
          stretch: true,
          primary: true,
          backgroundColor: appBarColor,
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            ...navItem.actions ?? [],
            widget.bodyPadding.right.hBox,
          ],
          leading: widget.canGoBack
              ? IconButton.filledTonal(
                  icon: Icon(
                    FluentIcons.chevron_left_24_regular,
                    color: colors.onSecondaryContainer,
                  ),
                  onPressed: () => context.popOrPushReplace(AppRoutes.homePath),
                )
              : null,
          flexibleSpace: FlexibleSpaceBar(
            expandedTitleScale: 1.55,
            background: innerBoxIsScrolled ? null : navItem.appBarBg,
            collapseMode: CollapseMode.parallax,
            titlePadding: EdgeInsets.only(
              bottom: 16,
              left: isRtl ? 0 : widget.bodyPadding.left + leftPadding,
              right: isRtl ? widget.bodyPadding.right + leftPadding : 0,
            ),
            title: navItem.titleBuilder?.call(1 - percentage) ??
                AppBarTitle(titleText: navItem.titleText!),
          ),
        );
      },
    );
  }

  Widget _bottomNavBar() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isBottomNavVisible,
      builder: (context, isVisible, child) {
        final safeBottom = MediaQuery.paddingOf(context).bottom;
        return AnimatedContainer(
          height: isVisible ? 62 + safeBottom : 0,
          duration: 320.ms,
          curve: isVisible ? Curves.easeOutCubic : Curves.easeInCubic,
          alignment: Alignment.bottomCenter,
          child: SingleChildScrollView(child: child),
        );
      },
      child: GlassSurface(
        blur: 18,
        height: 54,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        margin: EdgeInsets.fromLTRB(
          14,
          0,
          14,
          8 + MediaQuery.paddingOf(context).bottom,
        ),
        borderRadius: BorderRadius.circular(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(
            widget.items.length,
            (index) => _bottomNavDestination(index),
          ),
        ),
      ),
    );
  }

  Widget _bottomNavDestination(int index) {
    final colors = Theme.of(context).colorScheme;
    final item = widget.items[index];
    final isSelected = index == _selectedTabIndex;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: item.titleText,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(17),
            onTap: () => _tabController.animateTo(
              index,
              duration: AppConstants.defaultAnimDuration,
              curve: AppConstants.defaultCurve,
            ),
            child: Center(
              child: AnimatedContainer(
                duration: 240.ms,
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? colors.primary.withValues(alpha: 0.16)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: AnimatedScale(
                  scale: isSelected ? 1 : 0.92,
                  duration: 240.ms,
                  curve: Curves.easeOutCubic,
                  child: item.svgAsset == null
                      ? Icon(
                          isSelected ? item.filledIcon : item.icon,
                          size: 22,
                          color: isSelected
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        )
                      : SvgPicture.asset(
                          item.svgAsset!,
                          width: 22,
                          height: 22,
                          colorFilter: ColorFilter.mode(
                            isSelected
                                ? colors.primary
                                : colors.onSurfaceVariant,
                            BlendMode.srcIn,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppBarTitle extends StatelessWidget {
  const AppBarTitle({
    super.key,
    required this.titleText,
  });

  final String titleText;

  @override
  Widget build(BuildContext context) {
    return Skeleton.leaf(
      child: StyledText(
        titleText.isEmpty ? "Title" : titleText,
        fontSize: 24,
        maxLines: 2,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
