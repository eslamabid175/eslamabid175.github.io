---
name: db-migration
description: Change a local drift (SQLite) schema safely - additive changes, schemaVersion bump, a row-preserving onUpgrade step, DAO/mapper updates, codegen, and a live upgrade check. Use for "add a field/table", "change a column", "migration", or when a feature needs new stored data. (Adapt the same rules for Isar/Hive/sqflite.)
argument-hint: "<schema change>"
---
Change: $ARGUMENTS

Users' data lives on their phones. A migration that loses or corrupts rows
cannot be undone, so be conservative.

1. **Investigate**: the database class (`schemaVersion` getter and
   `MigrationStrategy`/`onUpgrade`), the table class, its DAO, its mappers,
   and any data-model doc. Find every reader of the table (grep the table
   and DAO names).
2. **Design**: prefer additive changes - a new nullable column, a column with
   a default, or a new table. A rename or drop needs an explicit
   copy-then-drop step and the user's approval. Keep types consistent with
   neighbouring columns (e.g. money as integer minor units, timestamps the
   same way as existing ones).
3. **Code**:
   - change the table; bump `schemaVersion` N -> N+1;
   - add the step inside a replayed loop so a phone that skipped releases
     still runs every step in order:
     ```dart
     onUpgrade: (m, from, to) async {
       for (var v = from; v < to; v++) {
         switch (v) {
           case 1: await m.addColumn(items, items.note); // v1 -> v2
           // case N: ... // vN -> vN+1
         }
       }
     },
     ```
   - never edit a step that has shipped; never use a standalone
     `if (from == N)` check;
   - indexes: `CREATE INDEX IF NOT EXISTS ...`;
   - `dart run build_runner build --delete-conflicting-outputs`.
   - Optional: `dart run drift_dev make-migrations` to export schema snapshots
     and generate migration tests.
4. **Layers**: DAO -> mapper -> entity (keep the domain layer free of drift
   types) -> repository.
5. **Sync** (if the table syncs to a backend): register the table/field
   wherever the sync layer lists them and update backend rules/serializers.
6. **Docs**: update the data-model doc (table, column, type, nullability,
   default, the version it arrived in).
7. **Verify**: `/verify-change`. Live check: install the previous release on
   an emulator, create data, upgrade to the debug build, confirm the rows
   survive.

Output: the schema diff, N -> N+1, the onUpgrade step, sync impact, docs
updated, verification results.
