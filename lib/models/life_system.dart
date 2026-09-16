import 'package:flutter/foundation.dart';

enum LifeSystemStatus {
  draft('draft', 'Brouillon'),
  active('active', 'Actif'),
  maintenance('maintenance', 'Entretien'),
  paused('paused', 'En pause'),
  archived('archived', 'Archivé');

  const LifeSystemStatus(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static LifeSystemStatus fromDatabase(String? value) => values.firstWhere(
        (status) => status.databaseValue == value,
        orElse: () => LifeSystemStatus.draft,
      );
}

enum SystemFrictionType {
  remove('remove', 'Retirer un obstacle'),
  add('add', 'Ajouter un obstacle');

  const SystemFrictionType(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static SystemFrictionType fromDatabase(String? value) => values.firstWhere(
        (type) => type.databaseValue == value,
        orElse: () => SystemFrictionType.remove,
      );
}

enum SystemFrictionStatus {
  proposed('proposed', 'Proposée'),
  testing('testing', 'En test'),
  kept('kept', 'Conservée'),
  abandoned('abandoned', 'Abandonnée');

  const SystemFrictionStatus(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static SystemFrictionStatus fromDatabase(String? value) => values.firstWhere(
        (status) => status.databaseValue == value,
        orElse: () => SystemFrictionStatus.proposed,
      );
}

enum SystemEventType {
  weeklyVictory('weeklyVictory', 'Victoire hebdomadaire'),
  minimumVersion('minimumVersion', 'Version minimale'),
  focusSession('focusSession', 'Session de concentration'),
  comeback('comeback', 'Reprise'),
  review('review', 'Revue du système'),
  frictionImproved('frictionImproved', 'Friction améliorée'),
  accountability('accountability', 'Point de redevabilité'),
  milestone('milestone', 'Jalon'),
  interruption('interruption', 'Interruption'),
  statusChanged('statusChanged', 'État modifié'),
  systemChanged('systemChanged', 'Système ajusté');

  const SystemEventType(this.databaseValue, this.label);

  final String databaseValue;
  final String label;

  static SystemEventType fromDatabase(String? value) => values.firstWhere(
        (type) => type.databaseValue == value,
        orElse: () => SystemEventType.systemChanged,
      );
}

enum SystemVictoryFrequency {
  weekly('weekly', 'Hebdomadaire', 'semaine'),
  daily('daily', 'Quotidienne', 'jour');

  const SystemVictoryFrequency(this.databaseValue, this.label, this.unit);

  final String databaseValue;
  final String label;

  /// Unit used for the per-period target ("jour" or "semaine").
  final String unit;

  static SystemVictoryFrequency fromDatabase(String? value) =>
      values.firstWhere(
        (frequency) => frequency.databaseValue == value,
        orElse: () => SystemVictoryFrequency.weekly,
      );
}

@immutable
class SystemVictory {
  const SystemVictory({
    required this.id,
    required this.title,
    required this.targetCount,
    required this.completedCount,
    required this.isImportant,
    required this.sortOrder,
    required this.frequency,
  });

  final int id;
  final String title;

  /// Weekly total target. For a daily victory this is the per-day target × 7,
  /// so daily victories still accumulate and reset weekly like weekly ones.
  final int targetCount;
  final int completedCount;
  final bool isImportant;
  final int sortOrder;
  final SystemVictoryFrequency frequency;

  bool get isCompleted => completedCount >= targetCount;

  /// Target expressed in the victory's own unit (per day when daily).
  int get perPeriodTarget => frequency == SystemVictoryFrequency.daily
      ? (targetCount / 7).round().clamp(1, 999)
      : targetCount;
}

@immutable
class SystemRule {
  const SystemRule({
    required this.id,
    required this.text,
    required this.isActive,
    required this.sortOrder,
  });

  final int id;
  final String text;
  final bool isActive;
  final int sortOrder;
}

@immutable
class SystemFriction {
  const SystemFriction({
    required this.id,
    required this.text,
    required this.type,
    required this.status,
    required this.sortOrder,
  });

  final int id;
  final String text;
  final SystemFrictionType type;
  final SystemFrictionStatus status;
  final int sortOrder;
}

@immutable
class SystemWeek {
  const SystemWeek({
    required this.id,
    required this.systemId,
    required this.weekStart,
    required this.weekEnd,
    required this.completedCount,
    required this.targetCount,
    required this.completionRatio,
    required this.momentum,
    required this.statusAtEnd,
    required this.reflection,
    required this.minimumUsed,
    required this.interruptionCount,
    required this.comebackCount,
  });

