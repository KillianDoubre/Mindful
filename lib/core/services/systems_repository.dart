import 'dart:async';

import 'package:drift/drift.dart';
import 'package:mindful/core/services/drift_db_service.dart';
import 'package:mindful/models/life_system.dart';

class SystemsLimitException implements Exception {
  const SystemsLimitException();

  @override
  String toString() => 'Vous pouvez créer cinq systèmes au maximum.';
}

/// Local, event-oriented persistence for identity systems.
///
/// Tables are installed lazily to preserve compatibility with personal
/// databases created by previous Mindful releases.
class SystemsRepository {
  SystemsRepository._();

  static final SystemsRepository instance = SystemsRepository._();
  static const int maximumSystems = 5;

  final StreamController<void> _changes = StreamController.broadcast();
  Stream<void> get changes => _changes.stream;

  Future<void>? _initialization;
  Future<void> _ensureInitialized() => _initialization ??= _createTables();

  dynamic get _db => DriftDbService.instance.driftDb;

  Future<void> _createTables() async {
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS life_systems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        direction TEXT NOT NULL DEFAULT '',
        identity_text TEXT NOT NULL DEFAULT '',
        status TEXT NOT NULL DEFAULT 'draft',
        priority INTEGER NOT NULL DEFAULT 3,
        minimum_version TEXT NOT NULL DEFAULT '',
        accountability_name TEXT NOT NULL DEFAULT '',
        comeback_rule TEXT NOT NULL DEFAULT '',
        next_action TEXT NOT NULL DEFAULT '',
        review_every_days INTEGER NOT NULL DEFAULT 7,
        total_xp INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0,
        last_victory_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS system_victories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        system_id INTEGER NOT NULL,
        title TEXT NOT NULL,
        target_count INTEGER NOT NULL DEFAULT 1,
        is_important INTEGER NOT NULL DEFAULT 0,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS system_victory_progress (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        system_id INTEGER NOT NULL,
        victory_id INTEGER NOT NULL,
        week_start INTEGER NOT NULL,
        completed_count INTEGER NOT NULL DEFAULT 0,
        UNIQUE(victory_id, week_start)
      )
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS system_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        system_id INTEGER NOT NULL,
        rule_text TEXT NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS system_frictions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        system_id INTEGER NOT NULL,
        friction_text TEXT NOT NULL,
        friction_type TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'proposed',
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS system_weeks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        system_id INTEGER NOT NULL,
        week_start INTEGER NOT NULL,
        week_end INTEGER NOT NULL,
        completed_count INTEGER NOT NULL DEFAULT 0,
        target_count INTEGER NOT NULL DEFAULT 0,
        completion_ratio REAL NOT NULL DEFAULT 0,
        momentum REAL NOT NULL DEFAULT 0,
        status_at_end TEXT NOT NULL DEFAULT 'active',
        reflection TEXT NOT NULL DEFAULT '',
        minimum_used INTEGER NOT NULL DEFAULT 0,
        interruption_count INTEGER NOT NULL DEFAULT 0,
        comeback_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(system_id, week_start)
      )
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS system_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        system_id INTEGER NOT NULL,
        event_type TEXT NOT NULL,
        source_key TEXT,
        title TEXT NOT NULL,
        details TEXT NOT NULL DEFAULT '',
        xp INTEGER NOT NULL DEFAULT 0,
        occurred_at INTEGER NOT NULL,
        UNIQUE(source_key)
      )
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS system_gamification_events (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        system_id INTEGER NOT NULL,
        event_type TEXT NOT NULL,
        source_key TEXT NOT NULL UNIQUE,
        base_xp INTEGER NOT NULL,
        awarded_xp INTEGER NOT NULL,
        occurred_at INTEGER NOT NULL,
        metadata TEXT NOT NULL DEFAULT ''
      )
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS system_focus_links (
        focus_session_id INTEGER PRIMARY KEY,
        system_id INTEGER NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS systems_settings (
        id INTEGER PRIMARY KEY CHECK (id = 0),
        selected_focus_system_id INTEGER
      )
    ''');
    await _db.customStatement(
      'INSERT OR IGNORE INTO systems_settings (id) VALUES (0)',
    );
    await _db.customStatement('''
      CREATE INDEX IF NOT EXISTS systems_status_priority
      ON life_systems(status, priority, sort_order)
    ''');
    await _db.customStatement('''
      CREATE INDEX IF NOT EXISTS system_events_system_date
      ON system_events(system_id, occurred_at DESC)
    ''');
  }

  Future<List<LifeSystem>> loadSystems() async {
    await _ensureInitialized();
    final rows = await _db.customSelect('''
      SELECT * FROM life_systems
      ORDER BY CASE status
        WHEN 'active' THEN 0 WHEN 'maintenance' THEN 1
        WHEN 'paused' THEN 2 WHEN 'draft' THEN 3 ELSE 4 END,
        priority ASC, sort_order ASC, updated_at DESC
    ''').get();

    final systems = <LifeSystem>[];
    for (final row in rows) {
      systems.add(await _hydrateSystem(row.data));
    }
    return systems;
  }

  Future<LifeSystem?> loadSystem(int id) async {
    await _ensureInitialized();
    final row = await _db.customSelect(
      'SELECT * FROM life_systems WHERE id = ?',
      variables: [Variable.withInt(id)],
    ).getSingleOrNull();
    return row == null ? null : _hydrateSystem(row.data);
  }

  Future<int> countSystems() async {
    await _ensureInitialized();
    final row = await _db
        .customSelect(
          'SELECT COUNT(*) AS amount FROM life_systems',
        )
        .getSingle();
    return row.read<int>('amount');
  }

  Future<int> saveSystem(LifeSystemDraft draft, {int? id}) async {
    await _ensureInitialized();
    if (id == null && await countSystems() >= maximumSystems) {
      throw const SystemsLimitException();
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    late int systemId;
    await _db.transaction(() async {
      if (id == null) {
        final orderRow = await _db
            .customSelect(
              'SELECT COALESCE(MAX(sort_order), -1) + 1 AS next_order FROM life_systems',
            )
            .getSingle();
        await _db.customStatement('''
          INSERT INTO life_systems (
            name, direction, identity_text, status, priority,
            minimum_version, accountability_name, comeback_rule, next_action,
            review_every_days, sort_order, created_at, updated_at
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', [
          draft.name.trim(),
          draft.direction.trim(),
          draft.identity.trim(),
          draft.status.databaseValue,
          draft.priority,
          draft.minimumVersion.trim(),
          draft.accountabilityName.trim(),
          draft.comebackRule.trim(),
          draft.nextAction.trim(),
          draft.reviewEveryDays,
          orderRow.read<int>('next_order'),
          now,
          now,
        ]);
        final inserted = await _db
            .customSelect(
              'SELECT last_insert_rowid() AS id',
            )
            .getSingle();
        systemId = inserted.read<int>('id');
      } else {
        systemId = id;
        await _db.customStatement('''
          UPDATE life_systems SET
            name = ?, direction = ?, identity_text = ?, status = ?,
            priority = ?, minimum_version = ?, accountability_name = ?,
            comeback_rule = ?, next_action = ?, review_every_days = ?,
            updated_at = ?
          WHERE id = ?
        ''', [
          draft.name.trim(),
          draft.direction.trim(),
          draft.identity.trim(),
          draft.status.databaseValue,
          draft.priority,
          draft.minimumVersion.trim(),
          draft.accountabilityName.trim(),
          draft.comebackRule.trim(),
          draft.nextAction.trim(),
          draft.reviewEveryDays,
          now,
          systemId,
        ]);
      }

      await _syncVictories(systemId, draft.victories);
      await _syncRules(systemId, draft.rules);
      await _syncFrictions(systemId, draft.frictions);
      await _ensureCurrentWeek(systemId, draft.status);
      await _recalculateCurrentWeek(systemId, draft.status);
      await _insertEvent(
        systemId: systemId,
        type: SystemEventType.systemChanged,
        sourceKey: id == null ? 'system-created:$systemId' : null,
        title: id == null ? 'Système créé' : 'Système ajusté',
        details: id == null
            ? 'Le système ${draft.name.trim()} prend forme.'
            : 'La structure du système a été mise à jour.',
        xp: 0,
      );
    });
    _changes.add(null);
    return systemId;
  }

  Future<void> _syncVictories(
    int systemId,
    List<SystemVictoryDraft> victories,
  ) async {
    final keptIds = victories.map((item) => item.id).whereType<int>().toSet();
    final existing = await _db.customSelect(
      'SELECT id FROM system_victories WHERE system_id = ?',
      variables: [Variable.withInt(systemId)],
    ).get();
    for (final row in existing) {
      final existingId = row.read<int>('id');
      if (!keptIds.contains(existingId)) {
        await _db.customStatement(
          'DELETE FROM system_victories WHERE id = ?',
          [existingId],
        );
      }
    }
    for (var index = 0; index < victories.length; index++) {
      final item = victories[index];
      if (item.id == null) {
        await _db.customStatement('''
          INSERT INTO system_victories
            (system_id, title, target_count, is_important, sort_order)
          VALUES (?, ?, ?, ?, ?)
        ''', [
          systemId,
          item.title.trim(),
          item.targetCount.clamp(1, 99),
          item.isImportant ? 1 : 0,
          index,
        ]);
      } else {
        await _db.customStatement('''
          UPDATE system_victories SET title = ?, target_count = ?,
            is_important = ?, sort_order = ?
          WHERE id = ? AND system_id = ?
        ''', [
          item.title.trim(),
          item.targetCount.clamp(1, 99),
          item.isImportant ? 1 : 0,
          index,
          item.id,
          systemId,
        ]);
      }
    }
  }

  Future<void> _syncRules(int systemId, List<SystemRuleDraft> rules) async {
    final keptIds = rules.map((item) => item.id).whereType<int>().toSet();
    final existing = await _db.customSelect(
      'SELECT id FROM system_rules WHERE system_id = ?',
      variables: [Variable.withInt(systemId)],
    ).get();
    for (final row in existing) {
      final existingId = row.read<int>('id');
      if (!keptIds.contains(existingId)) {
        await _db.customStatement('DELETE FROM system_rules WHERE id = ?', [
          existingId,
        ]);
      }
    }
    for (var index = 0; index < rules.length; index++) {
      final item = rules[index];
      if (item.id == null) {
        await _db.customStatement('''
          INSERT INTO system_rules (system_id, rule_text, is_active, sort_order)
          VALUES (?, ?, ?, ?)
        ''', [systemId, item.text.trim(), item.isActive ? 1 : 0, index]);
      } else {
        await _db.customStatement('''
          UPDATE system_rules SET rule_text = ?, is_active = ?, sort_order = ?
          WHERE id = ? AND system_id = ?
        ''', [
          item.text.trim(),
          item.isActive ? 1 : 0,
          index,
          item.id,
          systemId
        ]);
      }
    }
  }

  Future<void> _syncFrictions(
    int systemId,
    List<SystemFrictionDraft> frictions,
  ) async {
    final keptIds = frictions.map((item) => item.id).whereType<int>().toSet();
    final existing = await _db.customSelect(
      'SELECT id FROM system_frictions WHERE system_id = ?',
      variables: [Variable.withInt(systemId)],
    ).get();
    for (final row in existing) {
      final existingId = row.read<int>('id');
      if (!keptIds.contains(existingId)) {
        await _db.customStatement(
          'DELETE FROM system_frictions WHERE id = ?',
          [existingId],
        );
      }
    }
    for (var index = 0; index < frictions.length; index++) {
      final item = frictions[index];
      if (item.id == null) {
        await _db.customStatement('''
          INSERT INTO system_frictions
            (system_id, friction_text, friction_type, status, sort_order)
          VALUES (?, ?, ?, ?, ?)
        ''', [
          systemId,
          item.text.trim(),
          item.type.databaseValue,
          item.status.databaseValue,
          index,
        ]);
      } else {
        await _db.customStatement('''
          UPDATE system_frictions SET friction_text = ?, friction_type = ?,
            status = ?, sort_order = ? WHERE id = ? AND system_id = ?
        ''', [
          item.text.trim(),
          item.type.databaseValue,
          item.status.databaseValue,
          index,
          item.id,
          systemId,
        ]);
      }
    }
  }

  Future<void> setVictoryProgress(
    int systemId,
    SystemVictory victory,
    int newCount,
  ) async {
    await _ensureInitialized();
    final week = systemWeekStart(DateTime.now()).millisecondsSinceEpoch;
    final bounded = newCount.clamp(0, victory.targetCount);
    await _db.transaction(() async {
      final current = victory.completedCount;
      await _db.customStatement('''
        INSERT INTO system_victory_progress
          (system_id, victory_id, week_start, completed_count)
        VALUES (?, ?, ?, ?)
        ON CONFLICT(victory_id, week_start)
        DO UPDATE SET completed_count = excluded.completed_count
      ''', [systemId, victory.id, week, bounded]);

      if (bounded > current) {
        for (var ordinal = current + 1; ordinal <= bounded; ordinal++) {
          final xp = victory.isImportant ? 20 : 10;
          await _insertEvent(
            systemId: systemId,
            type: SystemEventType.weeklyVictory,
            sourceKey: 'victory:${victory.id}:$week:$ordinal',
            title: victory.title,
            details: '$ordinal sur ${victory.targetCount} cette semaine',
            xp: xp,
          );
        }
        await _db.customStatement(
          'UPDATE life_systems SET last_victory_at = ?, updated_at = ? WHERE id = ?',
          [
            DateTime.now().millisecondsSinceEpoch,
            DateTime.now().millisecondsSinceEpoch,
            systemId
          ],
        );
      } else if (bounded < current) {
        for (var ordinal = current; ordinal > bounded; ordinal--) {
          await _db.customStatement(
            'DELETE FROM system_events WHERE source_key = ?',
            ['victory:${victory.id}:$week:$ordinal'],
          );
        }
      }
      await _recalculateCurrentWeekById(systemId);
    });
    _changes.add(null);
  }

  Future<void> completeMinimumVersion(int systemId) async {
    await _ensureInitialized();
    final start = systemWeekStart(DateTime.now());
    final key = start.millisecondsSinceEpoch;
    await _db.transaction(() async {
      await _ensureCurrentWeekById(systemId);
      final row = await _db.customSelect(
        'SELECT minimum_used FROM system_weeks WHERE system_id = ? AND week_start = ?',
        variables: [Variable.withInt(systemId), Variable.withInt(key)],
      ).getSingle();
      if (row.read<int>('minimum_used') == 1) return;
      await _db.customStatement('''
        UPDATE system_weeks SET minimum_used = 1, updated_at = ?
        WHERE system_id = ? AND week_start = ?
      ''', [DateTime.now().millisecondsSinceEpoch, systemId, key]);
      await _insertEvent(
        systemId: systemId,
        type: SystemEventType.minimumVersion,
        sourceKey: 'minimum:$systemId:$key',
        title: 'Version minimale réalisée',
        details: 'Une preuve légère vaut mieux qu’un abandon.',
        xp: 5,
      );
      await _db.customStatement(
        'UPDATE life_systems SET last_victory_at = ?, updated_at = ? WHERE id = ?',
        [
          DateTime.now().millisecondsSinceEpoch,
          DateTime.now().millisecondsSinceEpoch,
          systemId
        ],
      );
    });
    _changes.add(null);
  }

  Future<void> toggleRule(int systemId, SystemRule rule) async {
    await _ensureInitialized();
    await _db.customStatement(
      'UPDATE system_rules SET is_active = ? WHERE id = ? AND system_id = ?',
      [rule.isActive ? 0 : 1, rule.id, systemId],
    );
    _changes.add(null);
  }

  Future<void> changeFrictionStatus(
    int systemId,
    SystemFriction friction,
    SystemFrictionStatus status,
  ) async {
    await _ensureInitialized();
    await _db.transaction(() async {
      await _db.customStatement(
        'UPDATE system_frictions SET status = ? WHERE id = ? AND system_id = ?',
        [status.databaseValue, friction.id, systemId],
      );
      if (status == SystemFrictionStatus.kept) {
        await _insertEvent(
          systemId: systemId,
          type: SystemEventType.frictionImproved,
          sourceKey: 'friction-improved:${friction.id}',
          title: 'Friction améliorée',
          details: friction.text,
          xp: 10,
        );
      }
    });
    _changes.add(null);
  }

  Future<void> changeStatus(int systemId, LifeSystemStatus status) async {
    await _ensureInitialized();
    await _db.transaction(() async {
      await _db.customStatement(
        'UPDATE life_systems SET status = ?, updated_at = ? WHERE id = ?',
        [status.databaseValue, DateTime.now().millisecondsSinceEpoch, systemId],
      );
      await _recalculateCurrentWeek(systemId, status);
      await _insertEvent(
        systemId: systemId,
        type: status == LifeSystemStatus.paused
            ? SystemEventType.interruption
            : SystemEventType.statusChanged,
        title: status == LifeSystemStatus.paused
            ? 'Système mis en pause'
            : 'État : ${status.label}',
        details: 'Ce changement ne retire aucune preuve accumulée.',
        xp: 0,
      );
      if (status == LifeSystemStatus.paused) {
        await _incrementCurrentWeekColumn(systemId, 'interruption_count');
      }
    });
    _changes.add(null);
  }

  Future<void> recordComeback({
    required int systemId,
    required String difficulty,
    required String action,
  }) async {
    await _ensureInitialized();
    final now = DateTime.now();
    await _db.transaction(() async {
      await _db.customStatement(
        "UPDATE life_systems SET status = 'active', last_victory_at = ?, updated_at = ? WHERE id = ?",
        [now.millisecondsSinceEpoch, now.millisecondsSinceEpoch, systemId],
      );
      await _incrementCurrentWeekColumn(systemId, 'comeback_count');
      await _insertEvent(
        systemId: systemId,
        type: SystemEventType.comeback,
        sourceKey: 'comeback:$systemId:${now.millisecondsSinceEpoch}',
        xpSourceKey:
            'comeback:$systemId:${systemWeekStart(now).millisecondsSinceEpoch}',
        title: 'Reprise engagée',
        details: '$difficulty · $action',
        xp: 20,
      );
    });
    _changes.add(null);
  }

  Future<void> recordReview({
    required int systemId,
    required String reflection,
    required String nextCommitment,
    required bool isExpress,
  }) async {
    await _ensureInitialized();
    final now = DateTime.now();
    final week = systemWeekStart(now).millisecondsSinceEpoch;
    await _db.transaction(() async {
      await _ensureCurrentWeekById(systemId);
      await _db.customStatement('''
        UPDATE system_weeks SET reflection = ?, updated_at = ?
        WHERE system_id = ? AND week_start = ?
      ''', [reflection.trim(), now.millisecondsSinceEpoch, systemId, week]);
      if (nextCommitment.trim().isNotEmpty) {
        await _db.customStatement(
          'UPDATE life_systems SET next_action = ?, updated_at = ? WHERE id = ?',
          [nextCommitment.trim(), now.millisecondsSinceEpoch, systemId],
        );
      }
      await _insertEvent(
        systemId: systemId,
        type: SystemEventType.review,
        sourceKey: 'review-event:$systemId:${now.millisecondsSinceEpoch}',
        xpSourceKey: 'review:$systemId:$week',
        title: isExpress ? 'Revue express' : 'Revue complète',
        details: reflection.trim(),
        xp: 10,
      );
    });
    _changes.add(null);
  }

  Future<void> deleteSystem(int systemId) async {
    await _ensureInitialized();
    await _db.transaction(() async {
      for (final table in [
        'system_victory_progress',
        'system_victories',
        'system_rules',
        'system_frictions',
        'system_weeks',
        'system_events',
        'system_gamification_events',
        'system_focus_links',
      ]) {
        await _db.customStatement('DELETE FROM $table WHERE system_id = ?', [
          systemId,
        ]);
      }
      await _db.customStatement('DELETE FROM life_systems WHERE id = ?', [
        systemId,
      ]);
      await _db.customStatement('''
        UPDATE systems_settings SET selected_focus_system_id = NULL
        WHERE selected_focus_system_id = ?
      ''', [systemId]);
    });
    _changes.add(null);
  }

  Future<int?> loadSelectedFocusSystemId() async {
    await _ensureInitialized();
    final row = await _db
        .customSelect(
          'SELECT selected_focus_system_id FROM systems_settings WHERE id = 0',
        )
        .getSingle();
    return row.data['selected_focus_system_id'] as int?;
  }

  Future<void> selectFocusSystem(int? systemId) async {
    await _ensureInitialized();
    await _db.customStatement(
      'UPDATE systems_settings SET selected_focus_system_id = ? WHERE id = 0',
      [systemId],
    );
    _changes.add(null);
  }

  Future<void> linkFocusSession(int focusSessionId, int? systemId) async {
    await _ensureInitialized();
    if (systemId == null) return;
    await _db.customStatement('''
      INSERT OR REPLACE INTO system_focus_links
        (focus_session_id, system_id, completed, created_at)
      VALUES (?, ?, 0, ?)
    ''', [focusSessionId, systemId, DateTime.now().millisecondsSinceEpoch]);
  }

  Future<String?> loadFocusSystemName(int focusSessionId) async {
    await _ensureInitialized();
    final row = await _db.customSelect('''
      SELECT s.name FROM system_focus_links l
      JOIN life_systems s ON s.id = l.system_id
      WHERE l.focus_session_id = ?
    ''', variables: [Variable.withInt(focusSessionId)]).getSingleOrNull();
    return row?.read<String>('name');
  }

  Future<void> completeFocusSession(int focusSessionId) async {
    await _ensureInitialized();
    final link = await _db.customSelect(
      'SELECT system_id, completed FROM system_focus_links WHERE focus_session_id = ?',
      variables: [Variable.withInt(focusSessionId)],
    ).getSingleOrNull();
    if (link == null || link.read<int>('completed') == 1) return;
    final systemId = link.read<int>('system_id');
    await _db.transaction(() async {
      await _db.customStatement(
        'UPDATE system_focus_links SET completed = 1 WHERE focus_session_id = ?',
        [focusSessionId],
      );
      await _insertEvent(
        systemId: systemId,
        type: SystemEventType.focusSession,
        sourceKey: 'focus-session:$focusSessionId',
        title: 'Session de concentration terminée',
        details: 'Une action réelle reliée à ce système.',
        xp: 10,
      );
    });
    _changes.add(null);
  }

  Future<LifeSystem> _hydrateSystem(Map<String, Object?> data) async {
    final id = data['id'] as int;
    final status = LifeSystemStatus.fromDatabase(data['status'] as String?);
    await _ensureCurrentWeek(id, status);
    await _recalculateCurrentWeek(id, status);
    final start = systemWeekStart(DateTime.now()).millisecondsSinceEpoch;

    final victoryRows = await _db.customSelect('''
      SELECT v.*, COALESCE(p.completed_count, 0) AS completed_count
      FROM system_victories v
      LEFT JOIN system_victory_progress p
        ON p.victory_id = v.id AND p.week_start = ?
      WHERE v.system_id = ? ORDER BY v.sort_order ASC
    ''', variables: [Variable.withInt(start), Variable.withInt(id)]).get();
    final victories = victoryRows
        .map((row) => SystemVictory(
              id: row.read<int>('id'),
              title: row.read<String>('title'),
              targetCount: row.read<int>('target_count'),
              completedCount: row.read<int>('completed_count'),
              isImportant: row.read<int>('is_important') == 1,
              sortOrder: row.read<int>('sort_order'),
            ))
        .toList();

    final ruleRows = await _db.customSelect(
      'SELECT * FROM system_rules WHERE system_id = ? ORDER BY sort_order ASC',
      variables: [Variable.withInt(id)],
    ).get();
    final rules = ruleRows
        .map((row) => SystemRule(
              id: row.read<int>('id'),
              text: row.read<String>('rule_text'),
              isActive: row.read<int>('is_active') == 1,
              sortOrder: row.read<int>('sort_order'),
            ))
        .toList();

    final frictionRows = await _db.customSelect(
      'SELECT * FROM system_frictions WHERE system_id = ? ORDER BY sort_order ASC',
      variables: [Variable.withInt(id)],
    ).get();
    final frictions = frictionRows
        .map((row) => SystemFriction(
              id: row.read<int>('id'),
              text: row.read<String>('friction_text'),
              type: SystemFrictionType.fromDatabase(
                row.read<String>('friction_type'),
              ),
              status: SystemFrictionStatus.fromDatabase(
                row.read<String>('status'),
              ),
              sortOrder: row.read<int>('sort_order'),
            ))
        .toList();

    final weekRows = await _db.customSelect('''
      SELECT * FROM system_weeks WHERE system_id = ?
      ORDER BY week_start DESC LIMIT 16
    ''', variables: [Variable.withInt(id)]).get();
    final weeks = weekRows.map((row) => _weekFromRow(row.data)).toList();
    final currentWeek = weeks.firstWhere(
      (week) => week.weekStart.millisecondsSinceEpoch == start,
    );
    final closed = weeks
        .where(
          (week) =>
              week.weekStart.millisecondsSinceEpoch < start &&
              week.statusAtEnd != LifeSystemStatus.paused,
        )
        .toList();
    final baseline =
        _weightedMomentum(closed.map((week) => week.completionRatio).toList());
    final provisional = currentWeek.completionRatio * .60 +
        (closed.isNotEmpty ? closed[0].completionRatio * .30 : 0) +
        (closed.length > 1 ? closed[1].completionRatio * .10 : 0);
    final momentum = status == LifeSystemStatus.paused
        ? baseline
        : (baseline > provisional ? baseline : provisional).clamp(0.0, 1.0);
    await _db.customStatement('''
      UPDATE system_weeks SET momentum = ?
      WHERE system_id = ? AND week_start = ?
    ''', [momentum, id, start]);

    final eventRows = await _db.customSelect('''
      SELECT * FROM system_events WHERE system_id = ?
      ORDER BY occurred_at DESC LIMIT 20
    ''', variables: [Variable.withInt(id)]).get();
    final events = eventRows.map((row) => _eventFromRow(row.data)).toList();

    return LifeSystem(
      id: id,
      name: data['name'] as String? ?? '',
      direction: data['direction'] as String? ?? '',
      identity: data['identity_text'] as String? ?? '',
      status: status,
      priority: data['priority'] as int? ?? 3,
      minimumVersion: data['minimum_version'] as String? ?? '',
      accountabilityName: data['accountability_name'] as String? ?? '',
      comebackRule: data['comeback_rule'] as String? ?? '',
      nextAction: data['next_action'] as String? ?? '',
      reviewEveryDays: data['review_every_days'] as int? ?? 7,
      totalXp: data['total_xp'] as int? ?? 0,
      sortOrder: data['sort_order'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(data['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(data['updated_at'] as int),
      lastVictoryAt: data['last_victory_at'] is int
          ? DateTime.fromMillisecondsSinceEpoch(data['last_victory_at'] as int)
          : null,
      victories: victories,
      rules: rules,
      frictions: frictions,
      currentWeek: currentWeek,
      recentWeeks: weeks,
      recentEvents: events,
      momentum: momentum,
    );
  }

  Future<void> _ensureCurrentWeekById(int systemId) async {
    final row = await _db.customSelect(
      'SELECT status FROM life_systems WHERE id = ?',
      variables: [Variable.withInt(systemId)],
    ).getSingle();
    await _ensureCurrentWeek(
      systemId,
      LifeSystemStatus.fromDatabase(row.read<String>('status')),
    );
  }

  Future<void> _ensureCurrentWeek(
    int systemId,
    LifeSystemStatus status,
  ) async {
    final start = systemWeekStart(DateTime.now());
    final end = systemWeekEnd(start);
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.customStatement('''
      INSERT OR IGNORE INTO system_weeks (
        system_id, week_start, week_end, status_at_end, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?)
    ''', [
      systemId,
      start.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
      status.databaseValue,
      now,
      now,
    ]);
  }

  Future<void> _recalculateCurrentWeekById(int systemId) async {
    final row = await _db.customSelect(
      'SELECT status FROM life_systems WHERE id = ?',
      variables: [Variable.withInt(systemId)],
    ).getSingle();
    await _recalculateCurrentWeek(
      systemId,
      LifeSystemStatus.fromDatabase(row.read<String>('status')),
    );
  }

  Future<void> _recalculateCurrentWeek(
    int systemId,
    LifeSystemStatus status,
  ) async {
    await _ensureCurrentWeek(systemId, status);
    final start = systemWeekStart(DateTime.now()).millisecondsSinceEpoch;
    final targetRow = await _db.customSelect(
      'SELECT COALESCE(SUM(target_count), 0) AS target FROM system_victories WHERE system_id = ?',
      variables: [Variable.withInt(systemId)],
    ).getSingle();
    final completedRow = await _db.customSelect('''
      SELECT COALESCE(SUM(
        CASE WHEN p.completed_count > v.target_count
          THEN v.target_count ELSE p.completed_count END
      ), 0) AS completed
      FROM system_victories v
      LEFT JOIN system_victory_progress p
        ON p.victory_id = v.id AND p.week_start = ?
      WHERE v.system_id = ?
    ''', variables: [
      Variable.withInt(start),
      Variable.withInt(systemId)
    ]).getSingle();
    final target = targetRow.read<int>('target');
    final completed = completedRow.read<int>('completed');
    final ratio = target == 0 ? 0.0 : (completed / target).clamp(0.0, 1.0);
    await _db.customStatement('''
      UPDATE system_weeks SET completed_count = ?, target_count = ?,
        completion_ratio = ?, status_at_end = ?, updated_at = ?
      WHERE system_id = ? AND week_start = ?
    ''', [
      completed,
      target,
      ratio,
      status.databaseValue,
      DateTime.now().millisecondsSinceEpoch,
      systemId,
      start,
    ]);
  }

  Future<void> _incrementCurrentWeekColumn(
    int systemId,
    String column,
  ) async {
    assert(column == 'interruption_count' || column == 'comeback_count');
    await _ensureCurrentWeekById(systemId);
    final week = systemWeekStart(DateTime.now()).millisecondsSinceEpoch;
    await _db.customStatement('''
      UPDATE system_weeks SET $column = $column + 1, updated_at = ?
      WHERE system_id = ? AND week_start = ?
    ''', [DateTime.now().millisecondsSinceEpoch, systemId, week]);
  }

  Future<void> _insertEvent({
    required int systemId,
    required SystemEventType type,
    required String title,
    required String details,
    required int xp,
    String? sourceKey,
    String? xpSourceKey,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final key = sourceKey ?? '${type.databaseValue}:$systemId:$now';
    final gamificationKey = xpSourceKey ?? key;
    var awardedXp = 0;
    if (xp > 0) {
      await _db.customStatement('''
        INSERT OR IGNORE INTO system_gamification_events (
          system_id, event_type, source_key, base_xp, awarded_xp,
          occurred_at, metadata
        ) VALUES (?, ?, ?, ?, ?, ?, '')
      ''', [systemId, type.databaseValue, gamificationKey, xp, xp, now]);
      final changes =
          await _db.customSelect('SELECT changes() AS amount').getSingle();
      if (changes.read<int>('amount') > 0) {
        awardedXp = xp;
        await _db.customStatement(
          'UPDATE life_systems SET total_xp = total_xp + ? WHERE id = ?',
          [xp, systemId],
        );
      }
    }
    await _db.customStatement('''
      INSERT OR IGNORE INTO system_events (
        system_id, event_type, source_key, title, details, xp, occurred_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
    ''', [
      systemId,
      type.databaseValue,
      key,
      title,
      details,
      awardedXp,
      now,
    ]);
  }

  double _weightedMomentum(List<double> ratios) {
    if (ratios.isEmpty) return 0;
    final first = ratios[0] * .60;
    final second = ratios.length > 1 ? ratios[1] * .30 : 0;
    final third = ratios.length > 2 ? ratios[2] * .10 : 0;
    return (first + second + third).clamp(0, 1);
  }

  SystemWeek _weekFromRow(Map<String, Object?> data) => SystemWeek(
        id: data['id'] as int,
        systemId: data['system_id'] as int,
        weekStart:
            DateTime.fromMillisecondsSinceEpoch(data['week_start'] as int),
        weekEnd: DateTime.fromMillisecondsSinceEpoch(data['week_end'] as int),
        completedCount: data['completed_count'] as int? ?? 0,
        targetCount: data['target_count'] as int? ?? 0,
        completionRatio: (data['completion_ratio'] as num? ?? 0).toDouble(),
        momentum: (data['momentum'] as num? ?? 0).toDouble(),
        statusAtEnd:
            LifeSystemStatus.fromDatabase(data['status_at_end'] as String?),
        reflection: data['reflection'] as String? ?? '',
        minimumUsed: (data['minimum_used'] as int? ?? 0) == 1,
        interruptionCount: data['interruption_count'] as int? ?? 0,
        comebackCount: data['comeback_count'] as int? ?? 0,
      );

  SystemEvent _eventFromRow(Map<String, Object?> data) => SystemEvent(
        id: data['id'] as int,
        systemId: data['system_id'] as int,
        type: SystemEventType.fromDatabase(data['event_type'] as String?),
        title: data['title'] as String? ?? '',
        details: data['details'] as String? ?? '',
        xp: data['xp'] as int? ?? 0,
        occurredAt:
            DateTime.fromMillisecondsSinceEpoch(data['occurred_at'] as int),
      );
}
