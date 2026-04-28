import 'package:diasorganize/data/models/financial_category_model.dart';
import 'package:diasorganize/data/models/transaction_model.dart';
import 'package:diasorganize/features/finance/finance_category_report.dart';
import 'package:flutter_test/flutter_test.dart';

FinancialTransaction tx({
  required double amount,
  int? categoryId,
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
    status: status,
    ignoreInReports: ignoreInReports,
    ignoreInTotals: ignoreInTotals,
    createdAt: '2026-04-01T00:00:00.000',
    updatedAt: '2026-04-01T00:00:00.000',
  );
}

void main() {
  group('FinanceCategoryReport', () {
    final food = FinancialCategory(
      id: 1,
      name: 'Alimentação',
      type: 'expense',
      color: '0xFF4CAF50',
      icon: 'restaurant',
      createdAt: '2026-04-01T00:00:00.000',
      updatedAt: '2026-04-01T00:00:00.000',
    );
    final transport = FinancialCategory(
      id: 2,
      name: 'Transporte',
      type: 'expense',
      color: '0xFF2196F3',
      icon: 'directions_car',
      createdAt: '2026-04-01T00:00:00.000',
      updatedAt: '2026-04-01T00:00:00.000',
    );

    test('agrupa e ordena despesas pagas por categoria', () {
      final report = FinanceCategoryReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(amount: 100, categoryId: 1),
          tx(amount: 250, categoryId: 1),
          tx(amount: 80, categoryId: 2),
        ],
        categories: [food, transport],
      );

      expect(report.items.length, 2);
      expect(report.topItem?.categoryName, 'Alimentação');
      expect(report.topItem?.amount, 350);
      expect(report.topItem?.transactionCount, 2);
      expect(report.total, 430);
    });

    test('calcula percentual sobre total do relatório', () {
      final report = FinanceCategoryReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(amount: 300, categoryId: 1),
          tx(amount: 100, categoryId: 2),
        ],
        categories: [food, transport],
      );

      expect(report.topItem?.percentOf(report.total), 75);
    });

    test('usa fallback Sem categoria', () {
      final report = FinanceCategoryReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [tx(amount: 50)],
        categories: const [],
      );

      expect(report.items.first.categoryName, 'Sem categoria');
    });

    test('ignora canceladas, pendentes e fora de relatórios', () {
      final report = FinanceCategoryReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(amount: 100, categoryId: 1),
          tx(amount: 200, categoryId: 1, status: 'pending'),
          tx(amount: 300, categoryId: 1, status: 'canceled'),
          tx(amount: 400, categoryId: 1, ignoreInReports: true),
          tx(amount: 500, categoryId: 1, ignoreInTotals: true),
        ],
        categories: [food],
      );

      expect(report.total, 100);
      expect(report.items.single.transactionCount, 1);
    });

    test('não mistura meses diferentes', () {
      final report = FinanceCategoryReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(amount: 100, categoryId: 1),
          FinancialTransaction(
            title: 'Despesa maio',
            amount: 200,
            type: 'expense',
            transactionDate: '2026-05-01T00:00:00.000',
            paidDate: '2026-05-01T00:00:00.000',
            categoryId: 1,
            status: 'paid',
            createdAt: '2026-04-01T00:00:00.000',
            updatedAt: '2026-04-01T00:00:00.000',
          ),
        ],
        categories: [food],
      );

      expect(report.total, 100);
    });
  });
}
