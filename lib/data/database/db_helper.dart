import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import 'finance_planning_store.dart';
import '../models/category_model.dart';
import '../models/financial_category_model.dart';
import '../models/project_step_model.dart';
import '../models/setting_model.dart';
import '../models/task_model.dart';
import '../models/transaction_model.dart';

class DatabaseHelper {
  static const int schemaVersion = 17;
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('diasorganize.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);
    await _copyLegacyDatabaseIfNeeded(dbPath, path);

    return openDatabase(path, version: schemaVersion, onConfigure: _onConfigure, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _copyLegacyDatabaseIfNeeded(String dbPath, String targetPath) async {
    final target = File(targetPath);
    if (await target.exists()) return;

    const legacyNames = [
      'diasorganize_v15.db',
      'diasorganize_v14.db',
      'diasorganize_v13.db',
      'diasorganize_v12.db',
      'diasorganize_v11.db',
      'diasorganize_v10.db',
      'diasorganize_v9.db',
      'diasorganize_v8.db',
      'diasorganize_v7.db',
      'diasorganize_v6.db',
      'diasorganize_v5.db',
      'diasorganize_v4.db',
      'diasorganize_v3.db',
      'diasorganize_v2.db',
      'diasorganize_v1.db',
    ];

    for (final legacyName in legacyNames) {
      final legacyPath = join(dbPath, legacyName);
      final legacyFile = File(legacyPath);
      if (await legacyFile.exists()) {
        await legacyFile.copy(targetPath);
        await _copySidecarIfExists('$legacyPath-wal', '$targetPath-wal');
        await _copySidecarIfExists('$legacyPath-shm', '$targetPath-shm');
        return;
      }
    }
  }

  Future<void> _copySidecarIfExists(String sourcePath, String targetPath) async {
    final source = File(sourcePath);
    if (await source.exists()) await source.copy(targetPath);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
      await _createFinancialCategoriesTable(db);
      await _seedFinancialCategories(db);
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS debts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT,
          title TEXT,
          description TEXT,
          totalAmount REAL NOT NULL,
          installmentCount INTEGER,
          installmentsCount INTEGER,
          installmentAmount REAL,
          installmentValue REAL,
          startDate TEXT,
          firstDueDate TEXT,
          categoryId INTEGER,
          creditorName TEXT,
          creditor TEXT,
          status TEXT NOT NULL,
          notes TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');
      await _addColumnIfMissing(db, 'transactions', 'debtId INTEGER');
      await _addColumnIfMissing(db, 'transactions', 'installmentNumber INTEGER');
      await _addColumnIfMissing(db, 'transactions', 'totalInstallments INTEGER');
    }
    if (oldVersion < 7) {
      await _addColumnIfMissing(db, 'debts', 'categoryId INTEGER');
      await _addColumnIfMissing(db, 'debts', 'installmentsCount INTEGER');
      await _addColumnIfMissing(db, 'debts', 'installmentValue REAL');
      await _addColumnIfMissing(db, 'debts', 'firstDueDate TEXT');
      await _addColumnIfMissing(db, 'transactions', 'discountAmount REAL DEFAULT 0');
    }
    if (oldVersion < 8) {
      await _createProjectsTable(db);
      await _addColumnIfMissing(db, 'tasks', 'projectId INTEGER');
    }
    if (oldVersion < 9) {
      await _addColumnIfMissing(db, 'projects', 'priority TEXT NOT NULL DEFAULT "media"');
      await _addColumnIfMissing(db, 'projects', 'color TEXT NOT NULL DEFAULT "0xFF2196F3"');
      await _addColumnIfMissing(db, 'projects', 'icon TEXT NOT NULL DEFAULT "rocket_launch"');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS project_stages (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          projectId INTEGER NOT NULL,
          title TEXT NOT NULL,
          stageOrder INTEGER NOT NULL DEFAULT 0,
          createdAt TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 10) {
      await _createProjectStepsTable(db);
      try {
        final oldRows = await db.query('project_stages', orderBy: 'stageOrder ASC, id ASC');
        for (final row in oldRows) {
          await db.insert('project_steps', {
            'projectId': row['projectId'],
            'title': row['title'],
            'description': null,
            'orderIndex': row['stageOrder'] ?? 0,
            'status': 'pending',
            'dueDate': null,
            'completedAt': null,
            'reminderEnabled': 0,
            'createdAt': row['createdAt'],
            'updatedAt': row['createdAt'],
          });
        }
      } catch (_) {}
    }
    if (oldVersion < 11) await _addColumnIfMissing(db, 'tasks', 'projectStepId INTEGER');
    if (oldVersion < 12) {
      await _addColumnIfMissing(db, 'projects', 'notes TEXT');
      await _addColumnIfMissing(db, 'projects', 'completedAt TEXT');
    }
    if (oldVersion < 13) await _addColumnIfMissing(db, 'projects', 'progress REAL NOT NULL DEFAULT 0');
    if (oldVersion < 14) {
      await _addColumnIfMissing(db, 'transactions', 'reminderEnabled INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfMissing(db, 'projects', 'reminderEnabled INTEGER NOT NULL DEFAULT 0');
      await _addColumnIfMissing(db, 'project_steps', 'reminderEnabled INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 15) {
      await FinancePlanningStore.ensureTables(db);
      await _addColumnIfMissing(db, 'transactions', 'accountId INTEGER');
    }
    if (oldVersion < 16) {
      await _addColumnIfMissing(db, 'tasks', 'parentTaskId INTEGER');
      await _addColumnIfMissing(db, 'tasks', 'recurrenceType TEXT NOT NULL DEFAULT "none"');
    }
    if (oldVersion < 17) {
      await _migrateReferentialIntegrity(db);
    }
  }

  Future<void> _migrateReferentialIntegrity(Database db) async {
    await FinancePlanningStore.ensureTables(db);
    await _ensureTaskColumns(db);

    await db.rawUpdate('UPDATE tasks SET categoryId = NULL WHERE categoryId IS NOT NULL AND categoryId NOT IN (SELECT id FROM categories)');
    await db.rawUpdate('UPDATE tasks SET projectId = NULL, projectStepId = NULL WHERE projectId IS NOT NULL AND projectId NOT IN (SELECT id FROM projects)');
    await db.rawUpdate('UPDATE tasks SET projectStepId = NULL WHERE projectStepId IS NOT NULL AND projectStepId NOT IN (SELECT id FROM project_steps)');
    await db.rawUpdate('UPDATE tasks SET parentTaskId = NULL WHERE parentTaskId IS NOT NULL AND parentTaskId NOT IN (SELECT id FROM tasks)');
    await db.rawDelete('DELETE FROM project_steps WHERE projectId NOT IN (SELECT id FROM projects)');
    await db.rawUpdate('UPDATE transactions SET categoryId = NULL WHERE categoryId IS NOT NULL AND categoryId NOT IN (SELECT id FROM financial_categories)');
    await db.rawUpdate('UPDATE transactions SET debtId = NULL WHERE debtId IS NOT NULL AND debtId NOT IN (SELECT id FROM debts)');
    await db.rawUpdate('UPDATE transactions SET accountId = NULL WHERE accountId IS NOT NULL AND accountId NOT IN (SELECT id FROM financial_accounts)');
    await db.rawUpdate('UPDATE debts SET categoryId = NULL WHERE categoryId IS NOT NULL AND categoryId NOT IN (SELECT id FROM financial_categories)');
    await db.rawUpdate('UPDATE budgets SET categoryId = NULL WHERE categoryId IS NOT NULL AND categoryId NOT IN (SELECT id FROM financial_categories)');
    await db.rawUpdate('UPDATE financial_goals SET accountId = NULL WHERE accountId IS NOT NULL AND accountId NOT IN (SELECT id FROM financial_accounts)');

    await _createReferentialIntegrityTriggers(db);
  }

  Future<void> _createReferentialIntegrityTriggers(Database db) async {
    final statements = <String>[
      """
      CREATE TRIGGER IF NOT EXISTS trg_tasks_category_valid_insert
      BEFORE INSERT ON tasks
      WHEN NEW.categoryId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM categories WHERE id = NEW.categoryId)
      BEGIN SELECT RAISE(ABORT, 'Invalid tasks.categoryId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_tasks_category_valid_update
      BEFORE UPDATE OF categoryId ON tasks
      WHEN NEW.categoryId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM categories WHERE id = NEW.categoryId)
      BEGIN SELECT RAISE(ABORT, 'Invalid tasks.categoryId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_tasks_project_valid_insert
      BEFORE INSERT ON tasks
      WHEN NEW.projectId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM projects WHERE id = NEW.projectId)
      BEGIN SELECT RAISE(ABORT, 'Invalid tasks.projectId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_tasks_project_valid_update
      BEFORE UPDATE OF projectId ON tasks
      WHEN NEW.projectId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM projects WHERE id = NEW.projectId)
      BEGIN SELECT RAISE(ABORT, 'Invalid tasks.projectId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_tasks_step_valid_insert
      BEFORE INSERT ON tasks
      WHEN NEW.projectStepId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM project_steps WHERE id = NEW.projectStepId)
      BEGIN SELECT RAISE(ABORT, 'Invalid tasks.projectStepId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_tasks_step_valid_update
      BEFORE UPDATE OF projectStepId ON tasks
      WHEN NEW.projectStepId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM project_steps WHERE id = NEW.projectStepId)
      BEGIN SELECT RAISE(ABORT, 'Invalid tasks.projectStepId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_tasks_parent_valid_insert
      BEFORE INSERT ON tasks
      WHEN NEW.parentTaskId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM tasks WHERE id = NEW.parentTaskId)
      BEGIN SELECT RAISE(ABORT, 'Invalid tasks.parentTaskId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_tasks_parent_valid_update
      BEFORE UPDATE OF parentTaskId ON tasks
      WHEN NEW.parentTaskId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM tasks WHERE id = NEW.parentTaskId)
      BEGIN SELECT RAISE(ABORT, 'Invalid tasks.parentTaskId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_project_steps_project_valid_insert
      BEFORE INSERT ON project_steps
      WHEN NOT EXISTS (SELECT 1 FROM projects WHERE id = NEW.projectId)
      BEGIN SELECT RAISE(ABORT, 'Invalid project_steps.projectId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_project_steps_project_valid_update
      BEFORE UPDATE OF projectId ON project_steps
      WHEN NOT EXISTS (SELECT 1 FROM projects WHERE id = NEW.projectId)
      BEGIN SELECT RAISE(ABORT, 'Invalid project_steps.projectId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_transactions_category_valid_insert
      BEFORE INSERT ON transactions
      WHEN NEW.categoryId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM financial_categories WHERE id = NEW.categoryId)
      BEGIN SELECT RAISE(ABORT, 'Invalid transactions.categoryId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_transactions_category_valid_update
      BEFORE UPDATE OF categoryId ON transactions
      WHEN NEW.categoryId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM financial_categories WHERE id = NEW.categoryId)
      BEGIN SELECT RAISE(ABORT, 'Invalid transactions.categoryId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_transactions_debt_valid_insert
      BEFORE INSERT ON transactions
      WHEN NEW.debtId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM debts WHERE id = NEW.debtId)
      BEGIN SELECT RAISE(ABORT, 'Invalid transactions.debtId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_transactions_debt_valid_update
      BEFORE UPDATE OF debtId ON transactions
      WHEN NEW.debtId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM debts WHERE id = NEW.debtId)
      BEGIN SELECT RAISE(ABORT, 'Invalid transactions.debtId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_transactions_account_valid_insert
      BEFORE INSERT ON transactions
      WHEN NEW.accountId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM financial_accounts WHERE id = NEW.accountId)
      BEGIN SELECT RAISE(ABORT, 'Invalid transactions.accountId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_transactions_account_valid_update
      BEFORE UPDATE OF accountId ON transactions
      WHEN NEW.accountId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM financial_accounts WHERE id = NEW.accountId)
      BEGIN SELECT RAISE(ABORT, 'Invalid transactions.accountId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_debts_category_valid_insert
      BEFORE INSERT ON debts
      WHEN NEW.categoryId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM financial_categories WHERE id = NEW.categoryId)
      BEGIN SELECT RAISE(ABORT, 'Invalid debts.categoryId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_debts_category_valid_update
      BEFORE UPDATE OF categoryId ON debts
      WHEN NEW.categoryId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM financial_categories WHERE id = NEW.categoryId)
      BEGIN SELECT RAISE(ABORT, 'Invalid debts.categoryId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_budgets_category_valid_insert
      BEFORE INSERT ON budgets
      WHEN NEW.categoryId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM financial_categories WHERE id = NEW.categoryId)
      BEGIN SELECT RAISE(ABORT, 'Invalid budgets.categoryId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_budgets_category_valid_update
      BEFORE UPDATE OF categoryId ON budgets
      WHEN NEW.categoryId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM financial_categories WHERE id = NEW.categoryId)
      BEGIN SELECT RAISE(ABORT, 'Invalid budgets.categoryId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_goals_account_valid_insert
      BEFORE INSERT ON financial_goals
      WHEN NEW.accountId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM financial_accounts WHERE id = NEW.accountId)
      BEGIN SELECT RAISE(ABORT, 'Invalid financial_goals.accountId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_goals_account_valid_update
      BEFORE UPDATE OF accountId ON financial_goals
      WHEN NEW.accountId IS NOT NULL AND NOT EXISTS (SELECT 1 FROM financial_accounts WHERE id = NEW.accountId)
      BEGIN SELECT RAISE(ABORT, 'Invalid financial_goals.accountId'); END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_delete_category_cleanup_tasks
      AFTER DELETE ON categories
      BEGIN UPDATE tasks SET categoryId = NULL WHERE categoryId = OLD.id; END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_delete_fin_category_cleanup
      AFTER DELETE ON financial_categories
      BEGIN
        UPDATE transactions SET categoryId = NULL WHERE categoryId = OLD.id;
        UPDATE debts SET categoryId = NULL WHERE categoryId = OLD.id;
        UPDATE budgets SET categoryId = NULL WHERE categoryId = OLD.id;
      END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_delete_project_cleanup
      AFTER DELETE ON projects
      BEGIN
        UPDATE tasks SET projectId = NULL, projectStepId = NULL WHERE projectId = OLD.id;
        DELETE FROM project_steps WHERE projectId = OLD.id;
      END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_delete_project_step_cleanup
      AFTER DELETE ON project_steps
      BEGIN UPDATE tasks SET projectStepId = NULL WHERE projectStepId = OLD.id; END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_delete_task_cleanup_subtasks
      AFTER DELETE ON tasks
      BEGIN UPDATE tasks SET parentTaskId = NULL WHERE parentTaskId = OLD.id; END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_delete_debt_cleanup_transactions
      AFTER DELETE ON debts
      BEGIN UPDATE transactions SET debtId = NULL WHERE debtId = OLD.id; END
      """,
      """
      CREATE TRIGGER IF NOT EXISTS trg_delete_account_cleanup
      AFTER DELETE ON financial_accounts
      BEGIN
        UPDATE transactions SET accountId = NULL WHERE accountId = OLD.id;
        UPDATE financial_goals SET accountId = NULL WHERE accountId = OLD.id;
      END
      """,
    ];

    for (final statement in statements) {
      await db.execute(statement);
    }
  }

  Future<void> _ensureTaskColumns(Database db) async {
    await _addColumnIfMissing(db, 'tasks', 'parentTaskId INTEGER');
    await _addColumnIfMissing(db, 'tasks', 'recurrenceType TEXT NOT NULL DEFAULT "none"');
  }

  Future<void> _addColumnIfMissing(Database db, String table, String columnSql) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnSql');
    } catch (_) {}
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        color TEXT NOT NULL,
        icon TEXT,
        createdAt TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        categoryId INTEGER REFERENCES categories(id) ON DELETE SET NULL,
        projectId INTEGER REFERENCES projects(id) ON DELETE SET NULL,
        projectStepId INTEGER REFERENCES project_steps(id) ON DELETE SET NULL,
        parentTaskId INTEGER REFERENCES tasks(id) ON DELETE SET NULL,
        priority TEXT NOT NULL,
        date TEXT,
        time TEXT,
        status TEXT NOT NULL,
        reminderEnabled INTEGER NOT NULL,
        recurrenceType TEXT NOT NULL DEFAULT 'none',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await _createProjectsTable(db);
    await _createProjectStepsTable(db);

    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        description TEXT,
        amount REAL NOT NULL,
        type TEXT NOT NULL,
        transactionDate TEXT NOT NULL,
        dueDate TEXT,
        paidDate TEXT,
        categoryId INTEGER REFERENCES financial_categories(id) ON DELETE SET NULL,
        accountId INTEGER REFERENCES financial_accounts(id) ON DELETE SET NULL,
        paymentMethod TEXT,
        status TEXT NOT NULL,
        reminderEnabled INTEGER NOT NULL DEFAULT 0,
        isFixed INTEGER NOT NULL DEFAULT 0,
        recurrenceType TEXT NOT NULL DEFAULT 'none',
        notes TEXT,
        debtId INTEGER REFERENCES debts(id) ON DELETE SET NULL,
        installmentNumber INTEGER,
        totalInstallments INTEGER,
        discountAmount REAL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await _createFinancialCategoriesTable(db);
    await FinancePlanningStore.ensureTables(db);

    await db.execute('''
      CREATE TABLE debts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        totalAmount REAL NOT NULL,
        installmentCount INTEGER,
        installmentAmount REAL,
        startDate TEXT,
        firstDueDate TEXT,
        categoryId INTEGER REFERENCES financial_categories(id) ON DELETE SET NULL,
        creditorName TEXT,
        status TEXT NOT NULL,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    final now = DateTime.now().toIso8601String();
    await db.insert('categories', {'name': 'Pessoal', 'color': '0xFF2196F3', 'icon': 'person', 'createdAt': now});
    await db.insert('categories', {'name': 'Trabalho', 'color': '0xFFFF9800', 'icon': 'work', 'createdAt': now});
    await db.insert('categories', {'name': 'Estudo', 'color': '0xFF4CAF50', 'icon': 'school', 'createdAt': now});
    await _seedFinancialCategories(db);
    await _migrateReferentialIntegrity(db);
  }

  Future<void> _createProjectsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        startDate TEXT,
        endDate TEXT,
        status TEXT NOT NULL,
        notes TEXT,
        completedAt TEXT,
        progress REAL NOT NULL DEFAULT 0,
        reminderEnabled INTEGER NOT NULL DEFAULT 0,
        priority TEXT NOT NULL DEFAULT 'media',
        color TEXT NOT NULL DEFAULT '0xFF2196F3',
        icon TEXT NOT NULL DEFAULT 'rocket_launch',
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createProjectStepsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS project_steps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        projectId INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        title TEXT NOT NULL,
        description TEXT,
        orderIndex INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        dueDate TEXT,
        completedAt TEXT,
        reminderEnabled INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createFinancialCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS financial_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        color TEXT NOT NULL,
        icon TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> _seedFinancialCategories(Database db) async {
    final existing = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM financial_categories')) ?? 0;
    if (existing > 0) return;
    final now = DateTime.now().toIso8601String();
    final defaultCats = [
      {'name': 'Salário', 'type': 'income', 'color': '0xFF4CAF50', 'icon': 'attach_money'},
      {'name': 'Alimentação', 'type': 'expense', 'color': '0xFFFF9800', 'icon': 'restaurant'},
      {'name': 'Transporte', 'type': 'expense', 'color': '0xFF2196F3', 'icon': 'directions_car'},
      {'name': 'Moradia', 'type': 'expense', 'color': '0xFF9C27B0', 'icon': 'home'},
      {'name': 'Saúde', 'type': 'expense', 'color': '0xFFE91E63', 'icon': 'local_hospital'},
      {'name': 'Educação', 'type': 'expense', 'color': '0xFF3F51B5', 'icon': 'school'},
      {'name': 'Lazer', 'type': 'expense', 'color': '0xFFFFEB3B', 'icon': 'sports_esports'},
      {'name': 'Assinaturas', 'type': 'expense', 'color': '0xFF00BCD4', 'icon': 'subscriptions'},
      {'name': 'Dívidas', 'type': 'expense', 'color': '0xFFF44336', 'icon': 'money_off'},
      {'name': 'Investimentos', 'type': 'both', 'color': '0xFF8BC34A', 'icon': 'trending_up'},
      {'name': 'Trabalho', 'type': 'both', 'color': '0xFF607D8B', 'icon': 'work'},
      {'name': 'Outros', 'type': 'both', 'color': '0xFF9E9E9E', 'icon': 'category'},
    ];
    for (final cat in defaultCats) {
      await db.insert('financial_categories', {...cat, 'createdAt': now, 'updatedAt': now});
    }
  }

  Future<void> resetCoreData() async {
    final db = await instance.database;
    await db.transaction((txn) async {
      for (final table in ['tasks', 'transactions', 'debts', 'project_steps', 'project_stages', 'projects']) {
        try {
          await txn.delete(table);
        } catch (_) {}
      }
    });
  }

  double _balanceDeltaFor(FinancialTransaction transaction) {
    if (transaction.status != 'paid' || transaction.accountId == null) return 0;
    return transaction.type == 'income' ? transaction.amount : -transaction.amount;
  }

  Future<FinancialTransaction> _sanitizeAccountLink(Database db, FinancialTransaction transaction) async {
    if (transaction.accountId == null) return transaction;
    await FinancePlanningStore.ensureTables(db);
    final rows = await db.query('financial_accounts', columns: ['id', 'isArchived'], where: 'id = ?', whereArgs: [transaction.accountId], limit: 1);
    if (rows.isEmpty) return transaction.copyWith(clearAccountId: true);
    final archived = rows.first['isArchived'] == 1;
    if (archived && transaction.status != 'paid') return transaction.copyWith(clearAccountId: true);
    return transaction;
  }

  Future<void> _applyAccountDelta(Transaction txn, int accountId, double delta) async {
    if (delta == 0) return;
    await txn.rawUpdate('UPDATE financial_accounts SET currentBalance = currentBalance + ?, updatedAt = ? WHERE id = ?', [delta, DateTime.now().toIso8601String(), accountId]);
  }

  Future<void> _syncAccountBalanceOnCreate(Transaction txn, FinancialTransaction transaction) async {
    if (transaction.accountId == null) return;
    await _applyAccountDelta(txn, transaction.accountId!, _balanceDeltaFor(transaction));
  }

  Future<void> _syncAccountBalanceOnUpdate(Transaction txn, FinancialTransaction oldTransaction, FinancialTransaction newTransaction) async {
    if (oldTransaction.accountId != null) await _applyAccountDelta(txn, oldTransaction.accountId!, -_balanceDeltaFor(oldTransaction));
    if (newTransaction.accountId != null) await _applyAccountDelta(txn, newTransaction.accountId!, _balanceDeltaFor(newTransaction));
  }

  Future<List<TaskCategory>> getCategories() async {
    final db = await instance.database;
    final result = await db.query('categories');
    return result.map((json) => TaskCategory.fromMap(json)).toList();
  }

  Future<TaskCategory> createCategory(TaskCategory category) async {
    final db = await instance.database;
    final id = await db.insert('categories', category.toMap());
    return TaskCategory(id: id, name: category.name, color: category.color, icon: category.icon, createdAt: category.createdAt);
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Task>> getTasks() async {
    final db = await instance.database;
    await _ensureTaskColumns(db);
    final result = await db.query('tasks', orderBy: 'date ASC, time ASC');
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<Task> createTask(Task task) async {
    final db = await instance.database;
    await _ensureTaskColumns(db);
    final id = await db.insert('tasks', task.toMap());
    return task.copyWith(id: id);
  }

  Future<int> updateTask(Task task) async {
    final db = await instance.database;
    await _ensureTaskColumns(db);
    return db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    await _ensureTaskColumns(db);
    await db.update('tasks', {'parentTaskId': null}, where: 'parentTaskId = ?', whereArgs: [id]);
    return db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<AppSetting?> getSetting(String key) async {
    final db = await instance.database;
    final result = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    return result.isEmpty ? null : AppSetting.fromMap(result.first);
  }

  Future<void> saveSetting(AppSetting setting) async {
    final db = await instance.database;
    await db.insert('settings', setting.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<FinancialTransaction>> getTransactions() async {
    final db = await instance.database;
    await FinancePlanningStore.ensureTables(db);
    await _addColumnIfMissing(db, 'transactions', 'accountId INTEGER');
    final result = await db.query('transactions', orderBy: 'transactionDate DESC');
    return result.map((json) => FinancialTransaction.fromMap(json)).toList();
  }

  Future<FinancialTransaction> createTransaction(FinancialTransaction transaction) async {
    final db = await instance.database;
    await FinancePlanningStore.ensureTables(db);
    await _addColumnIfMissing(db, 'transactions', 'accountId INTEGER');
    final sanitized = await _sanitizeAccountLink(db, transaction);
    late int id;
    await db.transaction((txn) async {
      id = await txn.insert('transactions', sanitized.toMap());
      await _syncAccountBalanceOnCreate(txn, sanitized.copyWith(id: id));
    });
    return sanitized.copyWith(id: id);
  }

  Future<int> updateTransaction(FinancialTransaction transaction) async {
    final db = await instance.database;
    await FinancePlanningStore.ensureTables(db);
    await _addColumnIfMissing(db, 'transactions', 'accountId INTEGER');
    final oldRows = await db.query('transactions', where: 'id = ?', whereArgs: [transaction.id], limit: 1);
    if (oldRows.isEmpty) return 0;
    final oldTransaction = FinancialTransaction.fromMap(oldRows.first);
    final sanitized = await _sanitizeAccountLink(db, transaction);
    late int count;
    await db.transaction((txn) async {
      count = await txn.update('transactions', sanitized.toMap(), where: 'id = ?', whereArgs: [sanitized.id]);
      await _syncAccountBalanceOnUpdate(txn, oldTransaction, sanitized);
    });
    return count;
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    await FinancePlanningStore.ensureTables(db);
    await _addColumnIfMissing(db, 'transactions', 'accountId INTEGER');
    final oldRows = await db.query('transactions', where: 'id = ?', whereArgs: [id], limit: 1);
    FinancialTransaction? oldTransaction;
    if (oldRows.isNotEmpty) oldTransaction = FinancialTransaction.fromMap(oldRows.first);
    late int count;
    await db.transaction((txn) async {
      if (oldTransaction?.accountId != null) await _applyAccountDelta(txn, oldTransaction!.accountId!, -_balanceDeltaFor(oldTransaction));
      count = await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);
    });
    return count;
  }

  Future<List<FinancialCategory>> getFinancialCategories() async {
    final db = await instance.database;
    final result = await db.query('financial_categories', orderBy: 'name ASC');
    return result.map((json) => FinancialCategory.fromMap(json)).toList();
  }

  Future<FinancialCategory> createFinancialCategory(FinancialCategory category) async {
    final db = await instance.database;
    final id = await db.insert('financial_categories', category.toMap());
    return category.copyWith(id: id);
  }

  Future<int> updateFinancialCategory(FinancialCategory category) async {
    final db = await instance.database;
    return db.update('financial_categories', category.toMap(), where: 'id = ?', whereArgs: [category.id]);
  }

  Future<int> deleteFinancialCategory(int id) async {
    final db = await instance.database;
    await FinancePlanningStore.clearCategoryLinks(db, id);
    await db.update('transactions', {'categoryId': null}, where: 'categoryId = ?', whereArgs: [id]);
    await db.update('debts', {'categoryId': null}, where: 'categoryId = ?', whereArgs: [id]);
    return db.delete('financial_categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getDebts() async {
    final db = await instance.database;
    return db.query('debts', orderBy: 'createdAt DESC');
  }

  Future<int> createDebt(Map<String, dynamic> debt) async {
    final db = await instance.database;
    return db.insert('debts', debt);
  }

  Future<int> updateDebt(Map<String, dynamic> debt) async {
    final db = await instance.database;
    return db.update('debts', debt, where: 'id = ?', whereArgs: [debt['id']]);
  }

  Future<int> deleteDebt(int id) async {
    final db = await instance.database;
    await db.update('transactions', {'debtId': null}, where: 'debtId = ?', whereArgs: [id]);
    return db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Map<String, dynamic>>> getProjects() async {
    final db = await instance.database;
    return db.query('projects', orderBy: 'createdAt DESC');
  }

  Future<int> createProject(Map<String, dynamic> project) async {
    final db = await instance.database;
    return db.insert('projects', project);
  }

  Future<int> updateProject(Map<String, dynamic> project) async {
    final db = await instance.database;
    return db.update('projects', project, where: 'id = ?', whereArgs: [project['id']]);
  }

  Future<int> deleteProject(int id, {bool deleteLinkedTasks = false}) async {
    final db = await instance.database;
    await _ensureTaskColumns(db);
    if (deleteLinkedTasks) {
      await db.delete('tasks', where: 'projectId = ?', whereArgs: [id]);
    } else {
      await db.update('tasks', {'projectId': null, 'projectStepId': null}, where: 'projectId = ?', whereArgs: [id]);
    }
    await db.delete('project_steps', where: 'projectId = ?', whereArgs: [id]);
    try { await db.delete('project_stages', where: 'projectId = ?', whereArgs: [id]); } catch (_) {}
    return db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ProjectStep>> getProjectSteps(int projectId) async {
    final db = await instance.database;
    final result = await db.query('project_steps', where: 'projectId = ?', whereArgs: [projectId], orderBy: 'orderIndex ASC, id ASC');
    return result.map((json) => ProjectStep.fromMap(json)).toList();
  }

  Future<List<ProjectStep>> getAllProjectSteps() async {
    final db = await instance.database;
    final result = await db.query('project_steps', orderBy: 'projectId ASC, orderIndex ASC, id ASC');
    return result.map((json) => ProjectStep.fromMap(json)).toList();
  }

  Future<ProjectStep> createProjectStep(ProjectStep step) async {
    final db = await instance.database;
    final id = await db.insert('project_steps', step.toMap());
    return ProjectStep(id: id, projectId: step.projectId, title: step.title, description: step.description, orderIndex: step.orderIndex, status: step.status, dueDate: step.dueDate, completedAt: step.completedAt, reminderEnabled: step.reminderEnabled, createdAt: step.createdAt, updatedAt: step.updatedAt);
  }

  Future<int> updateProjectStep(ProjectStep step) async {
    final db = await instance.database;
    return db.update('project_steps', step.toMap(), where: 'id = ?', whereArgs: [step.id]);
  }

  Future<int> deleteProjectStep(int id) async {
    final db = await instance.database;
    await _ensureTaskColumns(db);
    await db.update('tasks', {'projectStepId': null}, where: 'projectStepId = ?', whereArgs: [id]);
    return db.delete('project_steps', where: 'id = ?', whereArgs: [id]);
  }
}
