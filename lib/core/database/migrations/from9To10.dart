// ignore_for_file: file_names

import 'package:drift/drift.dart';
import 'package:mindful/core/database/schemas/schema_versions.dart';
import 'package:mindful/core/utils/db_utils.dart';

Future<void> from9To10(Migrator m, Schema10 schema) async => await runSafe(
      "Migration(9 to 10)",
      () async {
        /// Add [activePeriods] column to [RestrictionGroupsTable]
        await m.addColumn(
          schema.restrictionGroupsTable,
          schema.restrictionGroupsTable.activePeriods,
        );

        /// Migrate any existing single active period (where start != end) into a
        /// one-entry [activePeriods] list enabled on all weekdays, so previously
        /// configured group windows keep working.
        await m.database.customStatement(
          'UPDATE restriction_groups_table '
          'SET active_periods = \'[{"start":\' || active_period_start || '
          '\',"end":\' || active_period_end || '
          '\',"days":[true,true,true,true,true,true,true]}]\' '
          'WHERE active_period_start != active_period_end',
        );
      },
    );
