import 'package:diasorganize/data/models/financial_goal_model.dart';
import 'package:diasorganize/data/models/transaction_model.dart';
import 'package:diasorganize/features/finance/financial_goal_rules.dart';
import 'package:flutter_test/flutter_test.dart';

FinancialGoal goal({
  double targetAmount = 1000,
  double currentAmount = 250,
  String? targetDate,
  bool isArchived = false,
}) {
  final now = DateTime(2026, 4, 1).toIso8601String();
  return FinancialGoal(
    name: 'Viagem',
    targetAmount: targetAmount,
    currentAmount: currentAmount,
    targetDate: targetDate,
    isArchived: isArchived,
    createdAt: now,
    updatedAt: now,
  );
}

FinancialTransaction tx({
  required String type,
  required double amount,
  String status = 'paid',
  bool ignoreInMonthlySavings = false,
  bool ignoreInTotals = false,
}) {
  return FinancialTransaction(
    title: type == 'income' ? 'Receita' : 'Despesa',
    amount: amount,
    type: type,
    transactionDate: '2026-04-10T00:00:00.000',
    paidDate: status == 'paid' ? '2026-04-10T00:00:00.000' : null,
    status: status,
    ignoreInMonthlySavings: ignoreInMonthlySavings,
    ignoreInTotals: ignoreInTotals,
    createdAt: '2026-04-01T00:00:00.000',
    updatedAt: '2026-04-01T00:00:00.000',
  );
}

void main() {
  group('FinancialGoalRules progress', () {
    test('calcula progresso, percentual e restante', () {
      final progress = FinancialGoalRules.progressFor(goal(targetAmount: 1000, currentAmount: 250));

      expect(progress.ratio, 0.25);
      expect(progress.percent, 25);
      expect(progress.remainingAmount, 750);
      expect(progress.isCompleted, false);
    });

    test('limita percentual a 100 e marca como concluído', () {
      final progress = FinancialGoalRules.progressFor(goal(targetAmount: 1000, currentAmount: 1500));

      expect(progress.ratio, 1);
      expect(progress.percent, 100);
      expect(progress.remainingAmount, 0);
      expect(progress.isCompleted, true);
    });

    test('calcula dias restantes e contribuição mensal necessária', () {
      final progress = FinancialGoalRules.progressFor(
        goal(
          targetAmount: 1200,
          currentAmount: 300,
          targetDate: DateTime(2026, 7, 1).toIso8601String(),
        ),
      );

      expect(progress.daysRemaining(now: DateTime(2026, 4, 1)), 91);
      expect(progress.requiredMonthlySaving(now: DateTime(2026, 4, 1)), 225);
    });

    test('sem data alvo retorna nulo para prazo e contribuição mensal', () {
      final progress = FinancialGoalRules.progressFor(goal(targetDate: null));

      expect(progress.daysRemaining(now: DateTime(2026, 4, 1)), null);
      expect(progress.requiredMonthlySaving(now: DateTime(2026, 4, 1)), null);
    });

    test('progressForAll ignora arquivados', () {
      final progress = FinancialGoalRules.progressForAll([
        goal(targetAmount: 1000, currentAmount: 100),
        goal(targetAmount: 2000, currentAmount: 200, isArchived: true),
      ]);

      expect(progress.length, 1);
      expect(progress.first.targetAmount, 1000);
    });
  });

  group('FinancialGoalRules monthly savings', () {
    test('calcula economia mensal com receitas e despesas pagas', () {
      final savings = FinancialGoalRules.monthlySavings(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(type: 'income', amount: 3000),
          tx(type: 'expense', amount: 1200),
        ],
      );

      expect(savings, 1800);
    });

    test('respeita ignoreInMonthlySavings e ignoreInTotals', () {
      final savings = FinancialGoalRules.monthlySavings(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(type: 'income', amount: 3000),
          tx(type: 'expense', amount: 1000),
          tx(type: 'expense', amount: 500, ignoreInMonthlySavings: true),
          tx(type: 'income', amount: 999, ignoreInTotals: true),
        ],
      );

      expect(savings, 2000);
    });

    test('sugestão de contribuição usa percentual da economia positiva', () {
      final suggestion = FinancialGoalRules.suggestedGoalContribution(
        month: DateTime(2026, 4, 1),
        allocationPercent: 25,
        transactions: [
          tx(type: 'income', amount: 4000),
          tx(type: 'expense', amount: 1000),
        ],
      );

      expect(suggestion, 750);
    });

    test('sugestão de contribuição retorna zero se economia for negativa', () {
      final suggestion = FinancialGoalRules.suggestedGoalContribution(
        month: DateTime(2026, 4, 1),
        allocationPercent: 50,
        transactions: [
          tx(type: 'income', amount: 1000),
          tx(type: 'expense', amount: 1500),
        ],
      );

      expect(suggestion, 0);
    });
  });
}
