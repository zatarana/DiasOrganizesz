import '../../data/models/financial_category_model.dart';
import '../../data/models/transaction_model.dart';
import 'finance_transaction_rules.dart';

class FinanceCategoryReportItem {
  final int? categoryId;
  final String categoryName;
  final double amount;
  final int transactionCount;

  const FinanceCategoryReportItem({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.transactionCount,
  });

  double percentOf(double total) => total <= 0 ? 0 : (amount / total) * 100;
}

class FinanceCategoryReport {
  final DateTime month;
  final List<FinanceCategoryReportItem> items;

  const FinanceCategoryReport({required this.month, required this.items});

  double get total => items.fold<double>(0, (sum, item) => sum + item.amount);
  FinanceCategoryReportItem? get topItem => items.isEmpty ? null : items.first;

  static FinanceCategoryReport fromTransactions({
    required DateTime month,
    required List<FinancialTransaction> transactions,
    required List<FinancialCategory> categories,
  }) {
    final grouped = <String, _MutableCategoryReportItem>{};

    for (final transaction in transactions) {
      if (!FinanceTransactionRules.countsInReports(transaction)) continue;
      if (transaction.type != 'expense' || transaction.status != 'paid') continue;
      if (!FinanceTransactionRules.isPaidInMonth(transaction, month)) continue;

      final category = _categoryOf(categories, transaction.categoryId);
      final categoryName = category?.name ?? 'Sem categoria';
      final key = '${transaction.categoryId ?? 'none'}';

      grouped.update(
        key,
        (current) => current..add(transaction.amount),
        ifAbsent: () => _MutableCategoryReportItem(
          categoryId: transaction.categoryId,
          categoryName: categoryName,
          amount: transaction.amount,
          transactionCount: 1,
        ),
      );
    }

    final items = grouped.values
        .map((item) => FinanceCategoryReportItem(
              categoryId: item.categoryId,
              categoryName: item.categoryName,
              amount: item.amount,
              transactionCount: item.transactionCount,
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return FinanceCategoryReport(month: month, items: items);
  }

  static FinancialCategory? _categoryOf(List<FinancialCategory> categories, int? categoryId) {
    if (categoryId == null) return null;
    for (final category in categories) {
      if (category.id == categoryId) return category;
    }
    return null;
  }
}

class _MutableCategoryReportItem {
  final int? categoryId;
  final String categoryName;
  double amount;
  int transactionCount;

  _MutableCategoryReportItem({
    required this.categoryId,
    required this.categoryName,
    required this.amount,
    required this.transactionCount,
  });

  void add(double value) {
    amount += value;
    transactionCount++;
  }
}
