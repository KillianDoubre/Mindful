import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mindful/core/database/app_database.dart';
import 'package:mindful/core/services/drift_db_service.dart';

/// The channel every native call goes through.
const fgChannel = MethodChannel('com.mindful.android.methodchannel.fg');

/// Native calls recorded by [mockNativeChannel].
final nativeCalls = <MethodCall>[];

/// Answers every native call instead of Android. [responses] lets a test
/// return data for a given method; anything else answers `true`.
void mockNativeChannel([Map<String, Object? Function(MethodCall)>? responses]) {
  TestWidgetsFlutterBinding.ensureInitialized();
  nativeCalls.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(fgChannel, (call) async {
    nativeCalls.add(call);
    final respond = responses?[call.method];
    return respond == null ? true : respond(call);
  });
}

List<MethodCall> callsTo(String method) =>
    nativeCalls.where((call) => call.method == method).toList();

/// Points the app's database service at a fresh in-memory database.
///
/// Repositories are singletons that create their tables once, so a test
/// file should open one database in `setUpAll` and clean tables in `setUp`.
AppDatabase useInMemoryDatabase() {
  final db = AppDatabase(NativeDatabase.memory());
  DriftDbService.instance.driftDb = db;
  return db;
}

/// Empties the given tables if they exist.
Future<void> clearTables(AppDatabase db, List<String> tables) async {
  for (final table in tables) {
    final exists = await db.customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
      variables: [Variable.withString(table)],
    ).get();
    if (exists.isNotEmpty) await db.customStatement('DELETE FROM $table');
  }
}

/// Local midnight of [date] shifted by [days].
DateTime dayOffset(int days, [DateTime? from]) {
  final base = from ?? DateTime.now();
  return DateTime(base.year, base.month, base.day + days);
}
