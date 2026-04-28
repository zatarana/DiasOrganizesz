import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/database/db_helper.dart';
import '../../data/database/finance_planning_store.dart';

class BackupService {
  static const int backupFormatVersion = 2;
  static int get databaseVersion => DatabaseHelper.schemaVersion;

  Future<String> exportJson(DatabaseHelper dbHelper) async {
    final db = await dbHelper.database;
    final exportedAt = DateTime.now();

    final tables = <String, dynamic>{
      'categories': await db.query('categories', orderBy: 'id ASC'),
      'financial_categories': await db.query('financial_categories', orderBy: 'id ASC'),
      'tasks': await db.query('tasks', orderBy: 'id ASC'),
      'transactions': await db.query('transactions', orderBy: 'id ASC'),
      'debts': await db.query('debts', orderBy: 'id ASC'),
      'projects': await db.query('projects', orderBy: 'id ASC'),
      'project_steps': await db.query('project_steps', orderBy: 'id ASC'),
      'settings': await db.query('settings', orderBy: 'key ASC'),
      ...await FinancePlanningStore.exportTables(db),
    };

    try {
      tables['project_stages_legacy'] = await db.query('project_stages', orderBy: 'id ASC');
    } catch (_) {
      tables['project_stages_legacy'] = <Map<String, Object?>>[];
    }

    final payload = <String, dynamic>{
      'app': 'DiasOrganize',
      'backupFormatVersion': backupFormatVersion,
      'databaseVersion': databaseVersion,
      'exportedAt': exportedAt.toIso8601String(),
      'warning': 'Arquivo de backup gerado automaticamente. Não edite se pretende restaurar futuramente.',
      'tables': tables,
    };

    final directory = await _backupDirectory();
    await directory.create(recursive: true);

    final safeTimestamp = exportedAt.toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File(p.join(directory.path, 'diasorganize_backup_$safeTimestamp.json'));
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(payload), flush: true);

    return file.path;
  }

  Future<Directory> _backupDirectory() async {
    final external = await getExternalStorageDirectory();
    final base = external ?? await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, 'backups'));
  }
}
