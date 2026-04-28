import 'package:diasorganize/data/database/credit_card_store.dart';
import 'package:diasorganize/data/models/credit_card_invoice_model.dart';
import 'package:diasorganize/data/models/credit_card_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openCreditCardTestDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await databaseFactory.openDatabase(inMemoryDatabasePath);

  await db.execute('''
    CREATE TABLE transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      amount REAL NOT NULL,
      type TEXT NOT NULL,
      status TEXT NOT NULL,
      createdAt TEXT,
      updatedAt TEXT
    )
  ''');

  await CreditCardStore.ensureTables(db);
  return db;
}

CreditCard card({int? id, int closingDay = 10, int dueDay = 20}) {
  final now = DateTime(2026, 4, 1).toIso8601String();
  return CreditCard(
    id: id,
    name: 'Nubank',
    issuer: 'Nubank',
    creditLimit: 5000,
    closingDay: closingDay,
    dueDay: dueDay,
    createdAt: now,
    updatedAt: now,
  );
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

      expect(() => CreditCardStore.upsertCard(db, card(closingDay: 0)), throwsArgumentError);
      expect(() => CreditCardStore.upsertCard(db, card(dueDay: 29)), throwsArgumentError);
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

      await db.insert('transactions', {
        'title': 'Mercado',
        'amount': 100,
        'type': 'expense',
        'status': 'pending',
        'creditCardId': cardId,
        'creditCardInvoiceId': invoice.id,
        'createdAt': now,
        'updatedAt': now,
      });
      await db.insert('transactions', {
        'title': 'Farmácia',
        'amount': 50,
        'type': 'expense',
        'status': 'paid',
        'creditCardId': cardId,
        'creditCardInvoiceId': invoice.id,
        'createdAt': now,
        'updatedAt': now,
      });
      await db.insert('transactions', {
        'title': 'Cancelada',
        'amount': 500,
        'type': 'expense',
        'status': 'canceled',
        'creditCardId': cardId,
        'creditCardInvoiceId': invoice.id,
        'createdAt': now,
        'updatedAt': now,
      });
      await db.insert('transactions', {
        'title': 'Receita indevida',
        'amount': 1000,
        'type': 'income',
        'status': 'paid',
        'creditCardId': cardId,
        'creditCardInvoiceId': invoice.id,
        'createdAt': now,
        'updatedAt': now,
      });

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
}
