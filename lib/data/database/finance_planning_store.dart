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

  static Future<List<FinancialAccount>> getAccounts(Database db) async {
    await ensureTables(db);
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
      await db.insert('financial_accounts', account.toMap());
    } else {
      await db.update('financial_accounts', account.toMap(), where: 'id = ?', whereArgs: [account.id]);
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
    await ensureTables(db);
    return {
      'financial_accounts': await db.query('financial_accounts', orderBy: 'id ASC'),
      'budgets': await db.query('budgets', orderBy: 'id ASC'),
      'financial_goals': await db.query('financial_goals', orderBy: 'id ASC'),
    };
  }
}
