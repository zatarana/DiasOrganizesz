import 'package:diasorganize/core/backup/backup_service.dart';
import 'package:diasorganize/data/database/db_helper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backup database version follows the current SQLite schema version', () {
    expect(BackupService.databaseVersion, DatabaseHelper.schemaVersion);
  });
}