  final int id;
  final int systemId;
  final DateTime weekStart;
  final DateTime weekEnd;
  final int completedCount;
  final int targetCount;
  final double completionRatio;
  final double momentum;
  final LifeSystemStatus statusAtEnd;
  final String reflection;
  final bool minimumUsed;
  final int interruptionCount;
  final int comebackCount;
}

@immutable
class SystemEvent {
  const SystemEvent({
    required this.id,
    required this.systemId,
    required this.type,
    required this.title,
    required this.details,
    required this.xp,
    required this.occurredAt,
  });

  final int id;
  final int systemId;
  final SystemEventType type;
  final String title;
  final String details;
  final int xp;
  final DateTime occurredAt;
}

@immutable
class LifeSystem {
  const LifeSystem({
    required this.id,
    required this.name,
    required this.identity,
    required this.status,
    required this.priority,
    required this.minimumVersion,
    required this.accountabilityName,
    required this.comebackRule,
    required this.notes,
    required this.reviewEveryDays,
    required this.totalXp,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.lastVictoryAt,
    required this.victories,
    required this.rules,
    required this.frictions,
    required this.currentWeek,
    required this.recentWeeks,
    required this.recentEvents,
    required this.momentum,
    this.intention = '',
    this.reward = '',
    this.activeDays = const {},
    this.todayVotes = const {},
    this.totalVotes = 0,
    this.lifetimeActiveDays = 0,
  });

  final int id;
  final String name;
  final String identity;
  final LifeSystemStatus status;
  final int priority;
  final String minimumVersion;
  final String accountabilityName;
  final String comebackRule;
  final String notes;
  final int reviewEveryDays;
  final int totalXp;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastVictoryAt;
  final List<SystemVictory> victories;
  final List<SystemRule> rules;
  final List<SystemFriction> frictions;
  final SystemWeek currentWeek;
  final List<SystemWeek> recentWeeks;
  final List<SystemEvent> recentEvents;
  final double momentum;

  /// Habit stacking cue: "Après …, je …".
  final String intention;

  /// What makes the habit satisfying right after doing it.
  final String reward;

  /// Local days (midnight) with at least one vote, over the recent past.
  final Set<DateTime> activeDays;

  /// Votes cast today, per victory id.
  final Map<int, int> todayVotes;

  /// Every vote ever cast for this identity.
  final int totalVotes;

  /// Number of distinct days with at least one vote.
  final int lifetimeActiveDays;

  int get completedThisWeek => victories.fold(
        0,
        (sum, victory) =>
            sum + victory.completedCount.clamp(0, victory.targetCount),
      );

  int get targetThisWeek =>
      victories.fold(0, (sum, victory) => sum + victory.targetCount);

  double get currentWeekRatio => targetThisWeek == 0
      ? 0
      : (completedThisWeek / targetThisWeek).clamp(0, 1);

  /// Identity levels, unlocked with XP (10 per vote, 20 when important).
  static const levels = <(int, String)>[
    (0, 'Initié'),
    (80, 'En mouvement'),
    (200, 'Régulier'),
    (450, 'Engagé'),
    (800, 'Pilier'),
    (1500, 'Identité ancrée'),
  ];

  int get levelIndex {
    var index = 0;
    for (var i = 0; i < levels.length; i++) {
      if (totalXp >= levels[i].$1) index = i;
    }
    return index;
  }

  String get evidenceLevel => levels[levelIndex].$2;

  bool get isMaxLevel => levelIndex == levels.length - 1;

  String? get nextLevelName => isMaxLevel ? null : levels[levelIndex + 1].$2;

  int get xpToNextLevel => isMaxLevel ? 0 : levels[levelIndex + 1].$1 - totalXp;

  /// Progress from the current level to the next, 0..1.
  double get levelProgress {
    if (isMaxLevel) return 1;
    final from = levels[levelIndex].$1;
    final to = levels[levelIndex + 1].$1;
    return ((totalXp - from) / (to - from)).clamp(0, 1).toDouble();
  }

  bool isActiveOn(DateTime day) =>
      activeDays.contains(DateTime(day.year, day.month, day.day));

  bool get isActiveToday => isActiveOn(DateTime.now());

