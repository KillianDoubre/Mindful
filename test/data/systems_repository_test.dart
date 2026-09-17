import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/core/database/app_database.dart';
import 'package:mindful/core/services/systems_repository.dart';
import 'package:mindful/models/life_system.dart';
import 'package:mindful/models/weekly_review.dart';

import '../helpers/test_env.dart';

LifeSystemDraft draft({
  String name = 'Lecture',
  LifeSystemStatus status = LifeSystemStatus.active,
  List<SystemVictoryDraft>? victories,
  String intention = 'Après mon café, je lis',
  String reward = 'Un thé',
}) =>
    LifeSystemDraft(
      name: name,
      identity: 'lit chaque jour',
      status: status,
      priority: 2,
      minimumVersion: 'Lire une page',
      accountabilityName: 'Léa',
      comebackRule: 'Ne jamais manquer deux fois',
      notes: 'notes',
      reviewEveryDays: 7,
      victories: victories ??
          const [
            SystemVictoryDraft(
              title: 'Lire 10 pages',
              targetCount: 2,
              frequency: SystemVictoryFrequency.daily,
            ),
            SystemVictoryDraft(title: 'Bibliothèque', targetCount: 1),
          ],
      rules: const [SystemRuleDraft(text: 'Pas d’écran au lit')],
      frictions: const [
        SystemFrictionDraft(
          text: 'Livre sur l’oreiller',
          type: SystemFrictionType.remove,
        ),
      ],
      intention: intention,
      reward: reward,
    );

