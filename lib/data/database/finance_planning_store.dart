import 'package:sqflite/sqflite.dart';

import '../models/budget_model.dart';
import '../models/financial_account_model.dart';
import '../models/financial_balance_adjustment_model.dart';
import '../models/financial_goal_model.dart';
import '../models/financial_transfer_model.dart';

class FinancePlanningStore {
  static bool _indexesEnsured = false;

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
        ignoreInTotals INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS financial_transfers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fromAccountId INTEGER NOT NULL,
        toAccountId INTEGER NOT NULL,
        amount REAL NOT NULL,
        transferDate TEXT NOT NULL,
        description TEXT,
        notes TEXT,
        ignoreInReports INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS financial_balance_adjustments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        accountId INTEGER NOT NULL,
        previousBalance REAL NOT NULL,
        newBalance REAL NOT NULL,
        delta REAL NOT NULL,
        adjustmentDate TEXT NOT NULL,
        reason TEXT,
        notes TEXT,
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
        accountId INTEGER,
        targetDate TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        color TEXT NOT NULL DEFAULT '0xFF4CAF50',
        icon TEXT NOT NULL DEFAULT 'flag',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await _addColumnIfMissing(db, 'financial_accounts', 'ignoreInTotals INTEGER NOT NULL DEFAULT 0');
    await _addColumnIfMissing(db, 'financial_goals', 'accountId INTEGER');
    await _addColumnIfMissing(db, 'financial_transfers', 'notes TEXT');
    await _addColumnIfMissing(db, 'financial_transfers', 'ignoreInReports INTEGER NOT NULL DEFAULT 0');
    await _ensureIndexes(db);
  }

  static Future<void> _ensureIndexes(Database db) async {
    if (_indexesEnsured) return;
    await db.execute('CREATE INDEX IF NOT EXISTS idx_financial_accounts_archived_name ON financial_accounts(isArchived, name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_financial_accounts_total ON financial_accounts(isArchived, ignoreInTotals)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_financial_transfers_from_date ON financial_transfers(fromAccountId, transferDate)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_financial_transfers_to_date ON financial_transfers(toAccountId, transferDate)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_financial_balance_adjustments_account_date ON financial_balance_adjustments(accountId, adjustmentDate)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_financial_goals_status_account ON financial_goals(status, accountId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_budgets_month_category ON budgets(month, categoryId, isArchived)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_status_account ON transactions(status, accountId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_due_date ON transactions(dueDate)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_paid_date ON transactions(paidDate)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_category_status ON transactions(categoryId, status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_debt_status ON transactions(debtId, status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_date_status_parent ON tasks(date, status, parentTaskId)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_tasks_project_step_status ON tasks(projectId, projectStepId, status)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_project_steps_project_order ON project_steps(projectId, orderIndex)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_projects_status_end ON projects(status, endDate)');
    _indexesEnsured = true;
  }

  static Future<void> _addColumnIfMissing(Database db, String table, String columnSql) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnSql');
    } catch (_) {}
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

  static Future<double> _transferDelta(Database db, int accountId) async {
    final rows = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(CASE WHEN toAccountId = ? THEN amount ELSE 0 END), 0) -
        COALESCE(SUM(CASE WHEN fromAccountId = ? THEN amount ELSE 0 END), 0) AS delta
      FROM financial_transfers
      WHERE fromAccountId = ? OR toAccountId = ?
      ''',
      [accountId, accountId, accountId, accountId],
    );
    return _asDouble(rows.first['delta']);
  }

  static Future<double> _adjustmentDelta(Database db, int accountId) async {
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(delta), 0) AS delta
      FROM financial_balance_adjustments
      WHERE accountId = ?
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
    final transactionDelta = await _paidTransactionDelta(db, accountId);
    final transferDelta = await _transferDelta(db, accountId);
    final adjustmentDelta = await _adjustmentDelta(db, accountId);
    await db.update(
      'financial_accounts',
      {
        'currentBalance': account.initialBalance + transactionDelta + transferDelta + adjustmentDelta,
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

  static Future<List<FinancialAccount>> getAccounts(Database db, {bool recalculateBeforeRead = false}) async {
    await ensureTables(db);
    if (recalculateBeforeRead) await recalculateAllAccountBalances(db);
    final rows = await db.query('financial_accounts', orderBy: 'isArchived ASC, ignoreInTotals ASC, name ASC');
    return rows.map(FinancialAccount.fromMap).toList();
  }

  static Future<List<FinancialTransfer>> getTransfers(Database db) async {
    await ensureTables(db);
    final rows = await db.query('financial_transfers', orderBy: 'transferDate DESC, id DESC');
    return rows.map(FinancialTransfer.fromMap).toList();
  }

  static Future<List<FinancialBalanceAdjustment>> getBalanceAdjustments(Database db, {int? accountId}) async {
    await ensureTables(db);
    final rows = await db.query(
      'financial_balance_adjustments',
      where: accountId == null ? null : 'accountId = ?',
      whereArgs: accountId == null ? null : [accountId],
      orderBy: 'adjustmentDate DESC, id DESC',
    );
    return rows.map(FinancialBalanceAdjustment.fromMap).toList();
  }

  static Future<double> getActiveAccountsBalance(Database db) async {
    await ensureTables(db);
    final rows = await db.rawQuery('''
      SELECT COALESCE(SUM(currentBalance), 0) AS total
      FROM financial_accounts
      WHERE isArchived = 0 AND ignoreInTotals = 0
    ''');
    return _asDouble(rows.first['total']);
  }

  static Future<List<Budget>> getBudgets(Database db) async {
    await ensureTables(db);
    final rows = await db.query('budgets', orderBy: 'month DESC, name ASC');
    return rows.map(Budget.fromMap).toList();
  }

  static Future<List<FinancialGoal>> getGoals(Database db) async {
    await ensureTables(db);
    await clearArchivedAccountGoalLinks(db);
    final rows = await db.query('financial_goals', orderBy: 'status ASC, targetDate ASC, name ASC');
    return rows.map(FinancialGoal.fromMap).toList();
  }

  static Future<int> upsertAccount(Database db, FinancialAccount account) async {
    await ensureTables(db);
    if (account.id == null) {
      return db.insert('financial_accounts', account.copyWith(currentBalance: account.initialBalance).toMap());
    }
    await db.update('financial_accounts', account.toMap(), where: 'id = ?', whereArgs: [account.id]);
    await recalculateAccountBalance(db, account.id!);
    if (account.isArchived) await clearGoalAccountLinks(db, account.id!);
    return account.id!;
  }

  static Future<int> upsertTransfer(Database db, FinancialTransfer transfer) async {
    await ensureTables(db);
    if (transfer.amount <= 0) throw ArgumentError('O valor da transferência deve ser maior que zero.');
    if (transfer.fromAccountId == transfer.toAccountId) throw ArgumentError('A conta de origem e destino devem ser diferentes.');

    final affectedAccountIds = <int>{transfer.fromAccountId, transfer.toAccountId};
    if (transfer.id != null) {
      final oldRows = await db.query('financial_transfers', where: 'id = ?', whereArgs: [transfer.id], limit: 1);
      if (oldRows.isNotEmpty) {
        final oldTransfer = FinancialTransfer.fromMap(oldRows.first);
        affectedAccountIds.add(oldTransfer.fromAccountId);
        affectedAccountIds.add(oldTransfer.toAccountId);
      }
    }

    late int transferId;
    await db.transaction((txn) async {
      if (transfer.id == null) {
        transferId = await txn.insert('financial_transfers', transfer.toMap());
      } else {
        transferId = transfer.id!;
        await txn.update('financial_transfers', transfer.toMap(), where: 'id = ?', whereArgs: [transfer.id]);
      }
    });
    for (final accountId in affectedAccountIds) {
      await recalculateAccountBalance(db, accountId);
    }
    return transferId;
  }

  static Future<int> createBalanceAdjustment(Database db, {required int accountId, required double newBalance, String? reason, String? notes}) async {
    await ensureTables(db);
    await recalculateAccountBalance(db, accountId);
    final rows = await db.query('financial_accounts', where: 'id = ?', whereArgs: [accountId], limit: 1);
    if (rows.isEmpty) throw ArgumentError('Conta não encontrada.');
    final account = FinancialAccount.fromMap(rows.first);
    final previousBalance = account.currentBalance;
    final delta = newBalance - previousBalance;
    final now = DateTime.now().toIso8601String();
    final adjustment = FinancialBalanceAdjustment(
      accountId: accountId,
      previousBalance: previousBalance,
      newBalance: newBalance,
      delta: delta,
      adjustmentDate: now,
      reason: reason,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    final id = await db.insert('financial_balance_adjustments', adjustment.toMap());
    await recalculateAccountBalance(db, accountId);
    return id;
  }

  static Future<void> deleteTransfer(Database db, FinancialTransfer transfer) async {
    await ensureTables(db);
    if (transfer.id == null) return;
    await db.delete('financial_transfers', where: 'id = ?', whereArgs: [transfer.id]);
    await recalculateAccountBalance(db, transfer.fromAccountId);
    await recalculateAccountBalance(db, transfer.toAccountId);
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
    if (goal.accountId != null) {
      final accountRows = await db.query('financial_accounts', where: 'id = ? AND isArchived = 0', whereArgs: [goal.accountId], limit: 1);
      if (accountRows.isEmpty) goal = goal.copyWith(clearAccountId: true);
    }
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

  static Future<void> clearGoalAccountLinks(Database db, int accountId) async {
    await ensureTables(db);
    await db.update('financial_goals', {'accountId': null}, where: 'accountId = ?', whereArgs: [accountId]);
  }

  static Future<void> clearArchivedAccountGoalLinks(Database db) async {
    await ensureTables(db);
    await db.rawUpdate('''
      UPDATE financial_goals
      SET accountId = NULL
      WHERE accountId IS NOT NULL
        AND accountId NOT IN (SELECT id FROM financial_accounts WHERE isArchived = 0)
    ''');
  }

  static Future<void> resetPlanningData(Database db) async {
    await ensureTables(db);
    await db.delete('financial_accounts');
    await db.delete('financial_transfers');
    await db.delete('financial_balance_adjustments');
    await db.delete('budgets');
    await db.delete('financial_goals');
  }

  static Future<Map<String, dynamic>> exportTables(Database db) async {
    await recalculateAllAccountBalances(db);
    await clearArchivedAccountGoalLinks(db);
    return {
      'financial_accounts': await db.query('financial_accounts', orderBy: 'id ASC'),
      'financial_transfers': await db.query('financial_transfers', orderBy: 'id ASC'),
      'financial_balance_adjustments': await db.query('financial_balance_adjustments', orderBy: 'id ASC'),
      'budgets': await db.query('budgets', orderBy: 'id ASC'),
      'financial_goals': await db.query('financial_goals', orderBy: 'id ASC'),
    };
  }
}
