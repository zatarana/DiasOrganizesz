import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task_model.dart';
import '../models/category_model.dart';
import '../models/setting_model.dart';
import '../models/transaction_model.dart';
import '../models/project_step_model.dart';
    _database = await _initDB('diasorganize_v14.db');

      version: 14,
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('diasorganize_v14.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: 14,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transactions (
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
          isFixed INTEGER NOT NULL DEFAULT 0,
          recurrenceType TEXT NOT NULL DEFAULT 'none',
          notes TEXT,
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');
      // If we're upgrading from v3, we add columns to the existing table
      if (oldVersion == 3) {
        await db.execute('ALTER TABLE transactions ADD COLUMN description TEXT');
        await db.execute('ALTER TABLE transactions RENAME COLUMN date TO transactionDate');
        await db.execute('ALTER TABLE transactions ADD COLUMN paidDate TEXT');
        await db.execute('ALTER TABLE transactions ADD COLUMN status TEXT');
        await db.execute('ALTER TABLE transactions ADD COLUMN recurrenceType TEXT DEFAULT "none"');
        await db.execute('ALTER TABLE transactions ADD COLUMN notes TEXT');
        await db.execute('ALTER TABLE transactions ADD COLUMN updatedAt TEXT');
      }
      if (oldVersion < 5) {
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
        // Inserir categorias financeiras padrão
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
        for (var cat in defaultCats) {
          cat['createdAt'] = now;
          cat['updatedAt'] = now;
          await db.insert('financial_categories', cat);
        }
      }
      if (oldVersion < 6) {
         await db.execute('''
          CREATE TABLE IF NOT EXISTS debts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT,
            totalAmount REAL NOT NULL,
            creditor TEXT,
            status TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');
        await db.execute('ALTER TABLE transactions ADD COLUMN debtId INTEGER');
        await db.execute('ALTER TABLE transactions ADD COLUMN installmentNumber INTEGER');
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE projects ADD COLUMN priority TEXT NOT NULL DEFAULT "media"');
      await db.execute('ALTER TABLE projects ADD COLUMN color TEXT NOT NULL DEFAULT "0xFF2196F3"');
      await db.execute('ALTER TABLE projects ADD COLUMN icon TEXT NOT NULL DEFAULT "rocket_launch"');
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
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');
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
            'createdAt': row['createdAt'],
            'updatedAt': row['createdAt'],
          });
        }
      } catch (_) {}
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE tasks ADD COLUMN projectStepId INTEGER');
    }
    if (oldVersion < 12) {
      await db.execute('ALTER TABLE projects ADD COLUMN notes TEXT');
      await db.execute('ALTER TABLE projects ADD COLUMN completedAt TEXT');
    }
    if (oldVersion < 13) {
      await db.execute('ALTER TABLE projects ADD COLUMN progress REAL NOT NULL DEFAULT 0');
    }
    if (oldVersion < 14) {
      await db.execute('ALTER TABLE transactions ADD COLUMN reminderEnabled INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE projects ADD COLUMN reminderEnabled INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE project_steps ADD COLUMN reminderEnabled INTEGER NOT NULL DEFAULT 0');
    }
        projectStepId INTEGER,
        FOREIGN KEY (projectId) REFERENCES projects (id),
        FOREIGN KEY (projectStepId) REFERENCES project_steps (id)
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
    await db.execute('''
      CREATE TABLE project_steps (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        projectId INTEGER NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        orderIndex INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        dueDate TEXT,
        completedAt TEXT,
        reminderEnabled INTEGER NOT NULL DEFAULT 0,
        reminderEnabled INTEGER NOT NULL DEFAULT 0,
      }
      if (oldVersion < 7) {
        // v7 migrations
        await db.execute('ALTER TABLE debts ADD COLUMN categoryId INTEGER');
        await db.execute('ALTER TABLE debts ADD COLUMN installmentsCount INTEGER');
        await db.execute('ALTER TABLE debts ADD COLUMN installmentValue REAL');
        await db.execute('ALTER TABLE debts ADD COLUMN firstDueDate TEXT');
        await db.execute('ALTER TABLE transactions ADD COLUMN discountAmount REAL DEFAULT 0');
      }
      if (oldVersion < 8) {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS projects (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            startDate TEXT,
            endDate TEXT,
            status TEXT NOT NULL,
            createdAt TEXT NOT NULL,
            updatedAt TEXT NOT NULL
          )
        ''');
        await db.execute('ALTER TABLE tasks ADD COLUMN projectId INTEGER');
      }
    }
    if (oldVersion < 9) {
      await db.execute('ALTER TABLE projects ADD COLUMN priority TEXT NOT NULL DEFAULT "media"');
      await db.execute('ALTER TABLE projects ADD COLUMN color TEXT NOT NULL DEFAULT "0xFF2196F3"');
      await db.execute('ALTER TABLE projects ADD COLUMN icon TEXT NOT NULL DEFAULT "rocket_launch"');
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
          createdAt TEXT NOT NULL,
          updatedAt TEXT NOT NULL
        )
      ''');
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
            'createdAt': row['createdAt'],
            'updatedAt': row['createdAt'],
          });
        }
      } catch (_) {}
    }
    if (oldVersion < 11) {
      await db.execute('ALTER TABLE tasks ADD COLUMN projectStepId INTEGER');
    }
    if (oldVersion < 12) {
      await db.execute('ALTER TABLE projects ADD COLUMN notes TEXT');
      await db.execute('ALTER TABLE projects ADD COLUMN completedAt TEXT');
    }
    if (oldVersion < 13) {
      await db.execute('ALTER TABLE projects ADD COLUMN progress REAL NOT NULL DEFAULT 0');
    }
    if (oldVersion < 14) {
      await db.execute('ALTER TABLE transactions ADD COLUMN reminderEnabled INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE projects ADD COLUMN reminderEnabled INTEGER NOT NULL DEFAULT 0');
      await db.execute('ALTER TABLE project_steps ADD COLUMN reminderEnabled INTEGER NOT NULL DEFAULT 0');
    }
  }

  Future _createDB(Database db, int version) async {
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
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories (id),
        FOREIGN KEY (projectId) REFERENCES projects (id),
        FOREIGN KEY (projectStepId) REFERENCES project_steps (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE projects (
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
    await db.execute('''
      CREATE TABLE project_steps (
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

    await db.execute('''
      CREATE TABLE settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL,
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
        recurrenceType TEXT NOT NULL,
        notes TEXT,
        debtId INTEGER,
        installmentNumber INTEGER,
        totalInstallments INTEGER,
        discountAmount REAL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    
    await db.execute('''
      CREATE TABLE financial_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        type TEXT NOT NULL,
        color TEXT NOT NULL,
        icon TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');

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
    
    // Inserir categorias padrão
    final now = DateTime.now().toIso8601String();
    await db.insert('categories', {'name': 'Pessoal', 'color': '0xFF2196F3', 'icon': 'person', 'createdAt': now});
    await db.insert('categories', {'name': 'Trabalho', 'color': '0xFFFF9800', 'icon': 'work', 'createdAt': now});
    await db.insert('categories', {'name': 'Estudo', 'color': '0xFF4CAF50', 'icon': 'school', 'createdAt': now});
  }

  Future<List<TaskCategory>> getCategories() async {
    final db = await instance.database;
    final result = await db.query('categories');
    return result.map((json) => TaskCategory.fromMap(json)).toList();
  }

  Future<TaskCategory> createCategory(TaskCategory category) async {
    final db = await instance.database;
    final id = await db.insert('categories', category.toMap());
    return TaskCategory(id: id, name: category.name, color: category.color, icon: category.icon);
  }

  Future<int> deleteCategory(int id) async {
    final db = await instance.database;
    return await db.delete('categories', where: 'id = ?', whereArgs: [id]);
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
    return db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    return await db.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  // Settings
  Future<AppSetting?> getSetting(String key) async {
    final db = await instance.database;
    final result = await db.query('settings', where: 'key = ?', whereArgs: [key]);
    if (result.isNotEmpty) {
      return AppSetting.fromMap(result.first);
    }
    return null;
  }

  Future<void> saveSetting(AppSetting setting) async {
    final db = await instance.database;
    final existing = await getSetting(setting.key);
  Future<int> deleteProject(int id, {bool deleteLinkedTasks = false}) async {
    if (deleteLinkedTasks) {
      await db.delete('tasks', where: 'projectId = ?', whereArgs: [id]);
    } else {
      await db.update('tasks', {'projectId': null, 'projectStepId': null}, where: 'projectId = ?', whereArgs: [id]);
    }
    await db.delete('project_steps', where: 'projectId = ?', whereArgs: [id]);
    await db.delete('project_stages', where: 'projectId = ?', whereArgs: [id]);
  Future<List<ProjectStep>> getProjectSteps(int projectId) async {
    final db = await instance.database;
    final result = await db.query('project_steps', where: 'projectId = ?', whereArgs: [projectId], orderBy: 'orderIndex ASC, id ASC');
    return result.map((e) => ProjectStep.fromMap(e)).toList();
  }

  Future<List<ProjectStep>> getAllProjectSteps() async {
    final db = await instance.database;
    final result = await db.query('project_steps', orderBy: 'projectId ASC, orderIndex ASC, id ASC');
    return result.map((e) => ProjectStep.fromMap(e)).toList();
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
      await db.insert('settings', setting.toMap());
    }
  }

  // Transactions
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
    return db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await instance.database;
    return await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // Financial Categories
  Future<List<Map<String, dynamic>>> getFinancialCategories() async {
    final db = await instance.database;
    return await db.query('financial_categories', orderBy: 'name ASC');
  }

  Future<int> createFinancialCategory(Map<String, dynamic> category) async {
    final db = await instance.database;
    return await db.insert('financial_categories', category);
  }

  Future<int> updateFinancialCategory(Map<String, dynamic> category) async {
    final db = await instance.database;
    return await db.update(
      'financial_categories',
      category,
      where: 'id = ?',
      whereArgs: [category['id']],
    );
  }

  Future<int> deleteFinancialCategory(int id) async {
    final db = await instance.database;
    // Padrão: setar null nas transações que usam esta categoria
    await db.update('transactions', {'categoryId': null}, where: 'categoryId = ?', whereArgs: [id]);
    return await db.delete('financial_categories', where: 'id = ?', whereArgs: [id]);
  }

  // Debts
  Future<List<Map<String, dynamic>>> getDebts() async {
    final db = await instance.database;
    return await db.query('debts', orderBy: 'createdAt DESC');
  }

  Future<int> createDebt(Map<String, dynamic> debt) async {
    final db = await instance.database;
    return await db.insert('debts', debt);
  }

  Future<int> updateDebt(Map<String, dynamic> debt) async {
    final db = await instance.database;
    return await db.update(
      'debts',
      debt,
      where: 'id = ?',
      whereArgs: [debt['id']],
    );
  }

  Future<int> deleteDebt(int id) async {
    final db = await instance.database;
    // When deleting debt, we could delete associated transactions, or just un-link them. Leaving un-link for simplicity and preserving historical records.
    await db.update('transactions', {'debtId': null}, where: 'debtId = ?', whereArgs: [id]);
    return await db.delete('debts', where: 'id = ?', whereArgs: [id]);
  }

  // Projects
  Future<List<Map<String, dynamic>>> getProjects() async {
    final db = await instance.database;
    return await db.query('projects', orderBy: 'createdAt DESC');
  }

  Future<int> createProject(Map<String, dynamic> project) async {
    final db = await instance.database;
    return await db.insert('projects', project);
  }

  Future<int> updateProject(Map<String, dynamic> project) async {
    final db = await instance.database;
    return await db.update(
      'projects',
      project,
      where: 'id = ?',
      whereArgs: [project['id']],
    );
  }

  Future<int> deleteProject(int id, {bool deleteLinkedTasks = false}) async {
    final db = await instance.database;
    if (deleteLinkedTasks) {
      await db.delete('tasks', where: 'projectId = ?', whereArgs: [id]);
    } else {
      await db.update('tasks', {'projectId': null, 'projectStepId': null}, where: 'projectId = ?', whereArgs: [id]);
    }
    await db.delete('project_steps', where: 'projectId = ?', whereArgs: [id]);
    await db.delete('project_stages', where: 'projectId = ?', whereArgs: [id]);
    return await db.delete('projects', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<ProjectStep>> getProjectSteps(int projectId) async {
    final db = await instance.database;
    final result = await db.query('project_steps', where: 'projectId = ?', whereArgs: [projectId], orderBy: 'orderIndex ASC, id ASC');
    return result.map((e) => ProjectStep.fromMap(e)).toList();
  }

  Future<List<ProjectStep>> getAllProjectSteps() async {
    final db = await instance.database;
    final result = await db.query('project_steps', orderBy: 'projectId ASC, orderIndex ASC, id ASC');
    return result.map((e) => ProjectStep.fromMap(e)).toList();
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
