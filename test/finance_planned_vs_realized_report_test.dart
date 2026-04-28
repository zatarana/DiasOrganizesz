import 'package:diasorganize/data/models/transaction_model.dart';
import 'package:diasorganize/features/finance/finance_planned_vs_realized_report.dart';
import 'package:flutter_test/flutter_test.dart';

FinancialTransaction tx({
  required String type,
  required double amount,
  String status = 'pending',
  String date = '2026-04-10T00:00:00.000',
  bool ignoreInTotals = false,
}) {
  return FinancialTransaction(
    title: type == 'income' ? 'Receita' : 'Despesa',
    amount: amount,
    type: type,
    transactionDate: date,
    paidDate: status == 'paid' ? date : null,
    status: status,
    ignoreInTotals: ignoreInTotals,
    createdAt: '2026-04-01T00:00:00.000',
    updatedAt: '2026-04-01T00:00:00.000',
  );
}

void main() {
  group('FinancePlannedVsRealizedReport', () {
    test('calcula previsto, realizado e diferenças do mês', () {
      final report = FinancePlannedVsRealizedReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(type: 'income', amount: 3000),
          tx(type: 'income', amount: 1000, status: 'paid'),
          tx(type: 'expense', amount: 1200),
          tx(type: 'expense', amount: 400, status: 'paid'),
        ],
      );

      expect(report.expectedIncome, 4000);
      expect(report.realizedIncome, 1000);
      expect(report.expectedExpense, 1600);
      expect(report.realizedExpense, 400);
      expect(report.expectedResult, 2400);
      expect(report.realizedResult, 600);
      expect(report.resultDifference, -1800);
    });

    test('calcula percentuais de realização', () {
      final report = FinancePlannedVsRealizedReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(type: 'income', amount: 1000),
          tx(type: 'income', amount: 500, status: 'paid'),
          tx(type: 'expense', amount: 1000),
          tx(type: 'expense', amount: 250, status: 'paid'),
        ],
      );

      expect(report.incomeRealizationRatio, 0.5);
      expect(report.expenseRealizationRatio, 0.25);
    });

    test('ignora movimentações canceladas e ignoradas nos totais', () {
      final report = FinancePlannedVsRealizedReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(type: 'income', amount: 1000, status: 'canceled'),
          tx(type: 'income', amount: 500, ignoreInTotals: true),
          tx(type: 'expense', amount: 200, status: 'canceled'),
          tx(type: 'expense', amount: 100, ignoreInTotals: true),
          tx(type: 'income', amount: 300, status: 'paid'),
          tx(type: 'expense', amount: 120, status: 'paid'),
        ],
      );

      expect(report.expectedIncome, 300);
      expect(report.realizedIncome, 300);
      expect(report.expectedExpense, 120);
      expect(report.realizedExpense, 120);
    });

    test('não mistura meses diferentes', () {
      final report = FinancePlannedVsRealizedReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(type: 'income', amount: 1000, status: 'paid'),
          tx(type: 'income', amount: 5000, status: 'paid', date: '2026-05-01T00:00:00.000'),
          tx(type: 'expense', amount: 100, status: 'paid'),
          tx(type: 'expense', amount: 900, status: 'paid', date: '2026-05-01T00:00:00.000'),
        ],
      );

      expect(report.realizedIncome, 1000);
      expect(report.realizedExpense, 100);
      expect(report.realizedResult, 900);
    });

    test('indica quando realizado ficou melhor que previsto', () {
      final report = FinancePlannedVsRealizedReport(
        month: DateTime(2026, 4, 1),
        expectedIncome: 1000,
        realizedIncome: 1200,
        expectedExpense: 600,
        realizedExpense: 500,
      );

      expect(report.expectedResult, 400);
      expect(report.realizedResult, 700);
      expect(report.realizedBetterThanExpected, true);
    });
  });
}
