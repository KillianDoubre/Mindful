import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mindful/config/app_constants.dart';
import 'package:mindful/models/opening_intent_record.dart';
import 'package:mindful/models/app_info.dart';
import 'package:mindful/providers/apps/apps_info_provider.dart';
import 'package:mindful/providers/usage/opening_intent_history_provider.dart';
import 'package:mindful/ui/common/application_icon.dart';
import 'package:mindful/ui/common/glass_surface.dart';
import 'package:mindful/ui/common/styled_text.dart';

class OpeningIntentHistoryCard extends ConsumerStatefulWidget {
  const OpeningIntentHistoryCard({
    super.key,
    this.groupId,
    this.expanded = false,
  });

  final int? groupId;
  final bool expanded;

  @override
  ConsumerState<OpeningIntentHistoryCard> createState() =>
      _OpeningIntentHistoryCardState();
}

class _OpeningIntentHistoryCardState
    extends ConsumerState<OpeningIntentHistoryCard>
    with WidgetsBindingObserver {
  /// Whether the per-app detail list is revealed. Collapsed by default so the
  /// card shows only the header + today's summary until the user taps to expand.
  bool _showDetail = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(openingIntentHistoryProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(openingIntentHistoryProvider);
    final apps = ref.watch(appsInfoProvider).value ?? const {};
    final colors = Theme.of(context).colorScheme;

    /// Show the expand/collapse chevron as soon as the history has loaded
    /// (even when empty), so the toggle is always available and the detail
    /// stays collapsed by default.
    final hasDetail = history.hasValue;

    return GlassSurface(
      showShadow: false,
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: hasDetail
                ? () => setState(() => _showDetail = !_showDetail)
                : null,
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    FluentIcons.brain_circuit_20_filled,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StyledText(
                        "Intentions d’ouverture",
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                      StyledText(
                        "Observer vos mécanismes d'intention",
                        fontSize: 12.5,
                        isSubtitle: true,
                      ),
                    ],
                  ),
                ),
                if (hasDetail) ...[
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    duration: AppConstants.defaultAnimDuration,
                    turns: _showDetail ? 0.5 : 0,
                    child: Icon(
                      FluentIcons.chevron_down_20_filled,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          history.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => const StyledText(
              "L’historique n’est pas disponible pour le moment.",
              isSubtitle: true,
            ),
            data: (allRecords) {
              final records = allRecords
                  .where((record) =>
                      widget.groupId == null ||
                      record.groupId == widget.groupId)
                  .toList(growable: false);
              final now = DateTime.now();
              final today = records
                  .where((record) => _isSameDay(record.timestamp, now))
                  .toList(growable: false);

              final reasonCounts = <String, int>{};
              for (final record in today) {
                reasonCounts.update(
                  record.reason,
                  (count) => count + 1,
                  ifAbsent: () => 1,
                );
              }
              final sortedReasons = reasonCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              final visibleRecords = records
                  .take(widget.expanded ? 20 : 3)
                  .toList(growable: false);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StyledText(
                    today.isEmpty
                        ? "Aucune intention enregistrée aujourd’hui"
                        : "Aujourd’hui · ${today.length} ${today.length > 1 ? 'ouvertures observées' : 'ouverture observée'}",
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                  if (sortedReasons.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: sortedReasons
                          .take(4)
                          .map((entry) => _ReasonChip(
                                reason: entry.key,
                                count: entry.value,
                              ))
                          .toList(growable: false),
                    ),
                  ],

                  /// Per-app detail — collapsed by default, revealed via the
                  /// header chevron with the same animation as the Aperçu tile.
                  ClipRect(
                    child: AnimatedSize(
                      alignment: Alignment.topCenter,
                      duration: AppConstants.defaultAnimDuration,
                      reverseDuration: AppConstants.defaultAnimDuration,
                      curve: AppConstants.defaultCurve,
                      child: _showDetail
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 16),
                                Container(
                                  height: 1,
                                  color: colors.outlineVariant
                                      .withValues(alpha: 0.35),
                                ),
                                const SizedBox(height: 6),
                                if (visibleRecords.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 10),
                                    child: _EmptyIntentHistory(),
                                  ),
                                ...visibleRecords.map(
                                  (record) => _IntentHistoryRow(
                                    record: record,
                                    appInfo: apps[record.packageName],
                                    showGroup: widget.groupId == null,
                                  ),
                                ),
                              ],
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyIntentHistory extends StatelessWidget {
  const _EmptyIntentHistory();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const StyledText(
          "Aucune intention enregistrée pour le moment. Vos prochaines réponses apparaîtront ici.",
          textAlign: TextAlign.center,
          isSubtitle: true,
        ),
      );
}

class _ReasonChip extends StatelessWidget {
  const _ReasonChip({required this.reason, required this.count});

  final String reason;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: StyledText(
        "${_reasonLabel(reason)} · $count",
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: colors.primary,
      ),
    );
  }
}

class _IntentHistoryRow extends StatelessWidget {
  const _IntentHistoryRow({
    required this.record,
    required this.appInfo,
    required this.showGroup,
  });

  final OpeningIntentRecord record;
  final AppInfo? appInfo;
  final bool showGroup;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final outcomeColor = switch (record.outcome) {
      'continued' => colors.primary,
      'emergency' => colors.error,
      _ => colors.tertiary,
    };
    final outcomeLabel = switch (record.outcome) {
      'continued' => "Ouverte",
      'emergency' => "Urgence",
      _ => "Annulée",
    };
    final currentAppInfo = appInfo;
    final packageParts = record.packageName.split('.');
    final appName = currentAppInfo?.name ??
        (packageParts.isNotEmpty ? packageParts.last : record.packageName);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          if (currentAppInfo != null)
            ApplicationIcon(appInfo: currentAppInfo, size: 18)
          else
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.secondaryContainer,
              child: Icon(
                FluentIcons.apps_20_regular,
                size: 18,
                color: colors.onSecondaryContainer,
              ),
            ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StyledText(
                  _reasonLabel(record.reason),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                StyledText(
                  [
                    appName,
                    if (showGroup && record.groupName.isNotEmpty)
                      record.groupName,
                    _formatTimestamp(record.timestamp),
                  ].join(' · '),
                  fontSize: 11.5,
                  isSubtitle: true,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: outcomeColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: StyledText(
              outcomeLabel,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: outcomeColor,
            ),
          ),
        ],
      ),
    );
  }
}

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _formatTimestamp(DateTime value) {
  final now = DateTime.now();
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  if (_isSameDay(value, now)) return "$hour:$minute";
  final yesterday = now.subtract(const Duration(days: 1));
  if (_isSameDay(value, yesterday)) return "Hier, $hour:$minute";
  return "${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} · $hour:$minute";
}

/// Labels must stay in sync with the reason strings shown in the native
/// overlay (android/.../res/values-fr/strings.xml → opening_intent_reason_*).
String _reasonLabel(String reason) => switch (reason) {
      'boredom' => 'Me divertir',
      'stress' => 'Anti-stress',
      'information' => 'Rechercher une info',
      'reply' => 'Intéraction sociale',
      'habit' => 'Par habitude',
      'work' => 'Pour travailler',
      _ => 'Autre raison',
    };
