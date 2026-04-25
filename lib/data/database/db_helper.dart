import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task_model.dart';
import '../models/category_model.dart';
import '../models/setting_model.dart';
import '../models/transaction_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('diasorganize_v5.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path, 
      version: 5, 
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 5) {
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
        priority TEXT NOT NULL,
        date TEXT,
        time TEXT,
        status TEXT NOT NULL,
        reminderEnabled INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories (id)
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
        isFixed INTEGER NOT NULL DEFAULT 0,
        recurrenceType TEXT NOT NULL,
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
    if (existing != null) {
      await db.update('settings', setting.toMap(), where: 'key = ?', whereArgs: [setting.key]);
    } else {
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
}

