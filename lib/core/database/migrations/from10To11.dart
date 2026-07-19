// ignore_for_file: file_names

import 'package:drift/drift.dart';
import 'package:mindful/core/database/schemas/schema_versions.dart';
import 'package:mindful/core/utils/db_utils.dart';

Future<void> from10To11(Migrator m, Schema11 schema) async => await runSafe(
      "Migration(10 to 11)",
      () async {
        /// Add [datingBlocks] column to [WellbeingTable] (defaults to empty list)
        await m.addColumn(
          schema.wellbeingTable,
          schema.wellbeingTable.datingBlocks,
        );
      },
    );