  /// "Never miss twice" streak: consecutive days with votes, where a single
  /// missed day is forgiven but two in a row end the run. Today only counts
  /// once a vote is cast, it never breaks the streak while it is in progress.
  int get streakDays {
    final now = DateTime.now();
    var day = DateTime(now.year, now.month, now.day);
    if (!isActiveOn(day)) day = day.subtract(const Duration(days: 1));
    final created = DateTime(createdAt.year, createdAt.month, createdAt.day);
    var streak = 0;
    var misses = 0;
    while (!day.isBefore(created)) {
      if (isActiveOn(day)) {
        streak++;
        misses = 0;
      } else if (++misses >= 2) {
        break;
      }
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Yesterday was missed and nothing is done yet today: one more miss ends
  /// the streak.
  bool get isStreakAtRisk {
    if (status != LifeSystemStatus.active || streakDays == 0) return false;
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return !isActiveToday && !isActiveOn(yesterday);
  }

  /// The last [count] days, oldest first, with whether each had a vote.
  List<(DateTime, bool)> recentChain([int count = 7]) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var offset = count - 1; offset >= 0; offset--)
        (
          today.subtract(Duration(days: offset)),
          isActiveOn(today.subtract(Duration(days: offset))),
        ),
    ];
  }

  /// Compounded improvement of getting 1 % better on each active day.
  double get compoundedGrowth {
    var growth = 1.0;
    for (var i = 0; i < lifetimeActiveDays; i++) {
      growth *= 1.01;
    }
    return growth;
  }

  int todayVotesFor(SystemVictory victory) => todayVotes[victory.id] ?? 0;

  /// Whether the victory has nothing left to do in its current period.
  bool isVictoryDoneForNow(SystemVictory victory) => victory.frequency ==
          SystemVictoryFrequency.daily
      ? todayVotesFor(victory) >= victory.perPeriodTarget || victory.isCompleted
      : victory.isCompleted;

  bool get isPlayable =>
      status == LifeSystemStatus.active ||
      status == LifeSystemStatus.maintenance;

  String get momentumLabel {
    if (status == LifeSystemStatus.paused) return 'Système en pause';
    if (momentum >= .72) return 'Élan en progression';
    if (momentum >= .42) return 'Élan stable';
    return 'Rythme à construire';
  }

  bool get shouldOfferComeback {
    if (status != LifeSystemStatus.active || currentWeek.minimumUsed) {
      return false;
    }
    final reference = lastVictoryAt ?? createdAt;
    return DateTime.now().difference(reference).inDays >= 7;
  }
}

@immutable
class SystemVictoryDraft {
  const SystemVictoryDraft({
    this.id,
    required this.title,
    this.targetCount = 1,
    this.isImportant = false,
    this.frequency = SystemVictoryFrequency.weekly,
  });

  final int? id;
  final String title;

  /// Target in the chosen unit: per day when [frequency] is daily, per week
  /// otherwise. The repository converts it to a weekly total for storage.
  final int targetCount;
  final bool isImportant;
  final SystemVictoryFrequency frequency;
}

@immutable
class SystemRuleDraft {
  const SystemRuleDraft({this.id, required this.text, this.isActive = true});

  final int? id;
  final String text;
  final bool isActive;
}

@immutable
class SystemFrictionDraft {
  const SystemFrictionDraft({
    this.id,
    required this.text,
    required this.type,
    this.status = SystemFrictionStatus.proposed,
  });

  final int? id;
  final String text;
  final SystemFrictionType type;
  final SystemFrictionStatus status;
}

@immutable
class LifeSystemDraft {
  const LifeSystemDraft({
    required this.name,
    required this.identity,
    required this.status,
    required this.priority,
    required this.minimumVersion,
    required this.accountabilityName,
    required this.comebackRule,
    required this.notes,
    required this.reviewEveryDays,
    required this.victories,
    required this.rules,
    required this.frictions,
    this.intention = '',
    this.reward = '',
  });

  final String name;
  final String identity;
  final LifeSystemStatus status;
  final int priority;
  final String minimumVersion;
  final String accountabilityName;
  final String comebackRule;
  final String notes;
  final int reviewEveryDays;
  final List<SystemVictoryDraft> victories;
  final List<SystemRuleDraft> rules;
  final List<SystemFrictionDraft> frictions;
  final String intention;
  final String reward;
}

DateTime systemWeekStart(DateTime value) {
  final local = value.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

DateTime systemWeekEnd(DateTime start) =>
    start.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
