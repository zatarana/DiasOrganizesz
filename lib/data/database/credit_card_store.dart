import 'package:sqflite/sqflite.dart';

import '../models/credit_card_invoice_model.dart';
import '../models/credit_card_model.dart';

class CreditCardStore {
  static bool _indexesEnsured = false;

  static Future<void> ensureTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_cards (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        issuer TEXT,
        creditLimit REAL NOT NULL DEFAULT 0,
        closingDay INTEGER NOT NULL,
        dueDay INTEGER NOT NULL,
        paymentAccountId INTEGER,
        color TEXT NOT NULL DEFAULT '0xFF673AB7',
        icon TEXT NOT NULL DEFAULT 'credit_card',
        isArchived INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_card_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cardId INTEGER NOT NULL,
        referenceMonth TEXT NOT NULL,
        closingDate TEXT NOT NULL,
        dueDate TEXT NOT NULL,
        amount REAL NOT NULL DEFAULT 0,
        paidAmount REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'open',
        paymentAccountId INTEGER,
        paidDate TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL
      )
    ''');
    await _addColumnIfMissing(db, 'transactions', 'creditCardId INTEGER');
    await _addColumnIfMissing(db, 'transactions', 'creditCardInvoiceId INTEGER');
    await _ensureIndexes(db);
  }

  static Future<void> _ensureIndexes(Database db) async {
    if (_indexesEnsured) return;
    await db.execute('CREATE INDEX IF NOT EXISTS idx_credit_cards_archived_name ON credit_cards(isArchived, name)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_credit_card_invoices_card_month ON credit_card_invoices(cardId, referenceMonth)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_credit_card_invoices_status_due ON credit_card_invoices(status, dueDate)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_credit_card_invoice ON transactions(creditCardId, creditCardInvoiceId)');
    _indexesEnsured = true;
  }

  static Future<void> _addColumnIfMissing(Database db, String table, String columnSql) async {
    try {
      await db.execute('ALTER TABLE $table ADD COLUMN $columnSql');
    } catch (_) {}
  }

  static int _safeDay(int day) => day.clamp(1, 28).toInt();

  static String referenceMonth(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
  }

  static DateTime closingDateFor(DateTime month, int closingDay) {
    return DateTime(month.year, month.month, _safeDay(closingDay));
  }

  static DateTime dueDateFor(DateTime month, int closingDay, int dueDay) {
    final closing = closingDateFor(month, closingDay);
    final safeDueDay = _safeDay(dueDay);
    final dueMonthOffset = safeDueDay <= closing.day ? 1 : 0;
    return DateTime(month.year, month.month + dueMonthOffset, safeDueDay);
  }

  static Future<List<CreditCard>> getCards(Database db, {bool includeArchived = true}) async {
    await ensureTables(db);
    final rows = await db.query(
      'credit_cards',
      where: includeArchived ? null : 'isArchived = 0',
      orderBy: 'isArchived ASC, name ASC',
    );
    return rows.map(CreditCard.fromMap).toList();
  }

  static Future<int> upsertCard(Database db, CreditCard card) async {
    await ensureTables(db);
    if (card.closingDay < 1 || card.closingDay > 28) throw ArgumentError('O dia de fechamento deve estar entre 1 e 28.');
    if (card.dueDay < 1 || card.dueDay > 28) throw ArgumentError('O dia de vencimento deve estar entre 1 e 28.');
    if (card.id == null) return db.insert('credit_cards', card.toMap());
    await db.update('credit_cards', card.toMap(), where: 'id = ?', whereArgs: [card.id]);
    return card.id!;
  }

  static Future<List<CreditCardInvoice>> getInvoices(Database db, {int? cardId}) async {
    await ensureTables(db);
    final rows = await db.query(
      'credit_card_invoices',
      where: cardId == null ? null : 'cardId = ?',
      whereArgs: cardId == null ? null : [cardId],
      orderBy: 'referenceMonth DESC, dueDate DESC, id DESC',
    );
    return rows.map(CreditCardInvoice.fromMap).toList();
  }

  static Future<CreditCardInvoice> getOrCreateInvoice(Database db, {required CreditCard card, required DateTime month}) async {
    await ensureTables(db);
    if (card.id == null) throw ArgumentError('Cartão precisa estar salvo antes de criar fatura.');
    final refMonth = referenceMonth(month);
    final existing = await db.query(
      'credit_card_invoices',
      where: 'cardId = ? AND referenceMonth = ?',
      whereArgs: [card.id, refMonth],
      limit: 1,
    );
    if (existing.isNotEmpty) return CreditCardInvoice.fromMap(existing.first);

    final now = DateTime.now().toIso8601String();
    final invoice = CreditCardInvoice(
      cardId: card.id!,
      referenceMonth: refMonth,
      closingDate: closingDateFor(month, card.closingDay).toIso8601String(),
      dueDate: dueDateFor(month, card.closingDay, card.dueDay).toIso8601String(),
      paymentAccountId: card.paymentAccountId,
      createdAt: now,
      updatedAt: now,
    );
    final id = await db.insert('credit_card_invoices', invoice.toMap());
    return invoice.copyWith(id: id);
  }

  static Future<int> upsertInvoice(Database db, CreditCardInvoice invoice) async {
    await ensureTables(db);
    if (invoice.id == null) return db.insert('credit_card_invoices', invoice.toMap());
    await db.update('credit_card_invoices', invoice.toMap(), where: 'id = ?', whereArgs: [invoice.id]);
    return invoice.id!;
  }

  static Future<void> recalculateInvoiceAmount(Database db, int invoiceId) async {
    await ensureTables(db);
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM transactions
      WHERE creditCardInvoiceId = ?
        AND status != 'canceled'
        AND type = 'expense'
      ''',
      [invoiceId],
    );
    final totalRaw = rows.first['total'];
    final total = totalRaw is num ? totalRaw.toDouble() : double.tryParse('$totalRaw') ?? 0.0;
    await db.update(
      'credit_card_invoices',
      {
        'amount': total,
        'updatedAt': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [invoiceId],
    );
  }

  static Future<void> resetCardData(Database db) async {
    await ensureTables(db);
    await db.delete('credit_card_invoices');
    await db.delete('credit_cards');
  }

  static Future<Map<String, dynamic>> exportTables(Database db) async {
    await ensureTables(db);
    return {
      'credit_cards': await db.query('credit_cards', orderBy: 'id ASC'),
      'credit_card_invoices': await db.query('credit_card_invoices', orderBy: 'id ASC'),
    };
  }
}
