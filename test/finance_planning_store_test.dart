import 'package:diasorganize/data/database/finance_planning_store.dart';
import 'package:diasorganize/data/models/financial_account_model.dart';
import 'package:diasorganize/data/models/financial_transfer_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openTestDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
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
  await FinancePlanningStore.ensureTables(db);
  return db;
}

Future<int> insertAccount(Database db, String name, double initialBalance, {bool ignoreInTotals = false}) {
  final now = DateTime(2026, 4, 1).toIso8601String();
  return FinancePlanningStore.upsertAccount(
    db,
    FinancialAccount(
      name: name,
      initialBalance: initialBalance,
      currentBalance: initialBalance,
      ignoreInTotals: ignoreInTotals,
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Future<void> insertPaidTransaction(Database db, {required int accountId, required double amount, required String type}) async {
  final now = DateTime(2026, 4, 10).toIso8601String();
  await db.insert('transactions', {
    'title': type == 'income' ? 'Receita' : 'Despesa',
    'amount': amount,
    'type': type,
    'transactionDate': now,
    'paidDate': now,
    'accountId': accountId,
    'status': 'paid',
    'createdAt': now,
    'updatedAt': now,
  });
  await FinancePlanningStore.recalculateAccountBalance(db, accountId);
}

void main() {
  group('FinancePlanningStore balances', () {
    test('calcula saldo com saldo inicial, receitas e despesas pagas', () async {
      final db = await openTestDatabase();
      final accountId = await insertAccount(db, 'Banco', 1000);

      await insertPaidTransaction(db, accountId: accountId, amount: 500, type: 'income');
      await insertPaidTransaction(db, accountId: accountId, amount: 200, type: 'expense');

      final accounts = await FinancePlanningStore.getAccounts(db, recalculateBeforeRead: true);
      final account = accounts.firstWhere((item) => item.id == accountId);

      expect(account.currentBalance, 1300);
      await db.close();
    });

    test('transferência reduz origem e aumenta destino sem alterar saldo total', () async {
      final db = await openTestDatabase();
      final originId = await insertAccount(db, 'Banco', 1000);
      final destinationId = await insertAccount(db, 'Carteira', 100);
      final now = DateTime(2026, 4, 10).toIso8601String();

      await FinancePlanningStore.upsertTransfer(
        db,
        FinancialTransfer(
          fromAccountId: originId,
          toAccountId: destinationId,
          amount: 250,
          transferDate: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final accounts = await FinancePlanningStore.getAccounts(db, recalculateBeforeRead: true);
      final origin = accounts.firstWhere((item) => item.id == originId);
      final destination = accounts.firstWhere((item) => item.id == destinationId);
      final total = await FinancePlanningStore.getActiveAccountsBalance(db);

      expect(origin.currentBalance, 750);
      expect(destination.currentBalance, 350);
      expect(total, 1100);
      await db.close();
    });

    test('edição de transferência recalcula contas antigas e novas', () async {
      final db = await openTestDatabase();
      final a = await insertAccount(db, 'A', 1000);
      final b = await insertAccount(db, 'B', 100);
      final c = await insertAccount(db, 'C', 50);
      final now = DateTime(2026, 4, 10).toIso8601String();

      final transferId = await FinancePlanningStore.upsertTransfer(
        db,
        FinancialTransfer(fromAccountId: a, toAccountId: b, amount: 200, transferDate: now, createdAt: now, updatedAt: now),
      );
      await FinancePlanningStore.upsertTransfer(
        db,
        FinancialTransfer(id: transferId, fromAccountId: a, toAccountId: c, amount: 300, transferDate: now, createdAt: now, updatedAt: now),
      );

      final accounts = await FinancePlanningStore.getAccounts(db, recalculateBeforeRead: true);
      expect(accounts.firstWhere((item) => item.id == a).currentBalance, 700);
      expect(accounts.firstWhere((item) => item.id == b).currentBalance, 100);
      expect(accounts.firstWhere((item) => item.id == c).currentBalance, 350);
      await db.close();
    });

    test('reajuste registra delta e passa a compor saldo da conta', () async {
      final db = await openTestDatabase();
      final accountId = await insertAccount(db, 'Banco', 1000);
      await insertPaidTransaction(db, accountId: accountId, amount: 100, type: 'expense');

      await FinancePlanningStore.createBalanceAdjustment(db, accountId: accountId, newBalance: 950, reason: 'Correção banco');

      final accounts = await FinancePlanningStore.getAccounts(db, recalculateBeforeRead: true);
      final account = accounts.firstWhere((item) => item.id == accountId);
      final adjustments = await FinancePlanningStore.getBalanceAdjustments(db, accountId: accountId);

      expect(account.currentBalance, 950);
      expect(adjustments.length, 1);
      expect(adjustments.first.previousBalance, 900);
      expect(adjustments.first.newBalance, 950);
      expect(adjustments.first.delta, 50);
      await db.close();
    });

    test('conta ignorada não entra no saldo total, mas mantém saldo próprio', () async {
      final db = await openTestDatabase();
      final regularId = await insertAccount(db, 'Banco', 1000);
      final ignoredId = await insertAccount(db, 'Investimento', 5000, ignoreInTotals: true);

      await insertPaidTransaction(db, accountId: regularId, amount: 100, type: 'income');
      await insertPaidTransaction(db, accountId: ignoredId, amount: 1000, type: 'income');

      final accounts = await FinancePlanningStore.getAccounts(db, recalculateBeforeRead: true);
      final ignored = accounts.firstWhere((item) => item.id == ignoredId);
      final total = await FinancePlanningStore.getActiveAccountsBalance(db);

      expect(ignored.currentBalance, 6000);
      expect(total, 1100);
      await db.close();
    });
  });
}
