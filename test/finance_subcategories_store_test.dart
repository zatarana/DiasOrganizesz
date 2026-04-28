import 'package:diasorganize/data/database/finance_planning_store.dart';
import 'package:diasorganize/data/models/budget_model.dart';
import 'package:diasorganize/data/models/financial_subcategory_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openFinanceSubcategoryTestDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await databaseFactory.openDatabase(inMemoryDatabasePath);

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
      subcategoryId INTEGER,
      accountId INTEGER,
      paymentMethod TEXT,
      status TEXT NOT NULL,
      reminderEnabled INTEGER NOT NULL DEFAULT 0,
      isFixed INTEGER NOT NULL DEFAULT 0,
      recurrenceType TEXT NOT NULL DEFAULT 'none',
      notes TEXT,
      tags TEXT,
      ignoreInTotals INTEGER NOT NULL DEFAULT 0,
      ignoreInReports INTEGER NOT NULL DEFAULT 0,
      ignoreInMonthlySavings INTEGER NOT NULL DEFAULT 0,
      debtId INTEGER,
      installmentNumber INTEGER,
      totalInstallments INTEGER,
      discountAmount REAL DEFAULT 0,
      createdAt TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE tasks (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      status TEXT NOT NULL,
      parentTaskId INTEGER,
      date TEXT,
      projectId INTEGER,
      projectStepId INTEGER
    )
  ''');
  await db.execute('''
    CREATE TABLE projects (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      status TEXT NOT NULL,
      endDate TEXT
    )
  ''');
  await db.execute('''
    CREATE TABLE project_steps (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      projectId INTEGER NOT NULL,
      orderIndex INTEGER NOT NULL DEFAULT 0
    )
  ''');

  return db;
}

Future<int> insertCategory(Database db, String name) async {
  final now = DateTime(2026, 4, 1).toIso8601String();
  return db.insert('financial_categories', {
    'name': name,
    'type': 'expense',
    'color': '0xFF2196F3',
    'icon': 'category',
    'createdAt': now,
    'updatedAt': now,
  });
}

void main() {
  group('FinancePlanningStore subcategories', () {
    test('ensureTables cria subcategoria padrão Outros para cada categoria', () async {
      final db = await openFinanceSubcategoryTestDatabase();
      final categoryId = await insertCategory(db, 'Alimentação');

      await FinancePlanningStore.ensureTables(db);

      final subcategories = await FinancePlanningStore.getSubcategories(db, categoryId: categoryId);
      expect(subcategories.length, 1);
      expect(subcategories.first.name, 'Outros');
      expect(subcategories.first.isDefault, true);
      expect(subcategories.first.isArchived, false);
      await db.close();
    });

    test('upsertSubcategory cria e edita subcategoria', () async {
      final db = await openFinanceSubcategoryTestDatabase();
      final categoryId = await insertCategory(db, 'Casa');
      await FinancePlanningStore.ensureTables(db);
      final now = DateTime(2026, 4, 1).toIso8601String();

      final id = await FinancePlanningStore.upsertSubcategory(
        db,
        FinancialSubcategory(categoryId: categoryId, name: 'Mercado', createdAt: now, updatedAt: now),
      );
      await FinancePlanningStore.upsertSubcategory(
        db,
        FinancialSubcategory(id: id, categoryId: categoryId, name: 'Supermercado', createdAt: now, updatedAt: now),
      );

      final subcategories = await FinancePlanningStore.getSubcategories(db, categoryId: categoryId);
      expect(subcategories.any((item) => item.name == 'Supermercado'), true);
      expect(subcategories.any((item) => item.name == 'Mercado'), false);
      await db.close();
    });

    test('archiveSubcategory arquiva e limpa vínculos de transações e orçamentos', () async {
      final db = await openFinanceSubcategoryTestDatabase();
      final categoryId = await insertCategory(db, 'Transporte');
      await FinancePlanningStore.ensureTables(db);
      final now = DateTime(2026, 4, 1).toIso8601String();

      final subcategoryId = await FinancePlanningStore.upsertSubcategory(
        db,
        FinancialSubcategory(categoryId: categoryId, name: 'Uber', createdAt: now, updatedAt: now),
      );
      await db.insert('transactions', {
        'title': 'Corrida',
        'amount': 30,
        'type': 'expense',
        'transactionDate': now,
        'categoryId': categoryId,
        'subcategoryId': subcategoryId,
        'status': 'paid',
        'createdAt': now,
        'updatedAt': now,
      });
      await FinancePlanningStore.upsertBudget(
        db,
        Budget(
          name: 'Uber mês',
          categoryId: categoryId,
          subcategoryId: subcategoryId,
          limitAmount: 300,
          month: '2026-04',
          createdAt: now,
          updatedAt: now,
        ),
      );

      await FinancePlanningStore.archiveSubcategory(db, subcategoryId);

      final archived = await FinancePlanningStore.getSubcategories(db, categoryId: categoryId, includeArchived: true);
      final archivedSubcategory = archived.firstWhere((item) => item.id == subcategoryId);
      final transaction = (await db.query('transactions')).first;
      final budget = (await db.query('budgets')).first;

      expect(archivedSubcategory.isArchived, true);
      expect(transaction['subcategoryId'], null);
      expect(budget['subcategoryId'], null);
      await db.close();
    });
  });
}
