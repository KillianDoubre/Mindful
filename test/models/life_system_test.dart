import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/models/life_system.dart';

import '../helpers/test_env.dart';

SystemVictory victory({
  int id = 1,
  int target = 3,
  int completed = 0,
  SystemVictoryFrequency frequency = SystemVictoryFrequency.weekly,
  bool important = false,
}) =>
    SystemVictory(
      id: id,
      title: 'Victoire $id',
      targetCount: target,
      completedCount: completed,
      isImportant: important,
      sortOrder: 0,
      frequency: frequency,
    );

SystemWeek week({bool minimumUsed = false}) => SystemWeek(
      id: 1,
      systemId: 1,
      weekStart: systemWeekStart(DateTime.now()),
      weekEnd: systemWeekEnd(systemWeekStart(DateTime.now())),
      completedCount: 0,
      targetCount: 0,
      completionRatio: 0,
      momentum: 0,
      statusAtEnd: LifeSystemStatus.active,
      reflection: '',
      minimumUsed: minimumUsed,
      interruptionCount: 0,
      comebackCount: 0,
    );

LifeSystem system({
  int totalXp = 0,
  LifeSystemStatus status = LifeSystemStatus.active,
  Set<DateTime> activeDays = const {},
  Map<int, int> todayVotes = const {},
  List<SystemVictory> victories = const [],
  int lifetimeActiveDays = 0,
  DateTime? createdAt,
  DateTime? lastVictoryAt,
  bool minimumUsed = false,
}) =>
    LifeSystem(
      id: 1,
      name: 'Lecture',
      identity: 'lit chaque jour',
      status: status,
      priority: 1,
      minimumVersion: 'Lire une page',
      accountabilityName: '',
      comebackRule: '',
      notes: '',
      reviewEveryDays: 7,
      totalXp: totalXp,
      sortOrder: 0,
      createdAt: createdAt ?? DateTime(2020),
      updatedAt: DateTime(2020),
      lastVictoryAt: lastVictoryAt,
      victories: victories,
      rules: const [],
      frictions: const [],
      currentWeek: week(minimumUsed: minimumUsed),
      recentWeeks: const [],
      recentEvents: const [],
      momentum: 0,
      activeDays: activeDays,
      todayVotes: todayVotes,
      lifetimeActiveDays: lifetimeActiveDays,
    );

Set<DateTime> days(List<int> offsets) => {for (final o in offsets) dayOffset(-o)};

