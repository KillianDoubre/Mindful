/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

import 'dart:math' as math;

import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/models/life_system.dart';
import 'package:mindful/providers/systems/systems_provider.dart';

/// Atomic Habits reminders, one per day.
const _habitQuotes = <String>[
  'Chaque action est un vote pour la personne que tu veux devenir.',
  'Tu ne t’élèves pas au niveau de tes objectifs, tu tombes au niveau de tes systèmes.',
  'Rater une fois est un accident. Rater deux fois, c’est une nouvelle habitude.',
  '1 % de mieux chaque jour, c’est 37 fois mieux en un an.',
  'Rends-le évident, attrayant, facile et satisfaisant.',
  'Les jours difficiles, fais la version 2 minutes : l’important est de se présenter.',
  'Le but n’est pas de lire un livre, c’est de devenir un lecteur.',
];

String dailyHabitQuote() {
  final now = DateTime.now();
  final dayOfYear = now.difference(DateTime(now.year)).inDays;
  return _habitQuotes[dayOfYear % _habitQuotes.length];
}

/// Circular progress towards the next identity level.
class LevelRing extends StatelessWidget {
  const LevelRing({super.key, required this.system, this.size = 56});

  final LifeSystem system;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: system.levelProgress),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => CustomPaint(
          painter: _RingPainter(
            progress: value,
            track: colors.onSurface.withValues(alpha: 0.10),
            colors: [colors.primary, colors.tertiary, colors.primary],
            strokeWidth: size * 0.09,
          ),
          child: child,
        ),
        child: Center(
          child: Text(
            '${system.levelIndex + 1}',
            style: TextStyle(
              fontSize: size * 0.36,
              fontWeight: FontWeight.w800,
              color: colors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// Generic progress ring used by the "today" hub.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.child,
    this.size = 84,
  });

  final double progress;
  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: progress.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, value, inner) => CustomPaint(
          painter: _RingPainter(
            progress: value,
            track: colors.onSurface.withValues(alpha: 0.10),
            colors: [colors.primary, colors.tertiary, colors.primary],
            strokeWidth: size * 0.1,
          ),
          child: inner,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.track,
    required this.colors,
    required this.strokeWidth,
  });

  final double progress;
  final Color track;
  final List<Color> colors;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = track;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    if (progress <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 1.5,
        colors: colors,
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.track != track ||
      oldDelegate.colors != colors;
}

