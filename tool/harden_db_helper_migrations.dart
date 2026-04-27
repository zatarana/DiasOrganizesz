import 'dart:io';

void main() {
  final file = File('lib/data/database/db_helper.dart');
  if (!file.existsSync()) {
    stderr.writeln('db_helper.dart não encontrado. Execute o script na raiz do projeto.');
    exit(1);
  }

  var content = file.readAsStringSync();

  if (!content.contains("import 'migration_utils.dart';")) {
    content = content.replaceFirst(
      "import 'finance_planning_store.dart';\n",
      "import 'finance_planning_store.dart';\nimport 'migration_utils.dart';\n",
    );
  }

  const oldMethod = '''  Future<void> _addColumnIfMissing(Database db, String table, String columnSql) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnSql');
    } catch (_) {}
  }
''';

  const newMethod = '''  Future<void> _addColumnIfMissing(Database db, String table, String columnSql) async {
    return MigrationUtils.addColumnIfMissing(
      db,
      table,
      columnSql,
      logName: 'DatabaseHelper.migration',
    );
  }
''';

  if (content.contains(oldMethod)) {
    content = content.replaceFirst(oldMethod, newMethod);
  } else if (!content.contains('MigrationUtils.addColumnIfMissing')) {
    stderr.writeln('Método _addColumnIfMissing não encontrado no formato esperado. Nenhuma alteração aplicada.');
    exit(2);
  }

  file.writeAsStringSync(content);
  stdout.writeln('db_helper.dart atualizado: migrações inesperadas agora são logadas e propagadas.');
}
