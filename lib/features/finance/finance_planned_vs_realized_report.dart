import '../../data/models/transaction_model.dart';
import 'finance_monthly_summary.dart';

class FinancePlannedVsRealizedReport {
  final DateTime month;
  final double expectedIncome;
  final double realizedIncome;
  final double expectedExpense;
  final double realizedExpense;

  const FinancePlannedVsRealizedReport({
    required this.month,
    required this.expectedIncome,
    required this.realizedIncome,
    required this.expectedExpense,
    required this.realizedExpense,
  });

  double get expectedResult => expectedIncome - expectedExpense;
  double get realizedResult => realizedIncome - realizedExpense;
  double get incomeDifference => realizedIncome - expectedIncome;
  double get expenseDifference => realizedExpense - expectedExpense;
  double get resultDifference => realizedResult - expectedResult;

  double get incomeRealizationRatio => expectedIncome <= 0 ? 0 : (realizedIncome / expectedIncome).clamp(0.0, 1.0).toDouble();
  double get expenseRealizationRatio => expectedExpense <= 0 ? 0 : (realizedExpense / expectedExpense).clamp(0.0, 1.0).toDouble();

  bool get hasPositiveExpectedResult => expectedResult >= 0;
  bool get hasPositiveRealizedResult => realizedResult >= 0;
  bool get realizedBetterThanExpected => realizedResult >= expectedResult;

  static FinancePlannedVsRealizedReport fromTransactions({
    required DateTime month,
    required List<FinancialTransaction> transactions,
  }) {
    final summary = FinanceMonthlySummary.fromTransactions(transactions: transactions, month: month);
    return FinancePlannedVsRealizedReport(
      month: month,
      expectedIncome: summary.expectedIncome,
      realizedIncome: summary.paidIncome,
      expectedExpense: summary.expectedExpense,
      realizedExpense: summary.paidExpense,
    );
  }
}