/// Flame with the "never miss twice" streak.
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.system, this.compact = false});

  final LifeSystem system;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final streak = system.streakDays;
    final atRisk = system.isStreakAtRisk;
    final isLit = system.isActiveToday;
    final color = atRisk
        ? colors.error
        : isLit
            ? const Color(0xFFFF8A3D)
            : colors.onSurfaceVariant;

    return Tooltip(
      message: atRisk
          ? 'Hier a été manqué : un vote aujourd’hui sauve la série'
          : 'Série « ne jamais manquer deux fois »',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 4 : 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isLit ? FluentIcons.fire_20_filled : FluentIcons.fire_20_regular,
              size: compact ? 16 : 18,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              '$streak j',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 12 : 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Habit-tracker chain: one dot per recent day, filled when a vote was cast.
class ChainDots extends StatelessWidget {
  const ChainDots({super.key, required this.system, this.days = 7});

  final LifeSystem system;
  final int days;

  static const _weekdayLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final chain = system.recentChain(days);
    final showLetters = days <= 7;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < chain.length; i++)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: showLetters ? 22 : 14,
                height: showLetters ? 22 : 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: chain[i].$2
                      ? LinearGradient(
                          colors: [colors.primary, colors.tertiary],
                        )
                      : null,
                  color: chain[i].$2
                      ? null
                      : colors.onSurface.withValues(alpha: 0.08),
                  border: i == chain.length - 1
                      ? Border.all(color: colors.primary, width: 1.5)
                      : null,
                ),
                child: chain[i].$2 && showLetters
                    ? Icon(Icons.check_rounded,
                        size: 14, color: colors.onPrimary)
                    : null,
              ),
              if (showLetters) ...[
                const SizedBox(height: 4),
                Text(
                  _weekdayLetters[chain[i].$1.weekday - 1],
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

/// A victory as a big tappable pill: tap to cast a vote, long press to take
/// one back.
class VoteChip extends ConsumerStatefulWidget {
  const VoteChip({
    super.key,
    required this.system,
    required this.victory,
    this.expanded = false,
  });

  final LifeSystem system;
  final SystemVictory victory;

  /// Full-width layout for the detail screen.
  final bool expanded;

  @override
  ConsumerState<VoteChip> createState() => _VoteChipState();
}

class _VoteChipState extends ConsumerState<VoteChip> {
  int _celebrations = 0;

  SystemVictory get _victory => widget.victory;

  bool get _isDaily => _victory.frequency == SystemVictoryFrequency.daily;

  int get _done => _isDaily
      ? widget.system.todayVotesFor(_victory)
      : _victory.completedCount;

  int get _target => _isDaily ? _victory.perPeriodTarget : _victory.targetCount;

  Future<void> _vote() async {
    if (!widget.system.isPlayable ||
        widget.system.isVictoryDoneForNow(_victory)) {
      HapticFeedback.selectionClick();
      return;
    }
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final completesPeriod = _done + 1 >= _target;
    setState(() => _celebrations++);
    await ref.read(systemsProvider.notifier).setVictoryProgress(
          widget.system.id,
          _victory,
          _victory.completedCount + 1,
        );
    final identity = widget.system.identity.trim();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 2),
          content: Text(
            completesPeriod
                ? '🎉 ${_isDaily ? 'Objectif du jour' : 'Objectif de la semaine'} atteint !'
                : identity.isEmpty
                    ? '+1 vote enregistré'
                    : '+1 vote pour : $identity',
          ),
        ),
      );
  }

  Future<void> _undo() async {
    if (_victory.completedCount <= 0 || (_isDaily && _done <= 0)) return;
    HapticFeedback.lightImpact();
    await ref.read(systemsProvider.notifier).setVictoryProgress(
          widget.system.id,
          _victory,
          _victory.completedCount - 1,
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDone = widget.system.isVictoryDoneForNow(_victory);
    final progress = _target == 0 ? 0.0 : (_done / _target).clamp(0.0, 1.0);
    final unit = _isDaily ? 'aujourd’hui' : 'cette semaine';

    final chip = AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: isDone
            ? LinearGradient(
                colors: [
                  colors.primary.withValues(alpha: 0.85),
                  colors.tertiary.withValues(alpha: 0.85),
                ],
              )
            : null,
        color: isDone
            ? null
            : colors.surfaceContainerHighest.withValues(
                alpha: 0.55,
              ),
        border: Border.all(
          color: isDone
              ? Colors.white.withValues(alpha: 0.25)
              : colors.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: widget.expanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          SizedBox.square(
            dimension: 30,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: isDone ? 1 : progress,
                  strokeWidth: 3,
                  backgroundColor: (isDone ? colors.onPrimary : colors.primary)
                      .withValues(alpha: 0.15),
                  color: isDone ? colors.onPrimary : colors.primary,
                ),
                Icon(
                  isDone ? Icons.check_rounded : Icons.add_rounded,
                  size: 18,
                  color: isDone ? colors.onPrimary : colors.primary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            fit: widget.expanded ? FlexFit.tight : FlexFit.loose,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _victory.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isDone ? colors.onPrimary : null,
                  ),
                ),
                Text(
                  '$_done/$_target $unit'
                  '${_victory.isImportant ? ' · ★' : ''}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isDone
                        ? colors.onPrimary.withValues(alpha: 0.85)
                        : colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: '${_victory.title}, $_done sur $_target $unit',
      child: GestureDetector(
        onTap: _vote,
        onLongPress: _undo,
        child: chip
            .animate(key: ValueKey(_celebrations), autoPlay: _celebrations > 0)
            .scaleXY(
              begin: 1,
              end: 1.06,
              duration: 120.ms,
              curve: Curves.easeOut,
            )
            .then()
            .scaleXY(
              begin: 1.06,
              end: 1,
              duration: 260.ms,
              curve: Curves.elasticOut,
            ),
      ),
    );
  }
}

/// Short explanation shown under the vote chips.
class VoteHint extends StatelessWidget {
  const VoteHint({super.key});

  @override
  Widget build(BuildContext context) => Text(
        'Touchez pour voter · appui long pour annuler',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      );
}

/// Small rounded label.
class SoftPill extends StatelessWidget {
  const SoftPill({
    super.key,
    required this.label,
    this.icon,
    this.color,
  });

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: tone),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: tone,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

String formatGrowth(double growth) {
  final percent = (growth - 1) * 100;
  if (percent < 10) {
    return '+${percent.toStringAsFixed(1).replaceAll('.', ',')} %';
  }
  return '+${percent.round()} %';
}
