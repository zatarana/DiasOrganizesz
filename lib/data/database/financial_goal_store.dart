import 'package:sqflite/sqflite.dart';

import '../models/financial_goal_model.dart';

class FinancialGoalStore {
  static bool _indexesEnsured = false;

  static Future<void> ensureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS financial_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        targetAmount REAL NOT NULL,
        currentAmount REAL NOT NULL DEFAULT 0,
        accountId INTEGER,
        projectId INTEGER,
        targetDate TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        color TEXT NOT NULL DEFAULT '0xFF4CAF50',
        icon TEXT NOT NULL DEFAULT 'flag',
        isArchived INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await _addColumnIfMissing(db, 'financial_goals', 'isArchived INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'financial_goals', 'projectId INTEGER');
    await _ensureIndexes(db);
  }

  static Future<void> _ensureIndexes(Database db) async {
    if (_indexesEnsured) return;
    await db.execute('CREATE INDEX IF NOT EXISTS idx_financial_goals_status_archived ON financial_goals(status, isArchived)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_financial_goals_target_date ON financial_goals(targetDate)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_financial_goals_project ON financial_goals(projectId, isArchived)');
    _indexesEnsured = true;
  }

  static Future<void> _addColumnIfMissing(Database db, String table, String columnSql) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnSql');
    } catch (_) {}
  }

  static Future<List<FinancialGoal>> getGoals(Database db, {bool includeArchived = false}) async {
    await ensureTables(db);
    final rows = await db.query(
      'financial_goals',
      where: includeArchived ? null : 'isArchived = 0',
      orderBy: 'isArchived ASC, status ASC, targetDate IS NULL ASC, targetDate ASC, name ASC',
    );
    return rows.map(FinancialGoal.fromMap).toList();
  }

  static Future<List<FinancialGoal>> getGoalsForProject(Database db, int projectId, {bool includeArchived = false}) async {
    await ensureTables(db);
    final rows = await db.query(
      'financial_goals',
      where: includeArchived ? 'projectId = ?' : 'projectId = ? AND isArchived = 0',
      whereArgs: [projectId],
      orderBy: 'status ASC, targetDate IS NULL ASC, targetDate ASC, name ASC',
    );
    return rows.map(FinancialGoal.fromMap).toList();
  }

  static Future<int> upsertGoal(Database db, FinancialGoal goal) async {
    await ensureTables(db);
    if (goal.name.trim().isEmpty) throw ArgumentError('O nome do objetivo é obrigatório.');
    if (goal.targetAmount <= 0) throw ArgumentError('O valor alvo deve ser maior que zero.');
    if (goal.currentAmount < 0) throw ArgumentError('O valor atual não pode ser negativo.');
    if (goal.id == null) return db.insert('financial_goals', goal.toMap());
    await db.update('financial_goals', goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);
    return goal.id!;
  }

  static Future<void> archiveGoal(Database db, int goalId) async {
    await ensureTables(db);
    await db.update(
      'financial_goals',
      {
        'isArchived': 1,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [goalId],
    );
  }

  static Future<void> updateGoalProgress(Database db, int goalId, double currentAmount) async {
    await ensureTables(db);
    if (currentAmount < 0) throw ArgumentError('O valor atual não pode ser negativo.');
    final rows = await db.query('financial_goals', where: 'id = ?', whereArgs: [goalId], limit: 1);
    if (rows.isEmpty) throw ArgumentError('Objetivo financeiro não encontrado.');
    final goal = FinancialGoal.fromMap(rows.first);
    final completed = currentAmount >= goal.targetAmount;
    await db.update(
      'financial_goals',
      {
        'currentAmount': currentAmount,
        'status': completed ? 'completed' : goal.status == 'completed' ? 'active' : goal.status,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [goalId],
    );
  }

  static Future<void> resetGoalData(Database db) async {
    await ensureTables(db);
    await db.delete('financial_goals');
  }

  static Future<Map<String, dynamic>> exportTables(Database db) async {
    await ensureTables(db);
    return {
      'financial_goals': await db.query('financial_goals', orderBy: 'id ASC'),
    };
  }
}
