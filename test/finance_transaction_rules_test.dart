import 'package:flutter_test/flutter_test.dart';
import 'package:diasorganize/data/models/transaction_model.dart';
import 'package:diasorganize/features/finance/finance_monthly_summary.dart';
import 'package:diasorganize/features/finance/finance_transaction_rules.dart';

FinancialTransaction tx({
  int? id,
  String title = 'Movimentação',
  double amount = 100,
  String type = 'expense',
  String transactionDate = '2026-04-10T00:00:00.000',
  String? dueDate,
  String? paidDate,
  String status = 'pending',
  int? categoryId,
  String? tags,
  bool ignoreInTotals = false,
  bool ignoreInReports = false,
  bool ignoreInMonthlySavings = false,
}) {
  return FinancialTransaction(
    id: id,
    title: title,
    amount: amount,
    type: type,
    transactionDate: transactionDate,
    dueDate: dueDate,
    paidDate: paidDate,
    status: status,
    categoryId: categoryId,
    tags: tags,
    ignoreInTotals: ignoreInTotals,
    ignoreInReports: ignoreInReports,
    ignoreInMonthlySavings: ignoreInMonthlySavings,
    createdAt: '2026-04-01T00:00:00.000',
    updatedAt: '2026-04-01T00:00:00.000',
  );
}

void main() {
  group('FinanceTransactionRules', () {
    test('ignoreInTotals remove transação dos totais previstos e realizados', () {
      final month = DateTime(2026, 4, 1);
      final transactions = [
        tx(title: 'Salário', amount: 3000, type: 'income', status: 'paid', paidDate: '2026-04-05T00:00:00.000'),
        tx(title: 'Despesa real', amount: 500, type: 'expense', status: 'paid', paidDate: '2026-04-06T00:00:00.000'),
        tx(title: 'Despesa ignorada', amount: 200, type: 'expense', status: 'paid', paidDate: '2026-04-07T00:00:00.000', ignoreInTotals: true),
      ];

      final summary = FinanceMonthlySummary.fromTransactions(transactions: transactions, month: month);

      expect(summary.expectedIncome, 3000);
      expect(summary.expectedExpense, 500);
      expect(summary.paidIncome, 3000);
      expect(summary.paidExpense, 500);
      expect(summary.realizedResult, 2500);
    });

    test('ignoreInReports remove transação dos rankings por categoria', () {
      final month = DateTime(2026, 4, 1);
      final transactions = [
        tx(title: 'Mercado', amount: 800, type: 'expense', status: 'paid', paidDate: '2026-04-10T00:00:00.000', categoryId: 1),
        tx(title: 'Ajuste fora relatório', amount: 1200, type: 'expense', status: 'paid', paidDate: '2026-04-10T00:00:00.000', categoryId: 2, ignoreInReports: true),
      ];

      final summary = FinanceMonthlySummary.fromTransactions(transactions: transactions, month: month);

      expect(summary.paidExpensesByCategory[1], 800);
      expect(summary.paidExpensesByCategory.containsKey(2), false);
      expect(summary.topExpenseCategoryId, 1);
      expect(summary.topExpenseCategoryAmount, 800);
    });

    test('ignoreInMonthlySavings preserva totais mas remove da economia mensal', () {
      final month = DateTime(2026, 4, 1);
      final transactions = [
        tx(title: 'Salário', amount: 3000, type: 'income', status: 'paid', paidDate: '2026-04-05T00:00:00.000'),
        tx(title: 'Gasto comum', amount: 400, type: 'expense', status: 'paid', paidDate: '2026-04-06T00:00:00.000'),
        tx(title: 'Compra ignorada na economia', amount: 1000, type: 'expense', status: 'paid', paidDate: '2026-04-07T00:00:00.000', ignoreInMonthlySavings: true),
      ];

      final summary = FinanceMonthlySummary.fromTransactions(transactions: transactions, month: month);

      expect(summary.paidExpense, 1400);
      expect(summary.savingsExpense, 400);
      expect(summary.monthlySavings, 2600);
    });

    test('busca textual encontra tags', () {
      final transaction = tx(title: 'Compra', tags: 'essencial, casa, mercado');

      expect(FinanceTransactionRules.matchesText(transaction, 'casa'), true);
      expect(FinanceTransactionRules.matchesText(transaction, 'mercado'), true);
      expect(FinanceTransactionRules.matchesText(transaction, 'viagem'), false);
    });

    test('transação pendente vencida é identificada como atrasada', () {
      final transaction = tx(
        title: 'Conta vencida',
        status: 'pending',
        dueDate: '2026-04-01T00:00:00.000',
      );

      expect(FinanceTransactionRules.isOverdue(transaction, now: DateTime(2026, 4, 10)), true);
    });
  });
}
