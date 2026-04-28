import '../../data/models/debt_model.dart';
import '../../data/models/financial_category_model.dart';
import '../../data/models/transaction_model.dart';
import 'finance_monthly_summary.dart';
import 'finance_transaction_rules.dart';

class FinanceScreenData {
  final DateTime selectedMonth;
  final FinanceMonthlySummary summary;
  final List<FinancialTransaction> filteredTransactions;
  final FinancialCategory? topExpenseCategory;

  const FinanceScreenData({
    required this.selectedMonth,
    required this.summary,
    required this.filteredTransactions,
    required this.topExpenseCategory,
  });

  static FinanceScreenData build({
    required DateTime selectedMonth,
    required List<FinancialTransaction> transactions,
    required List<FinancialCategory> categories,
    required List<Debt> debts,
    required String filterType,
    required String filterStatus,
    required int? filterCategory,
    required String searchQuery,
  }) {
    final summary = FinanceMonthlySummary.fromTransactions(
      transactions: transactions,
      month: selectedMonth,
    );

    final filtered = transactions.where((transaction) {
      if (transaction.status == 'canceled' && filterStatus != 'all') return false;
      if (!FinanceTransactionRules.belongsToMonth(transaction, selectedMonth)) return false;
      if (filterType == 'income' && transaction.type != 'income') return false;
      if (filterType == 'expense' && transaction.type != 'expense') return false;
      if (filterType == 'debt' && transaction.debtId == null) return false;
      if (filterStatus == 'paid' && transaction.status != 'paid') return false;
      if (filterStatus == 'pending' && transaction.status != 'pending') return false;
      if (filterStatus == 'overdue' && transaction.status != 'overdue') return false;
      if (filterCategory != null && transaction.categoryId != filterCategory) return false;

      final category = _categoryOf(categories, transaction.categoryId);
      final debt = _debtOf(debts, transaction.debtId);
      return FinanceTransactionRules.matchesText(
        transaction,
        searchQuery,
        categoryName: category?.name,
        debtName: debt?.name,
        creditorName: debt?.creditorName,
      );
    }).toList()
      ..sort((a, b) {
        final ad = FinanceTransactionRules.expectedDate(a) ?? DateTime(2100);
        final bd = FinanceTransactionRules.expectedDate(b) ?? DateTime(2100);
        return ad.compareTo(bd);
      });

    return FinanceScreenData(
      selectedMonth: selectedMonth,
      summary: summary,
      filteredTransactions: filtered,
      topExpenseCategory: _categoryOf(categories, summary.topExpenseCategoryId),
    );
  }

  static FinancialCategory? _categoryOf(List<FinancialCategory> categories, int? categoryId) {
    if (categoryId == null) return null;
    for (final category in categories) {
      if (category.id == categoryId) return category;
    }
    return null;
  }

  static Debt? _debtOf(List<Debt> debts, int? debtId) {
    if (debtId == null) return null;
    for (final debt in debts) {
      if (debt.id == debtId) return debt;
    }
    return null;
  }
}
