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
import 'package:mindful/ui/transitions/default_page_transition_builder.dart';
import 'package:skeletonizer/skeletonizer.dart';

class AppTheme {
  static const _kSeedColor = Colors.indigo;

  static final _kShimmerEffect = ShimmerEffect(
    highlightColor: Colors.white.withValues(alpha: 0.6),
    baseColor: Colors.grey.withValues(alpha: 0.3),
  );

  /// Custom transition for page routes
  static const _kPageTransitionTheme = PageTransitionsTheme(
    builders: {TargetPlatform.android: DefaultPageTransitionsBuilder()},
  );

  static final materialColors = <String, MaterialColor>{
    'Amber': Colors.amber,
    'Blue': Colors.blue,
    'Blue Grey': Colors.blueGrey,
    'Brown': Colors.brown,
    'Cyan': Colors.cyan,
    'Deep Orange': Colors.deepOrange,
    'Deep Purple': Colors.deepPurple,
    'Green': Colors.green,
    'Grey': Colors.grey,
    'Indigo': Colors.indigo,
    'Light Blue': Colors.lightBlue,
    'Light Green': Colors.lightGreen,
    'Lime': Colors.lime,
    'Orange': Colors.orange,
    'Pink': Colors.pink,
    'Purple': Colors.purple,
    'Red': Colors.red,
    'Teal': Colors.teal,
    'Yellow': Colors.yellow,
  };

  static ThemeData darkTheme({Color? seedColor, required bool isAmoled}) =>
      _buildTheme(
        seedColor: seedColor ?? _kSeedColor,
        brightness: Brightness.dark,
        isAmoled: isAmoled,
      );

  static ThemeData lightTheme({Color? seedColor}) => _buildTheme(
        seedColor: seedColor ?? _kSeedColor,
        brightness: Brightness.light,
      );

  static ThemeData _buildTheme({
    required Color seedColor,
    required Brightness brightness,
    bool isAmoled = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final generated = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final surface = isAmoled
        ? Colors.black
        : Color.alphaBlend(
            seedColor.withValues(alpha: isDark ? 0.055 : 0.025),
            isDark ? const Color(0xFF0D0F14) : const Color(0xFFF8F9FD),
          );
    final colors = generated.copyWith(
      surface: surface,
      surfaceContainerLowest: surface,
      surfaceContainerLow: Color.alphaBlend(
        seedColor.withValues(alpha: isDark ? 0.075 : 0.035),
        surface,
      ),
      surfaceContainer: Color.alphaBlend(
        seedColor.withValues(alpha: isDark ? 0.10 : 0.055),
        surface,
      ),
      surfaceContainerHigh: Color.alphaBlend(
        seedColor.withValues(alpha: isDark ? 0.14 : 0.075),
        surface,
      ),
      surfaceContainerHighest: Color.alphaBlend(
        seedColor.withValues(alpha: isDark ? 0.18 : 0.10),
        surface,
      ),
    );
    final base = ThemeData.from(useMaterial3: true, colorScheme: colors);
    final textTheme = base.textTheme.copyWith(
      headlineLarge: base.textTheme.headlineLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.35),
      bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.30),
    );

    return base.copyWith(
      scaffoldBackgroundColor: surface,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: _kPageTransitionTheme,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.transparent,
        indicatorColor: colors.primary.withValues(alpha: 0.16),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: colors.surfaceContainerHigh.withValues(alpha: 0.72),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.30),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          elevation: const WidgetStatePropertyAll(0),
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? colors.primary.withValues(alpha: 0.14)
                : colors.surfaceContainerHigh.withValues(alpha: 0.52),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.34),
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.primary
              : colors.surfaceContainerHighest,
        ),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? colors.onPrimary
              : colors.onSurfaceVariant,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerHigh.withValues(alpha: 0.72),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        backgroundColor: colors.surface.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        showDragHandle: true,
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: colors.surfaceContainerHigh.withValues(alpha: 0.96),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: colors.inverseSurface,
        contentTextStyle: TextStyle(
          color: colors.onInverseSurface,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colors.primary,
        linearTrackColor: colors.surfaceContainerHighest,
        circularTrackColor: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(99),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: colors.inverseSurface,
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: TextStyle(color: colors.onInverseSurface),
      ),
      dividerTheme: DividerThemeData(
        color: colors.outlineVariant.withValues(alpha: 0.28),
        thickness: 1,
      ),
      extensions: [
        isDark
            ? SkeletonizerConfigData.dark(effect: _kShimmerEffect)
            : SkeletonizerConfigData(effect: _kShimmerEffect),
      ],
    );
  }
}
