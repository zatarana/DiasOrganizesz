import 'dart:io';

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/category_model.dart';
import '../models/financial_category_model.dart';
import '../models/project_step_model.dart';
import '../models/setting_model.dart';
import '../models/task_model.dart';
import '../models/transaction_model.dart';

class DatabaseHelper {
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

    return openDatabase(path, version: 14, onCreate: _createDB, onUpgrade: _onUpgrade);
  }

  Future<void> _copyLegacyDatabaseIfNeeded(String dbPath, String targetPath) async {
    final target = File(targetPath);
    if (await target.exists()) return;

    const legacyNames = [
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
    if (await source.exists()) {
      await source.copy(targetPath);
    }
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
        categoryId INTEGER,
        projectId INTEGER,
        projectStepId INTEGER,
        priority TEXT NOT NULL,
        date TEXT,
        time TEXT,
        status TEXT NOT NULL,
        reminderEnabled INTEGER NOT NULL,
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
        categoryId INTEGER,
        paymentMethod TEXT,
        status TEXT NOT NULL,
        reminderEnabled INTEGER NOT NULL DEFAULT 0,
        isFixed INTEGER NOT NULL DEFAULT 0,
        recurrenceType TEXT NOT NULL DEFAULT 'none',
        notes TEXT,
        debtId INTEGER,
        installmentNumber INTEGER,
        totalInstallments INTEGER,
        discountAmount REAL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

    await _createFinancialCategoriesTable(db);

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
        categoryId INTEGER,
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
        projectId INTEGER NOT NULL,
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
    final result = await db.query('tasks', orderBy: 'date ASC, time ASC');
    return result.map((json) => Task.fromMap(json)).toList();
  }

  Future<Task> createTask(Task task) async {
    final db = await instance.database;
    final id = await db.insert('tasks', task.toMap());
    return task.copyWith(id: id);
  }

  Future<int> updateTask(Task task) async {
    final db = await instance.database;
    return db.update('tasks', task.toMap(), where: 'id = ?', whereArgs: [task.id]);
  }

  Future<int> deleteTask(int id) async {
    final db = await instance.database;
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
    final result = await db.query('transactions', orderBy: 'transactionDate DESC');
    return result.map((json) => FinancialTransaction.fromMap(json)).toList();
  }

  Future<FinancialTransaction> createTransaction(FinancialTransaction transaction) async {
    final db = await instance.database;
    final id = await db.insert('transactions', transaction.toMap());
    return transaction.copyWith(id: id);
  }

  Future<int> updateTransaction(FinancialTransaction transaction) async {
    final db = await instance.database;
    return db.update('transactions', transaction.toMap(), where: 'id = ?', whereArgs: [transaction.id]);
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return db.delete('transactions', where: 'id = ?', whereArgs: [id]);
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
    if (deleteLinkedTasks) {
      await db.delete('tasks', where: 'projectId = ?', whereArgs: [id]);
    } else {
      await db.update('tasks', {'projectId': null, 'projectStepId': null}, where: 'projectId = ?', whereArgs: [id]);
    }
    await db.delete('project_steps', where: 'projectId = ?', whereArgs: [id]);
    try {
      await db.delete('project_stages', where: 'projectId = ?', whereArgs: [id]);
    } catch (_) {}
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
    return ProjectStep(
      id: id,
      projectId: step.projectId,
      title: step.title,
      description: step.description,
      orderIndex: step.orderIndex,
      status: step.status,
      dueDate: step.dueDate,
      completedAt: step.completedAt,
      reminderEnabled: step.reminderEnabled,
      createdAt: step.createdAt,
      updatedAt: step.updatedAt,
    );
  }

  Future<int> updateProjectStep(ProjectStep step) async {
    final db = await instance.database;
    return db.update('project_steps', step.toMap(), where: 'id = ?', whereArgs: [step.id]);
  }

  Future<int> deleteProjectStep(int id) async {
    final db = await instance.database;
    return db.delete('project_steps', where: 'id = ?', whereArgs: [id]);
  }
}
