import 'package:diasorganize/data/database/credit_card_store.dart';
import 'package:diasorganize/data/models/credit_card_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openMovePurchaseTestDatabase() async {
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
      transactionDate TEXT,
      dueDate TEXT,
      paidDate TEXT,
      categoryId INTEGER,
      subcategoryId INTEGER,
      accountId INTEGER,
      paymentMethod TEXT,
      status TEXT NOT NULL,
      ignoreInReports INTEGER NOT NULL DEFAULT 0,
      ignoreInMonthlySavings INTEGER NOT NULL DEFAULT 0,
      notes TEXT,
      tags TEXT,
      createdAt TEXT,
      updatedAt TEXT
    )
  ''');

  await CreditCardStore.ensureTables(db);
  return db;
}

CreditCard testCard({int? id}) {
  final now = DateTime(2026, 4, 1).toIso8601String();
  return CreditCard(
    id: id,
    name: 'Cartão Teste',
    creditLimit: 3000,
    closingDay: 10,
    dueDay: 20,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('CreditCardStore move purchase', () {
    test('move compra para outra fatura e recalcula antiga e nova', () async {
      final db = await openMovePurchaseTestDatabase();
      final cardId = await CreditCardStore.upsertCard(db, testCard());
      final transactionId = await CreditCardStore.createCardPurchase(
        db,
        cardId: cardId,
        title: 'Compra movível',
        amount: 100,
        purchaseDate: DateTime(2026, 4, 15),
      );
      final oldInvoice = (await CreditCardStore.getInvoices(db, cardId: cardId)).single;

      final newInvoiceId = await CreditCardStore.movePurchaseToInvoiceMonth(
        db,
        transactionId: transactionId,
        targetMonth: DateTime(2026, 5, 1),
      );

      final invoices = await CreditCardStore.getInvoices(db, cardId: cardId);
      final oldAfter = invoices.firstWhere((invoice) => invoice.id == oldInvoice.id);
      final newAfter = invoices.firstWhere((invoice) => invoice.id == newInvoiceId);
      final transaction = (await db.query('transactions', where: 'id = ?', whereArgs: [transactionId])).first;

      expect(oldAfter.amount, 0);
      expect(newAfter.referenceMonth, '2026-05');
      expect(newAfter.amount, 100);
      expect(transaction['creditCardInvoiceId'], newInvoiceId);
      expect(DateTime.parse(transaction['dueDate'] as String).month, DateTime.parse(newAfter.dueDate).month);
      await db.close();
    });

    test('bloqueia movimentação que não é compra de cartão', () async {
      final db = await openMovePurchaseTestDatabase();
      final now = DateTime(2026, 4, 1).toIso8601String();
      final transactionId = await db.insert('transactions', {
        'title': 'Despesa comum',
        'amount': 10,
        'type': 'expense',
        'transactionDate': now,
        'status': 'pending',
        'createdAt': now,
        'updatedAt': now,
      });

      expect(
        () => CreditCardStore.movePurchaseToInvoiceMonth(
          db,
          transactionId: transactionId,
          targetMonth: DateTime(2026, 5, 1),
        ),
        throwsArgumentError,
      );
      await db.close();
    });
  });
}
