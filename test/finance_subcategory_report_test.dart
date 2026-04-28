import 'package:diasorganize/data/models/financial_category_model.dart';
import 'package:diasorganize/data/models/financial_subcategory_model.dart';
import 'package:diasorganize/data/models/transaction_model.dart';
import 'package:diasorganize/features/finance/finance_subcategory_report.dart';
import 'package:flutter_test/flutter_test.dart';

FinancialTransaction tx({
  required double amount,
  int? categoryId,
  int? subcategoryId,
  String status = 'paid',
  bool ignoreInReports = false,
  bool ignoreInTotals = false,
}) {
  return FinancialTransaction(
    title: 'Despesa',
    amount: amount,
    type: 'expense',
    transactionDate: '2026-04-10T00:00:00.000',
    paidDate: status == 'paid' ? '2026-04-10T00:00:00.000' : null,
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    status: status,
    ignoreInReports: ignoreInReports,
    ignoreInTotals: ignoreInTotals,
    createdAt: '2026-04-01T00:00:00.000',
    updatedAt: '2026-04-01T00:00:00.000',
  );
}

void main() {
  group('FinanceSubcategoryReport', () {
    final food = FinancialCategory(
      id: 1,
      name: 'Alimentação',
      type: 'expense',
      color: '0xFF4CAF50',
      icon: 'restaurant',
      createdAt: '2026-04-01T00:00:00.000',
      updatedAt: '2026-04-01T00:00:00.000',
    );
    final home = FinancialCategory(
      id: 2,
      name: 'Casa',
      type: 'expense',
      color: '0xFF2196F3',
      icon: 'home',
      createdAt: '2026-04-01T00:00:00.000',
      updatedAt: '2026-04-01T00:00:00.000',
    );
    final market = FinancialSubcategory(
      id: 10,
      categoryId: 1,
      name: 'Mercado',
      createdAt: '2026-04-01T00:00:00.000',
      updatedAt: '2026-04-01T00:00:00.000',
    );
    final lunch = FinancialSubcategory(
      id: 11,
      categoryId: 1,
      name: 'Almoço',
      createdAt: '2026-04-01T00:00:00.000',
      updatedAt: '2026-04-01T00:00:00.000',
    );

    test('agrupa e ordena despesas pagas por subcategoria', () {
      final report = FinanceSubcategoryReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(amount: 100, categoryId: 1, subcategoryId: 10),
          tx(amount: 250, categoryId: 1, subcategoryId: 10),
          tx(amount: 80, categoryId: 1, subcategoryId: 11),
        ],
        categories: [food],
        subcategories: [market, lunch],
      );

      expect(report.items.length, 2);
      expect(report.topItem?.fullName, 'Alimentação / Mercado');
      expect(report.topItem?.amount, 350);
      expect(report.topItem?.transactionCount, 2);
      expect(report.total, 430);
    });

    test('calcula percentual sobre total do relatório', () {
      final report = FinanceSubcategoryReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(amount: 300, categoryId: 1, subcategoryId: 10),
          tx(amount: 100, categoryId: 2, subcategoryId: null),
        ],
        categories: [food, home],
        subcategories: [market],
      );

      expect(report.topItem?.percentOf(report.total), 75);
    });

    test('usa nomes fallback para sem categoria e sem subcategoria', () {
      final report = FinanceSubcategoryReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [tx(amount: 50)],
        categories: const [],
        subcategories: const [],
      );

      expect(report.items.first.categoryName, 'Sem categoria');
      expect(report.items.first.subcategoryName, 'Sem subcategoria');
    });

    test('ignora canceladas, pendentes e fora de relatórios', () {
      final report = FinanceSubcategoryReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(amount: 100, categoryId: 1, subcategoryId: 10),
          tx(amount: 200, categoryId: 1, subcategoryId: 10, status: 'pending'),
          tx(amount: 300, categoryId: 1, subcategoryId: 10, status: 'canceled'),
          tx(amount: 400, categoryId: 1, subcategoryId: 10, ignoreInReports: true),
          tx(amount: 500, categoryId: 1, subcategoryId: 10, ignoreInTotals: true),
        ],
        categories: [food],
        subcategories: [market],
      );

      expect(report.total, 100);
      expect(report.items.single.transactionCount, 1);
    });

    test('não mistura meses diferentes', () {
      final report = FinanceSubcategoryReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(amount: 100, categoryId: 1, subcategoryId: 10),
          FinancialTransaction(
            title: 'Despesa maio',
            amount: 200,
            type: 'expense',
            transactionDate: '2026-05-01T00:00:00.000',
            paidDate: '2026-05-01T00:00:00.000',
            categoryId: 1,
            subcategoryId: 10,
            status: 'paid',
            createdAt: '2026-04-01T00:00:00.000',
            updatedAt: '2026-04-01T00:00:00.000',
          ),
        ],
        categories: [food],
        subcategories: [market],
      );

      expect(report.total, 100);
    });
  });
}
