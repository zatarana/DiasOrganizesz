import 'dart:developer' as developer;

import 'package:sqflite/sqflite.dart';

class MigrationUtils {
  const MigrationUtils._();

  static bool isDuplicateColumnError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('duplicate column name') || message.contains('duplicate column');
  }

  static Future<void> addColumnIfMissing(
    Database db,
    String table,
    String columnSql, {
    String logName = 'DatabaseMigration',
  }) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnSql');
    } catch (error, stackTrace) {
      if (isDuplicateColumnError(error)) return;
      developer.log(
        'Falha inesperada ao adicionar coluna em $table: $columnSql',
        name: logName,
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
