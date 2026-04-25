import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task_model.dart';
import '../models/category_model.dart';
import '../models/setting_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('diasorganize_v2.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
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
}

