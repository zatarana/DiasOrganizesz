import '../../data/models/financial_category_model.dart';
import '../../data/models/financial_subcategory_model.dart';
import '../../data/models/transaction_model.dart';
import 'finance_transaction_rules.dart';

class FinanceSubcategoryReportItem {
  final int? categoryId;
  final String categoryName;
  final int? subcategoryId;
  final String subcategoryName;
  final double amount;
  final int transactionCount;

  const FinanceSubcategoryReportItem({
    required this.categoryId,
    required this.categoryName,
    required this.subcategoryId,
    required this.subcategoryName,
    required this.amount,
    required this.transactionCount,
  });

  double percentOf(double total) => total <= 0 ? 0 : (amount / total) * 100;

  String get fullName => '$categoryName / $subcategoryName';
}

class FinanceSubcategoryReport {
  final DateTime month;
  final List<FinanceSubcategoryReportItem> items;

  const FinanceSubcategoryReport({required this.month, required this.items});

  double get total => items.fold<double>(0, (sum, item) => sum + item.amount);

  FinanceSubcategoryReportItem? get topItem => items.isEmpty ? null : items.first;

  static FinanceSubcategoryReport fromTransactions({
    required DateTime month,
    required List<FinancialTransaction> transactions,
    required List<FinancialCategory> categories,
    required List<FinancialSubcategory> subcategories,
  }) {
    final grouped = <String, _MutableSubcategoryReportItem>{};

    for (final transaction in transactions) {
      if (!FinanceTransactionRules.countsInReports(transaction)) continue;
      if (transaction.type != 'expense' || transaction.status != 'paid') continue;
      if (!FinanceTransactionRules.isPaidInMonth(transaction, month)) continue;

      final category = _categoryOf(categories, transaction.categoryId);
      final subcategory = _subcategoryOf(subcategories, transaction.subcategoryId);
      final categoryName = category?.name ?? 'Sem categoria';
      final subcategoryName = subcategory?.name ?? 'Sem subcategoria';
      final key = '${transaction.categoryId ?? 'none'}:${transaction.subcategoryId ?? 'none'}';

      grouped.update(
        key,
        (current) => current..add(transaction.amount),
        ifAbsent: () => _MutableSubcategoryReportItem(
          categoryId: transaction.categoryId,
          categoryName: categoryName,
          subcategoryId: transaction.subcategoryId,
          subcategoryName: subcategoryName,
          amount: transaction.amount,
          transactionCount: 1,
        ),
      );
    }

    final items = grouped.values
        .map((item) => FinanceSubcategoryReportItem(
              categoryId: item.categoryId,
              categoryName: item.categoryName,
              subcategoryId: item.subcategoryId,
              subcategoryName: item.subcategoryName,
              amount: item.amount,
              transactionCount: item.transactionCount,
            ))
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return FinanceSubcategoryReport(month: month, items: items);
  }

  static FinancialCategory? _categoryOf(List<FinancialCategory> categories, int? categoryId) {
    if (categoryId == null) return null;
    for (final category in categories) {
      if (category.id == categoryId) return category;
    }
    return null;
  }

  static FinancialSubcategory? _subcategoryOf(List<FinancialSubcategory> subcategories, int? subcategoryId) {
    if (subcategoryId == null) return null;
    for (final subcategory in subcategories) {
      if (subcategory.id == subcategoryId) return subcategory;
    }
    return null;
  }
}

class _MutableSubcategoryReportItem {
  final int? categoryId;
  final String categoryName;
  final int? subcategoryId;
  final String subcategoryName;
  double amount;
  int transactionCount;

  _MutableSubcategoryReportItem({
    required this.categoryId,
    required this.categoryName,
    required this.subcategoryId,
    required this.subcategoryName,
    required this.amount,
    required this.transactionCount,
  });

  void add(double value) {
    amount += value;
    transactionCount++;
  }
}
