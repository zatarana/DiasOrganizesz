import 'package:diasorganize/data/models/transaction_model.dart';
import 'package:diasorganize/features/finance/finance_monthly_evolution_report.dart';
import 'package:flutter_test/flutter_test.dart';

FinancialTransaction tx({
  required String type,
  required double amount,
  required String date,
  String status = 'paid',
  bool ignoreInTotals = false,
  bool ignoreInMonthlySavings = false,
}) {
  return FinancialTransaction(
    title: type == 'income' ? 'Receita' : 'Despesa',
    amount: amount,
    type: type,
    transactionDate: date,
    paidDate: status == 'paid' ? date : null,
    status: status,
    ignoreInTotals: ignoreInTotals,
    ignoreInMonthlySavings: ignoreInMonthlySavings,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  group('FinanceMonthlyEvolutionReport', () {
    test('gera um item para cada mês do intervalo', () {
      final report = FinanceMonthlyEvolutionReport.fromTransactions(
        startMonth: DateTime(2026, 1, 10),
        endMonth: DateTime(2026, 3, 20),
        transactions: const [],
      );

      expect(report.items.length, 3);
      expect(report.items[0].month, DateTime(2026, 1, 1));
      expect(report.items[1].month, DateTime(2026, 2, 1));
      expect(report.items[2].month, DateTime(2026, 3, 1));
    });

    test('calcula receitas, despesas e resultado realizado por mês', () {
      final report = FinanceMonthlyEvolutionReport.fromTransactions(
        startMonth: DateTime(2026, 1, 1),
        endMonth: DateTime(2026, 2, 1),
        transactions: [
          tx(type: 'income', amount: 3000, date: '2026-01-10T00:00:00.000'),
          tx(type: 'expense', amount: 1200, date: '2026-01-11T00:00:00.000'),
          tx(type: 'income', amount: 2000, date: '2026-02-10T00:00:00.000'),
          tx(type: 'expense', amount: 2500, date: '2026-02-11T00:00:00.000'),
        ],
      );

      expect(report.items[0].paidIncome, 3000);
      expect(report.items[0].paidExpense, 1200);
      expect(report.items[0].realizedResult, 1800);
      expect(report.items[1].paidIncome, 2000);
      expect(report.items[1].paidExpense, 2500);
      expect(report.items[1].realizedResult, -500);
    });

    test('calcula totais e identifica melhor e pior mês', () {
      final report = FinanceMonthlyEvolutionReport.fromTransactions(
        startMonth: DateTime(2026, 1, 1),
        endMonth: DateTime(2026, 3, 1),
        transactions: [
          tx(type: 'income', amount: 3000, date: '2026-01-10T00:00:00.000'),
          tx(type: 'expense', amount: 1000, date: '2026-01-11T00:00:00.000'),
          tx(type: 'income', amount: 2000, date: '2026-02-10T00:00:00.000'),
          tx(type: 'expense', amount: 2500, date: '2026-02-11T00:00:00.000'),
          tx(type: 'income', amount: 4000, date: '2026-03-10T00:00:00.000'),
          tx(type: 'expense', amount: 500, date: '2026-03-11T00:00:00.000'),
        ],
      );

      expect(report.totalPaidIncome, 9000);
      expect(report.totalPaidExpense, 4000);
      expect(report.totalRealizedResult, 5000);
      expect(report.bestResultMonth?.month, DateTime(2026, 3, 1));
      expect(report.worstResultMonth?.month, DateTime(2026, 2, 1));
    });

    test('respeita ignoreInTotals e ignoreInMonthlySavings', () {
      final report = FinanceMonthlyEvolutionReport.fromTransactions(
        startMonth: DateTime(2026, 4, 1),
        endMonth: DateTime(2026, 4, 1),
        transactions: [
          tx(type: 'income', amount: 3000, date: '2026-04-10T00:00:00.000'),
          tx(type: 'income', amount: 999, date: '2026-04-10T00:00:00.000', ignoreInTotals: true),
          tx(type: 'expense', amount: 1000, date: '2026-04-11T00:00:00.000'),
          tx(type: 'expense', amount: 500, date: '2026-04-12T00:00:00.000', ignoreInMonthlySavings: true),
        ],
      );

      expect(report.items.single.paidIncome, 3000);
      expect(report.items.single.paidExpense, 1500);
      expect(report.items.single.monthlySavings, 2000);
    });

    test('bloqueia intervalo invertido', () {
      expect(
        () => FinanceMonthlyEvolutionReport.fromTransactions(
          startMonth: DateTime(2026, 5, 1),
          endMonth: DateTime(2026, 4, 1),
          transactions: const [],
        ),
        throwsArgumentError,
      );
    });
  });
}
