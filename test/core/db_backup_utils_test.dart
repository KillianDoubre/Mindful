import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/core/database/app_database.dart';
import 'package:mindful/core/utils/db_backup_utils.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mindful_db_test');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  File fileIn(String name) => File('${dir.path}${Platform.pathSeparator}$name');

  group('hasSqliteHeader', () {
    test('accepts the SQLite magic string', () {
      expect(hasSqliteHeader([...'SQLite format 3'.codeUnits, 0, 1, 2]), isTrue);
    });

    test('rejects other content', () {
      expect(hasSqliteHeader([]), isFalse);
      expect(hasSqliteHeader('SQLite format 3'.codeUnits), isFalse);
      expect(hasSqliteHeader([...'SQLite format 4'.codeUnits, 0]), isFalse);
      expect(hasSqliteHeader('PK zip file content'.codeUnits), isFalse);
    });

    test('header constant is the 16 byte SQLite magic', () {
      expect(sqliteHeader, hasLength(16));
      expect(String.fromCharCodes(sqliteHeader.take(15)), 'SQLite format 3');
      expect(sqliteHeader.last, 0);
    });
  });

  group('isSqliteDatabaseFile', () {
    test('true for a real database, whatever its name', () async {
      final file = fileIn('backup.bin');
      final db = AppDatabase(NativeDatabase(file));
      await db.customStatement('CREATE TABLE t (x INTEGER)');
      await db.close();
      expect(await isSqliteDatabaseFile(file), isTrue);
    });

    test('false for text, empty or missing files', () async {
      final text = fileIn('notes.sqlite')..writeAsStringSync('hello');
      final empty = fileIn('empty.sqlite')..writeAsBytesSync([]);
      expect(await isSqliteDatabaseFile(text), isFalse);
      expect(await isSqliteDatabaseFile(empty), isFalse);
      expect(await isSqliteDatabaseFile(fileIn('missing.sqlite')), isFalse);
    });
  });

  group('deleteSqliteDbFiles', () {
    test('removes the database and its journal files', () async {
      final base = fileIn('Mindful.sqlite').path;
      for (final path in [
        base,
        for (final s in sqliteSidecarSuffixes) '$base$s',
      ]) {
        File(path).writeAsStringSync('x');
      }
      final unrelated = fileIn('other.sqlite')..writeAsStringSync('keep');

      await deleteSqliteDbFiles(base);

      expect(File(base).existsSync(), isFalse);
      for (final s in sqliteSidecarSuffixes) {
        expect(File('$base$s').existsSync(), isFalse);
      }
      expect(unrelated.existsSync(), isTrue);
    });

    test('does nothing when files are missing', () async {
      await deleteSqliteDbFiles(fileIn('nothing.sqlite').path);
    });
  });

  group('snapshotDatabase', () {
    test('produces a standalone copy with every row', () async {
      final file = fileIn('Mindful.sqlite');
      final db = AppDatabase(NativeDatabase(file));
      await db.customStatement('PRAGMA journal_mode = WAL');
      await db.customStatement('CREATE TABLE items (name TEXT)');
      for (var i = 0; i < 50; i++) {
        await db.customStatement('INSERT INTO items VALUES (?)', ['item $i']);
      }

      final bytes = await snapshotDatabase(db, file.path);
      await db.close();

      expect(hasSqliteHeader(bytes), isTrue);
      final copy = fileIn('copy.sqlite')..writeAsBytesSync(bytes);
      final restored = AppDatabase(NativeDatabase(copy));
      final rows = await restored.customSelect('SELECT COUNT(*) AS c FROM items').getSingle();
      expect(rows.read<int>('c'), 50);
      await restored.close();
    });

    test('leaves no temporary file behind', () async {
      final file = fileIn('Mindful.sqlite');
      final db = AppDatabase(NativeDatabase(file));
      await db.customStatement('CREATE TABLE t (x INTEGER)');
      await snapshotDatabase(db, file.path);
      await db.close();
      final leftovers = dir
          .listSync()
          .map((e) => e.uri.pathSegments.last)
          .where((name) => name.startsWith('backup_'))
          .toList();
      expect(leftovers, isEmpty);
    });
  });
}
