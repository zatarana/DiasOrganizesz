import 'package:diasorganize/data/models/budget_model.dart';
import 'package:diasorganize/data/models/transaction_model.dart';
import 'package:diasorganize/features/finance/finance_budget_rules.dart';
import 'package:flutter_test/flutter_test.dart';

FinancialTransaction tx({
  required double amount,
  int? categoryId,
  int? subcategoryId,
  String status = 'pending',
  bool ignoreInTotals = false,
}) {
  return FinancialTransaction(
    title: 'Despesa',
    amount: amount,
    type: 'expense',
    transactionDate: '2026-04-10T00:00:00.000',
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    status: status,
    ignoreInTotals: ignoreInTotals,
    createdAt: '2026-04-01T00:00:00.000',
    updatedAt: '2026-04-01T00:00:00.000',
  );
}

Budget budget({
  int? categoryId,
  int? subcategoryId,
  double limit = 1000,
  String month = '2026-04',
}) {
  return Budget(
    name: 'Orçamento',
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    limitAmount: limit,
    month: month,
    createdAt: '2026-04-01T00:00:00.000',
    updatedAt: '2026-04-01T00:00:00.000',
  );
}

void main() {
  group('FinanceBudgetRules', () {
    test('orçamento geral considera despesas do mês inteiro', () {
      final usage = FinanceBudgetRules.usageFor(
        budget(limit: 1000),
        [
          tx(amount: 100, categoryId: 1, subcategoryId: 10),
          tx(amount: 200, categoryId: 2, subcategoryId: 20, status: 'paid'),
        ],
      );

      expect(usage.plannedAmount, 300);
      expect(usage.paidAmount, 200);
      expect(usage.availableAmount, 700);
    });

    test('orçamento por categoria considera apenas categoria escolhida', () {
      final usage = FinanceBudgetRules.usageFor(
        budget(categoryId: 1, limit: 500),
        [
          tx(amount: 100, categoryId: 1, subcategoryId: 10),
          tx(amount: 200, categoryId: 1, subcategoryId: 11, status: 'paid'),
          tx(amount: 300, categoryId: 2, subcategoryId: 20),
        ],
      );

      expect(usage.plannedAmount, 300);
      expect(usage.paidAmount, 200);
      expect(usage.availableAmount, 200);
    });

    test('orçamento por subcategoria considera apenas subcategoria escolhida', () {
      final usage = FinanceBudgetRules.usageFor(
        budget(categoryId: 1, subcategoryId: 10, limit: 250),
        [
          tx(amount: 100, categoryId: 1, subcategoryId: 10),
          tx(amount: 200, categoryId: 1, subcategoryId: 11),
          tx(amount: 300, categoryId: 2, subcategoryId: 10),
        ],
      );

      expect(usage.plannedAmount, 100);
      expect(usage.paidAmount, 0);
      expect(usage.availableAmount, 150);
    });

    test('ignora canceladas, receitas e movimentações fora dos totais', () {
      final usage = FinanceBudgetRules.usageFor(
        budget(limit: 1000),
        [
          tx(amount: 100, status: 'canceled'),
          tx(amount: 200, ignoreInTotals: true),
          FinancialTransaction(
            title: 'Receita',
            amount: 300,
            type: 'income',
            transactionDate: '2026-04-10T00:00:00.000',
            status: 'paid',
            createdAt: '2026-04-01T00:00:00.000',
            updatedAt: '2026-04-01T00:00:00.000',
          ),
          tx(amount: 400, status: 'paid'),
        ],
      );

      expect(usage.plannedAmount, 400);
      expect(usage.paidAmount, 400);
    });

    test('não mistura meses diferentes', () {
      final usage = FinanceBudgetRules.usageFor(
        budget(month: '2026-04'),
        [
          tx(amount: 100),
          FinancialTransaction(
            title: 'Despesa maio',
            amount: 200,
            type: 'expense',
            transactionDate: '2026-05-01T00:00:00.000',
            status: 'pending',
            createdAt: '2026-04-01T00:00:00.000',
            updatedAt: '2026-04-01T00:00:00.000',
          ),
        ],
      );

      expect(usage.plannedAmount, 100);
    });
  });
}
