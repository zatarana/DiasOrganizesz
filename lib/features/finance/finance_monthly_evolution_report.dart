import '../../data/models/transaction_model.dart';
import 'finance_monthly_summary.dart';

class FinanceMonthlyEvolutionItem {
  final DateTime month;
  final double expectedIncome;
  final double expectedExpense;
  final double paidIncome;
  final double paidExpense;
  final double monthlySavings;

  const FinanceMonthlyEvolutionItem({
    required this.month,
    required this.expectedIncome,
    required this.expectedExpense,
    required this.paidIncome,
    required this.paidExpense,
    required this.monthlySavings,
  });

  double get expectedResult => expectedIncome - expectedExpense;
  double get realizedResult => paidIncome - paidExpense;
  double get expenseRealizationRatio => expectedExpense <= 0 ? 0 : (paidExpense / expectedExpense).clamp(0.0, 1.0).toDouble();
  double get incomeRealizationRatio => expectedIncome <= 0 ? 0 : (paidIncome / expectedIncome).clamp(0.0, 1.0).toDouble();
}

class FinanceMonthlyEvolutionReport {
  final DateTime startMonth;
  final DateTime endMonth;
  final List<FinanceMonthlyEvolutionItem> items;

  const FinanceMonthlyEvolutionReport({
    required this.startMonth,
    required this.endMonth,
    required this.items,
  });

  double get totalPaidIncome => items.fold<double>(0, (sum, item) => sum + item.paidIncome);
  double get totalPaidExpense => items.fold<double>(0, (sum, item) => sum + item.paidExpense);
  double get totalRealizedResult => items.fold<double>(0, (sum, item) => sum + item.realizedResult);
  double get totalSavings => items.fold<double>(0, (sum, item) => sum + item.monthlySavings);

  FinanceMonthlyEvolutionItem? get bestResultMonth {
    if (items.isEmpty) return null;
    final sorted = [...items]..sort((a, b) => b.realizedResult.compareTo(a.realizedResult));
    return sorted.first;
  }

  FinanceMonthlyEvolutionItem? get worstResultMonth {
    if (items.isEmpty) return null;
    final sorted = [...items]..sort((a, b) => a.realizedResult.compareTo(b.realizedResult));
    return sorted.first;
  }

  static FinanceMonthlyEvolutionReport fromTransactions({
    required List<FinancialTransaction> transactions,
    required DateTime startMonth,
    required DateTime endMonth,
  }) {
    final normalizedStart = DateTime(startMonth.year, startMonth.month, 1);
    final normalizedEnd = DateTime(endMonth.year, endMonth.month, 1);
    if (normalizedEnd.isBefore(normalizedStart)) {
      throw ArgumentError('O mês final não pode ser anterior ao mês inicial.');
    }

    final items = <FinanceMonthlyEvolutionItem>[];
    var current = normalizedStart;
    while (!current.isAfter(normalizedEnd)) {
      final summary = FinanceMonthlySummary.fromTransactions(transactions: transactions, month: current);
      items.add(FinanceMonthlyEvolutionItem(
        month: current,
        expectedIncome: summary.expectedIncome,
        expectedExpense: summary.expectedExpense,
        paidIncome: summary.paidIncome,
        paidExpense: summary.paidExpense,
        monthlySavings: summary.monthlySavings,
      ));
      current = DateTime(current.year, current.month + 1, 1);
    }

    return FinanceMonthlyEvolutionReport(
      startMonth: normalizedStart,
      endMonth: normalizedEnd,
      items: items,
    );
  }
}
