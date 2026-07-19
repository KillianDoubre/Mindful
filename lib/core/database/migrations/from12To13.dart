// ignore_for_file: file_names

import 'package:drift/drift.dart';
import 'package:mindful/core/database/schemas/schema_versions.dart';
import 'package:mindful/core/utils/db_utils.dart';

Future<void> from12To13(Migrator m, Schema13 schema) async => await runSafe(
      "Migration(12 to 13)",
      () async {
        await m.addColumn(
          schema.restrictionGroupsTable,
          schema.restrictionGroupsTable.isIntentPromptEnabled,
        );
      },
    );