void main() {
  group('levels', () {
    test('starts at the first level', () {
      final s = system();
      expect(s.levelIndex, 0);
      expect(s.evidenceLevel, 'Initié');
      expect(s.levelProgress, 0);
      expect(s.nextLevelName, 'En mouvement');
      expect(s.xpToNextLevel, 80);
    });

    test('unlocks each level at its threshold', () {
      for (final (xp, name) in LifeSystem.levels) {
        expect(system(totalXp: xp).evidenceLevel, name);
      }
      expect(system(totalXp: 79).evidenceLevel, 'Initié');
      expect(system(totalXp: 199).evidenceLevel, 'En mouvement');
    });

    test('progress is measured between two levels', () {
      final s = system(totalXp: 140);
      expect(s.levelProgress, closeTo(0.5, 1e-9));
      expect(s.xpToNextLevel, 60);
    });

    test('the last level is capped', () {
      final s = system(totalXp: 99999);
      expect(s.isMaxLevel, isTrue);
      expect(s.levelProgress, 1);
      expect(s.nextLevelName, isNull);
      expect(s.xpToNextLevel, 0);
    });

    test('thresholds are increasing', () {
      final values = LifeSystem.levels.map((l) => l.$1).toList();
      for (var i = 1; i < values.length; i++) {
        expect(values[i], greaterThan(values[i - 1]));
      }
    });
  });

  group('never-miss-twice streak', () {
    test('no activity means no streak', () {
      expect(system().streakDays, 0);
      expect(system().isStreakAtRisk, isFalse);
    });

    test('today alone counts', () {
      expect(system(activeDays: days([0])).streakDays, 1);
    });

    test('today in progress does not break the streak', () {
      expect(system(activeDays: days([1, 2])).streakDays, 2);
    });

    test('a single missed day is forgiven', () {
      expect(system(activeDays: days([0, 1, 3, 4])).streakDays, 4);
    });

    test('two missed days in a row end the streak', () {
      expect(system(activeDays: days([0, 3, 4, 5])).streakDays, 1);
    });

    test('a long unbroken chain', () {
      expect(
        system(activeDays: days(List.generate(30, (i) => i))).streakDays,
        30,
      );
    });

    test('does not count days before the system existed', () {
      final s = system(
        activeDays: days([0, 1, 2]),
        createdAt: dayOffset(-1),
      );
      expect(s.streakDays, 2);
    });

    test('at risk when yesterday was missed and today is empty', () {
      final s = system(activeDays: days([2, 3]));
      expect(s.streakDays, greaterThan(0));
      expect(s.isStreakAtRisk, isTrue);
    });

    test('not at risk once today has a vote', () {
      expect(system(activeDays: days([0, 2, 3])).isStreakAtRisk, isFalse);
    });

    test('not at risk when yesterday was done', () {
      expect(system(activeDays: days([1, 2])).isStreakAtRisk, isFalse);
    });

    test('a paused system is never at risk', () {
      final s = system(
        activeDays: days([2, 3]),
        status: LifeSystemStatus.paused,
      );
      expect(s.isStreakAtRisk, isFalse);
    });
  });

  group('chain', () {
    test('lists the last days oldest first, ending today', () {
      final chain = system(activeDays: days([0, 2])).recentChain();
      expect(chain, hasLength(7));
      expect(chain.last.$1, dayOffset(0));
      expect(chain.first.$1, dayOffset(-6));
      expect(chain.map((d) => d.$2).toList(),
          [false, false, false, false, true, false, true]);
    });

    test('accepts a custom length', () {
      expect(system().recentChain(14), hasLength(14));
    });

    test('isActiveOn ignores the time of day', () {
      final s = system(activeDays: days([0]));
      expect(s.isActiveOn(DateTime.now()), isTrue);
      expect(s.isActiveToday, isTrue);
    });
  });

  group('votes and victories', () {
    test('perPeriodTarget converts daily targets', () {
      expect(
        victory(target: 14, frequency: SystemVictoryFrequency.daily)
            .perPeriodTarget,
        2,
      );
      expect(victory(target: 3).perPeriodTarget, 3);
      expect(
        victory(target: 1, frequency: SystemVictoryFrequency.daily)
            .perPeriodTarget,
        1,
      );
    });

    test('daily victory is done once today\'s target is reached', () {
      final daily = victory(target: 14, frequency: SystemVictoryFrequency.daily);
      expect(
        system(todayVotes: {1: 1}, victories: [daily])
            .isVictoryDoneForNow(daily),
        isFalse,
      );
      expect(
        system(todayVotes: {1: 2}, victories: [daily])
            .isVictoryDoneForNow(daily),
        isTrue,
      );
    });

    test('weekly victory is done once the week target is reached', () {
      final open = victory(target: 3, completed: 2);
      final done = victory(target: 3, completed: 3);
      expect(system().isVictoryDoneForNow(open), isFalse);
      expect(system().isVictoryDoneForNow(done), isTrue);
    });

    test('todayVotesFor defaults to zero', () {
      expect(system().todayVotesFor(victory()), 0);
    });

    test('week totals clamp overshoot', () {
      final s = system(victories: [
        victory(id: 1, target: 3, completed: 5),
        victory(id: 2, target: 2, completed: 1),
      ]);
      expect(s.completedThisWeek, 4);
      expect(s.targetThisWeek, 5);
      expect(s.currentWeekRatio, closeTo(0.8, 1e-9));
    });

    test('ratio is zero without victories', () {
      expect(system().currentWeekRatio, 0);
    });

    test('only running systems are playable', () {
      expect(system().isPlayable, isTrue);
      expect(system(status: LifeSystemStatus.maintenance).isPlayable, isTrue);
      for (final status in [
        LifeSystemStatus.paused,
        LifeSystemStatus.draft,
        LifeSystemStatus.archived,
      ]) {
        expect(system(status: status).isPlayable, isFalse);
      }
    });
  });

  group('growth and comeback', () {
    test('compounds 1 % per active day', () {
      expect(system().compoundedGrowth, 1);
      expect(system(lifetimeActiveDays: 1).compoundedGrowth, closeTo(1.01, 1e-9));
      expect(
        system(lifetimeActiveDays: 100).compoundedGrowth,
        closeTo(2.7048, 1e-3),
      );
    });

    test('offers a comeback after a silent week', () {
      expect(
        system(lastVictoryAt: DateTime.now().subtract(const Duration(days: 8)))
            .shouldOfferComeback,
        isTrue,
      );
      expect(
        system(lastVictoryAt: DateTime.now()).shouldOfferComeback,
        isFalse,
      );
      expect(
        system(
          lastVictoryAt: DateTime.now().subtract(const Duration(days: 8)),
          minimumUsed: true,
        ).shouldOfferComeback,
        isFalse,
      );
    });
  });

  group('week helpers', () {
    test('systemWeekStart is Monday midnight', () {
      final start = systemWeekStart(DateTime(2026, 9, 17, 10));
      expect(start, DateTime(2026, 9, 14));
      expect(systemWeekEnd(start), DateTime(2026, 9, 20, 23, 59, 59));
    });
  });
}
