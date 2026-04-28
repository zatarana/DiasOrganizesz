import '../../data/models/budget_model.dart';
import '../../data/models/transaction_model.dart';
import 'finance_transaction_rules.dart';

class FinanceBudgetUsage {
  final Budget budget;
  final double plannedAmount;
  final double paidAmount;

  const FinanceBudgetUsage({
    required this.budget,
    required this.plannedAmount,
    required this.paidAmount,
  });

  double get availableAmount => budget.limitAmount - plannedAmount;
  double get paidAvailableAmount => budget.limitAmount - paidAmount;
  bool get isOverPlanned => plannedAmount > budget.limitAmount;
  bool get isOverPaid => paidAmount > budget.limitAmount;
  double get plannedRatio => budget.limitAmount <= 0 ? 0 : (plannedAmount / budget.limitAmount).clamp(0.0, 1.0).toDouble();
  double get paidRatio => budget.limitAmount <= 0 ? 0 : (paidAmount / budget.limitAmount).clamp(0.0, 1.0).toDouble();
}

class FinanceBudgetRules {
  const FinanceBudgetRules._();

  static String transactionMonth(FinancialTransaction transaction) {
    final date = FinanceTransactionRules.expectedDate(transaction);
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
  }

  static bool matchesBudget(FinancialTransaction transaction, Budget budget) {
    if (transaction.status == 'canceled' || transaction.type != 'expense') return false;
    if (transaction.ignoreInTotals) return false;
    if (transactionMonth(transaction) != budget.month) return false;
    if (budget.categoryId != null && transaction.categoryId != budget.categoryId) return false;
    if (budget.subcategoryId != null && transaction.subcategoryId != budget.subcategoryId) return false;
    return true;
  }

  static FinanceBudgetUsage usageFor(Budget budget, List<FinancialTransaction> transactions) {
    final matched = transactions.where((transaction) => matchesBudget(transaction, budget)).toList();
    final planned = matched.fold<double>(0, (sum, transaction) => sum + transaction.amount);
    final paid = matched.where((transaction) => transaction.status == 'paid').fold<double>(0, (sum, transaction) => sum + transaction.amount);
    return FinanceBudgetUsage(budget: budget, plannedAmount: planned, paidAmount: paid);
  }

  static List<FinanceBudgetUsage> usageForAll(List<Budget> budgets, List<FinancialTransaction> transactions) {
    return budgets.where((budget) => !budget.isArchived).map((budget) => usageFor(budget, transactions)).toList();
  }
}
