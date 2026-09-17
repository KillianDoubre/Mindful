/*
 *
 *  * Copyright (c) 2024 Mindful (https://github.com/akaMrNagar/Mindful)
 *  * Author : Pawan Nagar (https://github.com/akaMrNagar)
 *  *
 *  * This source code is licensed under the GPL-2.0 license license found in the
 *  * LICENSE file in the root directory of this source tree.
 *
 */

import 'dart:io';

import 'package:drift/drift.dart';

/// Every SQLite database file starts with this 16 byte header.
const sqliteHeader = <int>[
  // 'SQLite format 3' followed by a zero byte
  0x53, 0x51, 0x4c, 0x69, 0x74, 0x65, 0x20, 0x66,
  0x6f, 0x72, 0x6d, 0x61, 0x74, 0x20, 0x33, 0x00,
];

/// Journal files SQLite may keep next to a database.
const sqliteSidecarSuffixes = ['-wal', '-shm', '-journal'];

/// Whether [bytes] start like a SQLite database file.
bool hasSqliteHeader(List<int> bytes) {
  if (bytes.length < sqliteHeader.length) return false;
  for (var i = 0; i < sqliteHeader.length; i++) {
    if (bytes[i] != sqliteHeader[i]) return false;
  }
  return true;
}

/// Whether [file] is a SQLite database (checked on its header, not its name,
/// since file pickers do not always keep the extension).
Future<bool> isSqliteDatabaseFile(File file) async {
  if (!await file.exists()) return false;
  final handle = await file.open();
  try {
    return hasSqliteHeader(await handle.read(sqliteHeader.length));
  } finally {
    await handle.close();
  }
}

/// Deletes the database at [path] and its journal files.
Future<void> deleteSqliteDbFiles(String path) async {
  for (final candidate in [
    path,
    for (final s in sqliteSidecarSuffixes) '$path$s'
  ]) {
    final file = File(candidate);
    if (await file.exists()) await file.delete();
  }
}

/// Returns a consistent copy of the open database.
///
/// `VACUUM INTO` writes a self-contained file that includes changes still in
/// the write-ahead log, which a plain file copy would miss. Falls back to
/// checkpointing and reading [dbPath] on SQLite builds without it.
Future<Uint8List> snapshotDatabase(GeneratedDatabase db, String dbPath) async {
  final snapshot = File(
    '${File(dbPath).parent.path}${Platform.pathSeparator}'
    'backup_${DateTime.now().microsecondsSinceEpoch}.sqlite',
  );
  try {
    final escaped = snapshot.path.replaceAll("'", "''");
    await db.customStatement("VACUUM INTO '$escaped'");
    return await snapshot.readAsBytes();
  } catch (_) {
    try {
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {
      // Not in WAL mode: the main file is already complete
    }
    return File(dbPath).readAsBytes();
  } finally {
    if (await snapshot.exists()) await snapshot.delete();
  }
}
