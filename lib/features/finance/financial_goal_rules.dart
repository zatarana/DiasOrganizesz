import '../../data/models/financial_goal_model.dart';
import '../../data/models/transaction_model.dart';
import 'finance_monthly_summary.dart';

class FinancialGoalProgress {
  final FinancialGoal goal;
  final double currentAmount;
  final double targetAmount;

  const FinancialGoalProgress({
    required this.goal,
    required this.currentAmount,
    required this.targetAmount,
  });

  double get remainingAmount => (targetAmount - currentAmount).clamp(0.0, double.infinity).toDouble();
  double get ratio => targetAmount <= 0 ? 0 : (currentAmount / targetAmount).clamp(0.0, 1.0).toDouble();
  double get percent => ratio * 100;
  bool get isCompleted => currentAmount >= targetAmount;

  int? daysRemaining({DateTime? now}) {
    if (goal.targetDate == null) return null;
    final target = DateTime.tryParse(goal.targetDate!);
    if (target == null) return null;
    final source = now ?? DateTime.now();
    final today = DateTime(source.year, source.month, source.day);
    final targetDay = DateTime(target.year, target.month, target.day);
    return targetDay.difference(today).inDays;
  }

  double? requiredMonthlySaving({DateTime? now}) {
    final days = daysRemaining(now: now);
    if (days == null) return null;
    if (remainingAmount <= 0) return 0;
    if (days <= 0) return remainingAmount;
    final months = (days / 30).ceil();
    return remainingAmount / months;
  }
}

class FinancialGoalRules {
  const FinancialGoalRules._();

  static FinancialGoalProgress progressFor(FinancialGoal goal) {
    return FinancialGoalProgress(
      goal: goal,
      currentAmount: goal.currentAmount,
      targetAmount: goal.targetAmount,
    );
  }

  static List<FinancialGoalProgress> progressForAll(List<FinancialGoal> goals) {
    return goals.where((goal) => !goal.isArchived).map(progressFor).toList();
  }

  static double monthlySavings({
    required List<FinancialTransaction> transactions,
    required DateTime month,
  }) {
    return FinanceMonthlySummary.fromTransactions(transactions: transactions, month: month).monthlySavings;
  }

  static double suggestedGoalContribution({
    required List<FinancialTransaction> transactions,
    required DateTime month,
    double allocationPercent = 50,
  }) {
    final savings = monthlySavings(transactions: transactions, month: month);
    if (savings <= 0) return 0;
    final normalizedPercent = allocationPercent.clamp(0, 100).toDouble();
    return savings * (normalizedPercent / 100);
  }
}
