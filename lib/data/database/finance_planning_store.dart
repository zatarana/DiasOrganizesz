import 'package:sqflite/sqflite.dart';

import '../models/budget_model.dart';
import '../models/financial_account_model.dart';
import '../models/financial_goal_model.dart';

class FinancePlanningStore {
  static Future<void> ensureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS financial_accounts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        initialBalance REAL NOT NULL DEFAULT 0,
        currentBalance REAL NOT NULL DEFAULT 0,
        color TEXT NOT NULL DEFAULT '0xFF2196F3',
        icon TEXT NOT NULL DEFAULT 'account_balance',
        isArchived INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        categoryId INTEGER,
        limitAmount REAL NOT NULL,
        month TEXT NOT NULL,
        isArchived INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS financial_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        targetAmount REAL NOT NULL,
        currentAmount REAL NOT NULL DEFAULT 0,
        targetDate TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        color TEXT NOT NULL DEFAULT '0xFF4CAF50',
        icon TEXT NOT NULL DEFAULT 'flag',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0.0;
  }

  static Future<double> _paidTransactionDelta(Database db, int accountId) async {
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(
        CASE
          WHEN type = 'income' THEN amount
          WHEN type = 'expense' THEN -amount
          ELSE 0
        END
      ), 0) AS delta
      FROM transactions
      WHERE status = 'paid' AND accountId = ?
      ''',
      [accountId],
    );
    return _asDouble(rows.first['delta']);
  }

  static Future<void> recalculateAccountBalance(Database db, int accountId) async {
    await ensureTables(db);
    final rows = await db.query('financial_accounts', where: 'id = ?', whereArgs: [accountId], limit: 1);
    if (rows.isEmpty) return;
    final account = FinancialAccount.fromMap(rows.first);
    final delta = await _paidTransactionDelta(db, accountId);
    await db.update(
      'financial_accounts',
      {
        'currentBalance': account.initialBalance + delta,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [accountId],
    );
  }

  static Future<void> recalculateAllAccountBalances(Database db) async {
    await ensureTables(db);
    final rows = await db.query('financial_accounts', columns: ['id']);
    for (final row in rows) {
      final id = row['id'];
      if (id is int) await recalculateAccountBalance(db, id);
    }
  }

  static Future<List<FinancialAccount>> getAccounts(Database db) async {
    await recalculateAllAccountBalances(db);
    final rows = await db.query('financial_accounts', orderBy: 'isArchived ASC, name ASC');
    return rows.map(FinancialAccount.fromMap).toList();
  }

  static Future<List<Budget>> getBudgets(Database db) async {
    await ensureTables(db);
    final rows = await db.query('budgets', orderBy: 'month DESC, name ASC');
    return rows.map(Budget.fromMap).toList();
  }

  static Future<List<FinancialGoal>> getGoals(Database db) async {
    await ensureTables(db);
    final rows = await db.query('financial_goals', orderBy: 'status ASC, targetDate ASC, name ASC');
    return rows.map(FinancialGoal.fromMap).toList();
  }

  static Future<void> upsertAccount(Database db, FinancialAccount account) async {
    await ensureTables(db);
    if (account.id == null) {
      await db.insert('financial_accounts', account.copyWith(currentBalance: account.initialBalance).toMap());
    } else {
      await db.update('financial_accounts', account.toMap(), where: 'id = ?', whereArgs: [account.id]);
      await recalculateAccountBalance(db, account.id!);
    }
  }

  static Future<void> upsertBudget(Database db, Budget budget) async {
    await ensureTables(db);
    if (budget.id == null) {
      await db.insert('budgets', budget.toMap());
    } else {
      await db.update('budgets', budget.toMap(), where: 'id = ?', whereArgs: [budget.id]);
    }
  }

  static Future<void> upsertGoal(Database db, FinancialGoal goal) async {
    await ensureTables(db);
    if (goal.id == null) {
      await db.insert('financial_goals', goal.toMap());
    } else {
      await db.update('financial_goals', goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);
    }
  }

  static Future<void> clearCategoryLinks(Database db, int categoryId) async {
    await ensureTables(db);
    await db.update('budgets', {'categoryId': null}, where: 'categoryId = ?', whereArgs: [categoryId]);
  }

  static Future<void> resetPlanningData(Database db) async {
    await ensureTables(db);
    await db.delete('financial_accounts');
    await db.delete('budgets');
    await db.delete('financial_goals');
  }

  static Future<Map<String, dynamic>> exportTables(Database db) async {
    await recalculateAllAccountBalances(db);
    return {
      'financial_accounts': await db.query('financial_accounts', orderBy: 'id ASC'),
      'budgets': await db.query('budgets', orderBy: 'id ASC'),
      'financial_goals': await db.query('financial_goals', orderBy: 'id ASC'),
    };
  }
}
