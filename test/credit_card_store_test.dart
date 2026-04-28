import 'package:diasorganize/data/database/credit_card_store.dart';
import 'package:diasorganize/data/models/credit_card_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openCreditCardTestDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await databaseFactory.openDatabase(inMemoryDatabasePath);

  await db.execute('''
    CREATE TABLE IF NOT EXISTS transactions (
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

CreditCard card({int? id, int closingDay = 10, int dueDay = 20, bool isArchived = false}) {
  final now = DateTime(2026, 4, 1).toIso8601String();
  return CreditCard(
    id: id,
    name: 'Nubank',
    issuer: 'Nubank',
    creditLimit: 5000,
    closingDay: closingDay,
    dueDay: dueDay,
    isArchived: isArchived,
    createdAt: now,
    updatedAt: now,
  );
}

Future<(Database, int, int)> seedCardInvoiceWithAmount({double amount = 150}) async {
  final db = await openCreditCardTestDatabase();
  final cardId = await CreditCardStore.upsertCard(db, card());
  final savedCard = (await CreditCardStore.getCards(db)).firstWhere((item) => item.id == cardId);
  final invoice = await CreditCardStore.getOrCreateInvoice(db, card: savedCard, month: DateTime(2026, 4, 1));
  final now = DateTime(2026, 4, 10).toIso8601String();
  await db.insert('transactions', {
    'title': 'Compra da fatura',
    'amount': amount,
    'type': 'expense',
    'status': 'pending',
    'creditCardId': cardId,
    'creditCardInvoiceId': invoice.id,
    'createdAt': now,
    'updatedAt': now,
  });
  await CreditCardStore.recalculateInvoiceAmount(db, invoice.id!);
  return (db, cardId, invoice.id!);
}

void main() {
  group('CreditCardStore date rules', () {
    test('referenceMonth retorna AAAA-MM', () {
      expect(CreditCardStore.referenceMonth(DateTime(2026, 4, 15)), '2026-04');
      expect(CreditCardStore.referenceMonth(DateTime(2026, 12, 1)), '2026-12');
    });

    test('closingDateFor usa o dia de fechamento no mês informado', () {
      final closing = CreditCardStore.closingDateFor(DateTime(2026, 4, 1), 12);
      expect(closing.year, 2026);
      expect(closing.month, 4);
      expect(closing.day, 12);
    });

    test('dueDateFor fica no mesmo mês quando vencimento é depois do fechamento', () {
      final due = CreditCardStore.dueDateFor(DateTime(2026, 4, 1), 10, 20);
      expect(due.year, 2026);
      expect(due.month, 4);
      expect(due.day, 20);
    });

    test('dueDateFor vai para mês seguinte quando vencimento é antes ou igual ao fechamento', () {
      final dueBefore = CreditCardStore.dueDateFor(DateTime(2026, 4, 1), 20, 10);
      final dueEqual = CreditCardStore.dueDateFor(DateTime(2026, 4, 1), 20, 20);

      expect(dueBefore.year, 2026);
      expect(dueBefore.month, 5);
      expect(dueBefore.day, 10);
      expect(dueEqual.month, 5);
      expect(dueEqual.day, 20);
    });

    test('dias são limitados entre 1 e 28 para evitar datas inválidas', () {
      final closing = CreditCardStore.closingDateFor(DateTime(2026, 2, 1), 31);
      final due = CreditCardStore.dueDateFor(DateTime(2026, 2, 1), 31, 31);

      expect(closing.day, 28);
      expect(due.day, 28);
    });
  });

  group('CreditCardStore persistence', () {
    test('upsertCard cria e edita cartão', () async {
      final db = await openCreditCardTestDatabase();
      final cardId = await CreditCardStore.upsertCard(db, card());

      await CreditCardStore.upsertCard(
        db,
        card(id: cardId).copyWith(name: 'Nubank Ultravioleta', creditLimit: 9000, updatedAt: DateTime(2026, 4, 2).toIso8601String()),
      );

      final cards = await CreditCardStore.getCards(db);
      expect(cards.length, 1);
      expect(cards.first.name, 'Nubank Ultravioleta');
      expect(cards.first.creditLimit, 9000);
      await db.close();
    });

    test('upsertCard rejeita fechamento e vencimento fora de 1 a 28', () async {
      final db = await openCreditCardTestDatabase();

      await expectLater(CreditCardStore.upsertCard(db, card(closingDay: 0)), throwsArgumentError);
      await expectLater(CreditCardStore.upsertCard(db, card(dueDay: 29)), throwsArgumentError);
      await db.close();
    });

    test('getOrCreateInvoice cria apenas uma fatura por cartão e mês', () async {
      final db = await openCreditCardTestDatabase();
      final cardId = await CreditCardStore.upsertCard(db, card(closingDay: 10, dueDay: 20));
      final savedCard = (await CreditCardStore.getCards(db)).firstWhere((item) => item.id == cardId);

      final first = await CreditCardStore.getOrCreateInvoice(db, card: savedCard, month: DateTime(2026, 4, 1));
      final second = await CreditCardStore.getOrCreateInvoice(db, card: savedCard, month: DateTime(2026, 4, 20));

      expect(first.id, second.id);
      expect(first.referenceMonth, '2026-04');
      expect(DateTime.parse(first.closingDate).day, 10);
      expect(DateTime.parse(first.dueDate).day, 20);
      await db.close();
    });

    test('recalculateInvoiceAmount soma apenas despesas não canceladas da fatura', () async {
      final db = await openCreditCardTestDatabase();
      final cardId = await CreditCardStore.upsertCard(db, card());
      final savedCard = (await CreditCardStore.getCards(db)).firstWhere((item) => item.id == cardId);
      final invoice = await CreditCardStore.getOrCreateInvoice(db, card: savedCard, month: DateTime(2026, 4, 1));
      final now = DateTime(2026, 4, 10).toIso8601String();

      await db.insert('transactions', {'title': 'Mercado', 'amount': 100, 'type': 'expense', 'status': 'pending', 'creditCardId': cardId, 'creditCardInvoiceId': invoice.id, 'createdAt': now, 'updatedAt': now});
      await db.insert('transactions', {'title': 'Farmácia', 'amount': 50, 'type': 'expense', 'status': 'paid', 'creditCardId': cardId, 'creditCardInvoiceId': invoice.id, 'createdAt': now, 'updatedAt': now});
      await db.insert('transactions', {'title': 'Cancelada', 'amount': 500, 'type': 'expense', 'status': 'canceled', 'creditCardId': cardId, 'creditCardInvoiceId': invoice.id, 'createdAt': now, 'updatedAt': now});
      await db.insert('transactions', {'title': 'Receita indevida', 'amount': 1000, 'type': 'income', 'status': 'paid', 'creditCardId': cardId, 'creditCardInvoiceId': invoice.id, 'createdAt': now, 'updatedAt': now});

      await CreditCardStore.recalculateInvoiceAmount(db, invoice.id!);
      final invoices = await CreditCardStore.getInvoices(db, cardId: cardId);

      expect(invoices.single.amount, 150);
      await db.close();
    });

    test('exportTables inclui cartões e faturas', () async {
      final db = await openCreditCardTestDatabase();
      final cardId = await CreditCardStore.upsertCard(db, card());
      final savedCard = (await CreditCardStore.getCards(db)).firstWhere((item) => item.id == cardId);
      await CreditCardStore.getOrCreateInvoice(db, card: savedCard, month: DateTime(2026, 4, 1));

      final exported = await CreditCardStore.exportTables(db);

      expect((exported['credit_cards'] as List).length, 1);
      expect((exported['credit_card_invoices'] as List).length, 1);
      await db.close();
    });
  });

  group('CreditCardStore purchases', () {
    test('createCardPurchase cria despesa vinculada ao cartão e recalcula fatura', () async {
      final db = await openCreditCardTestDatabase();
      final cardId = await CreditCardStore.upsertCard(db, card());

      final transactionId = await CreditCardStore.createCardPurchase(
        db,
        cardId: cardId,
        title: 'Mercado',
        description: 'Compra semanal',
        amount: 123.45,
        purchaseDate: DateTime(2026, 4, 15),
        categoryId: 1,
        subcategoryId: 10,
        notes: 'Sem juros',
        tags: 'casa, mercado',
      );

      final transaction = (await db.query('transactions', where: 'id = ?', whereArgs: [transactionId])).first;
      final invoices = await CreditCardStore.getInvoices(db, cardId: cardId);

      expect(invoices.length, 1);
      expect(invoices.first.referenceMonth, '2026-04');
      expect(invoices.first.amount, 123.45);
      expect(transaction['creditCardId'], cardId);
      expect(transaction['creditCardInvoiceId'], invoices.first.id);
      expect(transaction['paymentMethod'], 'cartão de crédito');
      expect(transaction['status'], 'pending');
      expect(transaction['categoryId'], 1);
      expect(transaction['subcategoryId'], 10);
      await db.close();
    });

    test('createCardPurchase reutiliza fatura existente do mês', () async {
      final db = await openCreditCardTestDatabase();
      final cardId = await CreditCardStore.upsertCard(db, card());

      await CreditCardStore.createCardPurchase(db, cardId: cardId, title: 'Compra 1', amount: 100, purchaseDate: DateTime(2026, 4, 1));
      await CreditCardStore.createCardPurchase(db, cardId: cardId, title: 'Compra 2', amount: 50, purchaseDate: DateTime(2026, 4, 20));

      final invoices = await CreditCardStore.getInvoices(db, cardId: cardId);
      final transactions = await db.query('transactions');

      expect(invoices.length, 1);
      expect(invoices.first.amount, 150);
      expect(transactions.length, 2);
      await db.close();
    });

    test('createCardPurchase bloqueia cartão arquivado', () async {
      final db = await openCreditCardTestDatabase();
      final cardId = await CreditCardStore.upsertCard(db, card(isArchived: true));

      await expectLater(
        CreditCardStore.createCardPurchase(db, cardId: cardId, title: 'Compra', amount: 10, purchaseDate: DateTime(2026, 4, 1)),
        throwsArgumentError,
      );
      await db.close();
    });
  });

  group('CreditCardStore invoice payments', () {
    test('payInvoice registra pagamento total e cria transação paga na conta', () async {
      final (db, _, invoiceId) = await seedCardInvoiceWithAmount(amount: 150);
      final paidDate = DateTime(2026, 4, 20);

      final transactionId = await CreditCardStore.payInvoice(db, invoiceId: invoiceId, paymentAccountId: 7, paidDate: paidDate, notes: 'Pago no app do banco');
      final invoice = (await CreditCardStore.getInvoices(db)).firstWhere((item) => item.id == invoiceId);
      final payment = (await db.query('transactions', where: 'id = ?', whereArgs: [transactionId])).first;

      expect(invoice.status, 'paid');
      expect(invoice.paidAmount, 150);
      expect(invoice.paymentAccountId, 7);
      expect(DateTime.parse(invoice.paidDate!).day, 20);
      expect(payment['amount'], 150);
      expect(payment['type'], 'expense');
      expect(payment['status'], 'paid');
      expect(payment['accountId'], 7);
      expect(payment['ignoreInReports'], 1);
      expect(payment['ignoreInMonthlySavings'], 1);
      expect(payment['creditCardPaymentInvoiceId'], invoiceId);
      await db.close();
    });

    test('payInvoice permite pagamento parcial', () async {
      final (db, _, invoiceId) = await seedCardInvoiceWithAmount(amount: 200);

      await CreditCardStore.payInvoice(db, invoiceId: invoiceId, paymentAccountId: 3, amount: 80, paidDate: DateTime(2026, 4, 20));
      final invoice = (await CreditCardStore.getInvoices(db)).firstWhere((item) => item.id == invoiceId);

      expect(invoice.status, 'partial');
      expect(invoice.paidAmount, 80);
      expect(invoice.paidDate, null);
      await db.close();
    });

    test('payInvoice bloqueia pagamento maior que fatura', () async {
      final (db, _, invoiceId) = await seedCardInvoiceWithAmount(amount: 100);

      await expectLater(
        CreditCardStore.payInvoice(db, invoiceId: invoiceId, paymentAccountId: 1, amount: 101),
        throwsArgumentError,
      );
      await db.close();
    });

    test('payInvoice bloqueia fatura já paga', () async {
      final (db, _, invoiceId) = await seedCardInvoiceWithAmount(amount: 100);

      await CreditCardStore.payInvoice(db, invoiceId: invoiceId, paymentAccountId: 1, paidDate: DateTime(2026, 4, 20));

      await expectLater(
        CreditCardStore.payInvoice(db, invoiceId: invoiceId, paymentAccountId: 1, paidDate: DateTime(2026, 4, 21)),
        throwsArgumentError,
      );
      await db.close();
    });
  });
}
