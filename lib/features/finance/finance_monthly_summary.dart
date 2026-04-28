import '../../data/models/transaction_model.dart';
import 'finance_transaction_rules.dart';

class FinanceMonthlySummary {
  final DateTime month;
  final double expectedIncome;
  final double expectedExpense;
  final double paidIncome;
  final double paidExpense;
  final double savingsIncome;
  final double savingsExpense;
  final double previousPaidIncome;
  final double previousPaidExpense;
  final int overdueExpenses;
  final Map<int?, double> paidExpensesByCategory;
  final Map<int?, double> paidExpensesBySubcategory;

  const FinanceMonthlySummary({
    required this.month,
    required this.expectedIncome,
    required this.expectedExpense,
    required this.paidIncome,
    required this.paidExpense,
    required this.savingsIncome,
    required this.savingsExpense,
    required this.previousPaidIncome,
    required this.previousPaidExpense,
    required this.overdueExpenses,
    required this.paidExpensesByCategory,
    required this.paidExpensesBySubcategory,
  });

  double get expectedBalance => expectedIncome - expectedExpense;
  double get realizedResult => paidIncome - paidExpense;
  double get monthlySavings => savingsIncome - savingsExpense;
  double get previousResult => previousPaidIncome - previousPaidExpense;
  double get resultDifference => realizedResult - previousResult;
  double get expenseDifference => paidExpense - previousPaidExpense;
  double get paidExpenseRatio => expectedExpense <= 0 ? 0 : (paidExpense / expectedExpense).clamp(0.0, 1.0).toDouble();
  double get savingsRate => savingsIncome <= 0 ? 0 : (monthlySavings / savingsIncome) * 100;

  static FinanceMonthlySummary fromTransactions({
    required List<FinancialTransaction> transactions,
    required DateTime month,
    DateTime? now,
  }) {
    final previousMonth = DateTime(month.year, month.month - 1, 1);

    return FinanceMonthlySummary(
      month: month,
      expectedIncome: FinanceTransactionRules.expectedIncomeForMonth(transactions, month),
      expectedExpense: FinanceTransactionRules.expectedExpenseForMonth(transactions, month),
      paidIncome: FinanceTransactionRules.paidIncomeForMonth(transactions, month),
      paidExpense: FinanceTransactionRules.paidExpenseForMonth(transactions, month),
      savingsIncome: FinanceTransactionRules.paidIncomeForMonth(transactions, month, forMonthlySavings: true),
      savingsExpense: FinanceTransactionRules.paidExpenseForMonth(transactions, month, forMonthlySavings: true),
      previousPaidIncome: FinanceTransactionRules.paidIncomeForMonth(transactions, previousMonth),
      previousPaidExpense: FinanceTransactionRules.paidExpenseForMonth(transactions, previousMonth),
      overdueExpenses: FinanceTransactionRules.overdueExpensesForMonth(transactions, month, now: now),
      paidExpensesByCategory: FinanceTransactionRules.paidExpensesByCategoryForMonth(transactions, month),
      paidExpensesBySubcategory: FinanceTransactionRules.paidExpensesBySubcategoryForMonth(transactions, month),
    );
  }

  int? get topExpenseCategoryId {
    if (paidExpensesByCategory.isEmpty) return null;
    final entries = paidExpensesByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  double get topExpenseCategoryAmount {
    if (paidExpensesByCategory.isEmpty) return 0;
    final entries = paidExpensesByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.value;
  }

  int? get topExpenseSubcategoryId {
    if (paidExpensesBySubcategory.isEmpty) return null;
    final entries = paidExpensesBySubcategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  double get topExpenseSubcategoryAmount {
    if (paidExpensesBySubcategory.isEmpty) return 0;
    final entries = paidExpensesBySubcategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.value;
  }
}