void main() {
  late AppDatabase db;
  final repository = SystemsRepository.instance;

  setUpAll(() {
    mockNativeChannel();
    db = useInMemoryDatabase();
  });

  setUp(() async {
    await repository.loadSystems();
    await clearTables(db, [
      'life_systems',
      'system_victories',
      'system_victory_progress',
      'system_rules',
      'system_frictions',
      'system_weeks',
      'system_events',
      'system_gamification_events',
    ]);
  });

  tearDownAll(() => db.close());

  Future<LifeSystem> load(int id) async => (await repository.loadSystem(id))!;

  group('saving', () {
    test('stores every part of a system', () async {
      final id = await repository.saveSystem(draft());
      final system = await load(id);
      expect(system.name, 'Lecture');
      expect(system.identity, 'lit chaque jour');
      expect(system.status, LifeSystemStatus.active);
      expect(system.priority, 2);
      expect(system.minimumVersion, 'Lire une page');
      expect(system.accountabilityName, 'Léa');
      expect(system.intention, 'Après mon café, je lis');
      expect(system.reward, 'Un thé');
      expect(system.victories.map((v) => v.title),
          ['Lire 10 pages', 'Bibliothèque']);
      expect(system.rules.single.text, 'Pas d’écran au lit');
      expect(system.frictions.single.type, SystemFrictionType.remove);
    });

    test('daily victories are stored as a weekly total', () async {
      final id = await repository.saveSystem(draft());
      final daily = (await load(id)).victories.first;
      expect(daily.targetCount, 14);
      expect(daily.perPeriodTarget, 2);
    });

    test('updating keeps ids of kept victories and drops removed ones',
        () async {
      final id = await repository.saveSystem(draft());
      final kept = (await load(id)).victories.first;
      await repository.saveSystem(
        draft(
          name: 'Lecture +',
          intention: '',
          reward: '',
          victories: [
            SystemVictoryDraft(
              id: kept.id,
              title: 'Lire 20 pages',
              targetCount: 1,
              frequency: SystemVictoryFrequency.daily,
            ),
          ],
        ),
        id: id,
      );
      final system = await load(id);
      expect(system.name, 'Lecture +');
      expect(system.intention, '');
      expect(system.victories.single.id, kept.id);
      expect(system.victories.single.title, 'Lire 20 pages');
    });

    test('refuses a sixth system', () async {
      for (var i = 0; i < SystemsRepository.maximumSystems; i++) {
        await repository.saveSystem(draft(name: 'S$i'));
      }
      expect(
        () => repository.saveSystem(draft(name: 'Trop')),
        throwsA(isA<SystemsLimitException>()),
      );
    });

    test('lists active systems before paused ones', () async {
      await repository.saveSystem(
        draft(name: 'Pause', status: LifeSystemStatus.paused),
      );
      await repository.saveSystem(draft(name: 'Actif'));
      final names = (await repository.loadSystems()).map((s) => s.name);
      expect(names, ['Actif', 'Pause']);
    });
  });

  group('votes', () {
    test('a vote updates today, the chain, XP and totals', () async {
      final id = await repository.saveSystem(draft());
      final daily = (await load(id)).victories.first;

      await repository.setVictoryProgress(id, daily, 1);

      final system = await load(id);
      expect(system.todayVotesFor(system.victories.first), 1);
      expect(system.isActiveToday, isTrue);
      expect(system.streakDays, 1);
      expect(system.totalVotes, 1);
      expect(system.lifetimeActiveDays, 1);
      expect(system.totalXp, 10);
      expect(system.victories.first.completedCount, 1);
    });

    test('important victories give more XP', () async {
      final id = await repository.saveSystem(draft(victories: const [
        SystemVictoryDraft(title: 'Clé', targetCount: 3, isImportant: true),
      ]));
      final key = (await load(id)).victories.single;
      await repository.setVictoryProgress(id, key, 2);
      expect((await load(id)).totalXp, 40);
    });

    test('taking a vote back removes it', () async {
      final id = await repository.saveSystem(draft());
      final daily = (await load(id)).victories.first;
      await repository.setVictoryProgress(id, daily, 2);
      final voted = (await load(id)).victories.first;
      await repository.setVictoryProgress(id, voted, 1);

      final system = await load(id);
      expect(system.todayVotesFor(system.victories.first), 1);
      expect(system.totalVotes, 1);
    });

    test('progress never exceeds the target', () async {
      final id = await repository.saveSystem(draft());
      final weekly = (await load(id)).victories.last;
      await repository.setVictoryProgress(id, weekly, 10);
      expect((await load(id)).victories.last.completedCount, 1);
    });

    test('the two-minute version counts once a week', () async {
      final id = await repository.saveSystem(draft());
      await repository.completeMinimumVersion(id);
      await repository.completeMinimumVersion(id);
      final system = await load(id);
      expect(system.currentWeek.minimumUsed, isTrue);
      expect(system.totalVotes, 1);
      expect(system.isActiveToday, isTrue);
      expect(system.totalXp, 5);
    });
  });

  group('weekly votes', () {
    test('counts votes and active days per running system', () async {
      final reading = await repository.saveSystem(draft(name: 'Lecture'));
      final sport = await repository.saveSystem(draft(name: 'Sport'));
      await repository.saveSystem(
        draft(name: 'Archivé', status: LifeSystemStatus.archived),
      );
      final victory = (await load(reading)).victories.first;
      await repository.setVictoryProgress(reading, victory, 2);

      final start = weekStartOf(DateTime.now());
      final votes = await repository.loadWeeklyVotes(start, weekEndOf(start));

      expect(votes.map((v) => v.name), ['Lecture', 'Sport']);
      expect(votes.first.votes, 2);
      expect(votes.first.activeDays, 1);
      expect(votes.last.systemId, sport);
      expect(votes.last.votes, 0);
    });

    test('ignores votes outside the range', () async {
      final id = await repository.saveSystem(draft());
      final victory = (await load(id)).victories.first;
      await repository.setVictoryProgress(id, victory, 1);

      final lastWeek = weekStartOf(DateTime.now().subtract(const Duration(days: 7)));
      final votes =
          await repository.loadWeeklyVotes(lastWeek, weekEndOf(lastWeek));
      expect(votes.single.votes, 0);
    });
  });

  test('deleting a system removes it', () async {
    final id = await repository.saveSystem(draft());
    await repository.deleteSystem(id);
    expect(await repository.loadSystem(id), isNull);
    expect(await repository.loadSystems(), isEmpty);
  });
}
