import '../../data/models/transaction_model.dart';

class FinanceTransactionRules {
  const FinanceTransactionRules._();

  static DateTime? expectedDate(FinancialTransaction transaction) {
    return DateTime.tryParse(transaction.dueDate ?? transaction.transactionDate);
  }

  static DateTime? paidDate(FinancialTransaction transaction) {
    return transaction.paidDate == null ? null : DateTime.tryParse(transaction.paidDate!);
  }

  static bool isSameMonth(DateTime? date, DateTime month) {
    return date != null && date.year == month.year && date.month == month.month;
  }

  static bool belongsToMonth(FinancialTransaction transaction, DateTime month) {
    return isSameMonth(expectedDate(transaction), month) || isSameMonth(paidDate(transaction), month);
  }

  static bool countsInTotals(FinancialTransaction transaction) {
    return transaction.status != 'canceled' && !transaction.ignoreInTotals;
  }

  static bool countsInReports(FinancialTransaction transaction) {
    return transaction.status != 'canceled' && !transaction.ignoreInReports && !transaction.ignoreInTotals;
  }

  static bool countsInMonthlySavings(FinancialTransaction transaction) {
    return transaction.status != 'canceled' && !transaction.ignoreInMonthlySavings && !transaction.ignoreInTotals;
  }

  static bool isPaidInMonth(FinancialTransaction transaction, DateTime month) {
    if (transaction.status != 'paid') return false;
    final expected = expectedDate(transaction);
    final paid = paidDate(transaction);
    return isSameMonth(paid, month) || (paid == null && isSameMonth(expected, month));
  }

  static bool isExpectedInMonth(FinancialTransaction transaction, DateTime month) {
    return isSameMonth(expectedDate(transaction), month);
  }

  static bool isOverdue(FinancialTransaction transaction, {DateTime? now}) {
    if (transaction.status == 'paid' || transaction.status == 'canceled') return false;
    if (transaction.status == 'overdue') return true;

    final expected = expectedDate(transaction);
    if (expected == null) return false;

    final todaySource = now ?? DateTime.now();
    final today = DateTime(todaySource.year, todaySource.month, todaySource.day);
    final due = DateTime(expected.year, expected.month, expected.day);
    return due.isBefore(today);
  }

  static double signedAmount(FinancialTransaction transaction) {
    return transaction.type == 'income' ? transaction.amount : -transaction.amount;
  }

  static double expectedIncomeForMonth(List<FinancialTransaction> transactions, DateTime month) {
    return transactions
        .where((transaction) => countsInTotals(transaction) && transaction.type == 'income' && isExpectedInMonth(transaction, month))
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
  }

  static double expectedExpenseForMonth(List<FinancialTransaction> transactions, DateTime month) {
    return transactions
        .where((transaction) => countsInTotals(transaction) && transaction.type == 'expense' && isExpectedInMonth(transaction, month))
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
  }

  static double paidIncomeForMonth(List<FinancialTransaction> transactions, DateTime month, {bool forMonthlySavings = false}) {
    return transactions
        .where((transaction) {
          final counts = forMonthlySavings ? countsInMonthlySavings(transaction) : countsInTotals(transaction);
          return counts && transaction.type == 'income' && isPaidInMonth(transaction, month);
        })
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
  }

  static double paidExpenseForMonth(List<FinancialTransaction> transactions, DateTime month, {bool forMonthlySavings = false}) {
    return transactions
        .where((transaction) {
          final counts = forMonthlySavings ? countsInMonthlySavings(transaction) : countsInTotals(transaction);
          return counts && transaction.type == 'expense' && isPaidInMonth(transaction, month);
        })
        .fold<double>(0, (sum, transaction) => sum + transaction.amount);
  }

  static Map<int?, double> paidExpensesByCategoryForMonth(List<FinancialTransaction> transactions, DateTime month) {
    final result = <int?, double>{};
    for (final transaction in transactions) {
      if (!countsInReports(transaction)) continue;
      if (transaction.status != 'paid' || transaction.type != 'expense') continue;
      if (!isPaidInMonth(transaction, month)) continue;
      result[transaction.categoryId] = (result[transaction.categoryId] ?? 0) + transaction.amount;
    }
    return result;
  }

  static Map<int?, double> paidExpensesBySubcategoryForMonth(List<FinancialTransaction> transactions, DateTime month) {
    final result = <int?, double>{};
    for (final transaction in transactions) {
      if (!countsInReports(transaction)) continue;
      if (transaction.status != 'paid' || transaction.type != 'expense') continue;
      if (!isPaidInMonth(transaction, month)) continue;
      result[transaction.subcategoryId] = (result[transaction.subcategoryId] ?? 0) + transaction.amount;
    }
    return result;
  }

  static int overdueExpensesForMonth(List<FinancialTransaction> transactions, DateTime month, {DateTime? now}) {
    return transactions
        .where((transaction) => countsInTotals(transaction) && transaction.type == 'expense' && isExpectedInMonth(transaction, month) && isOverdue(transaction, now: now))
        .length;
  }

  static bool matchesText(
    FinancialTransaction transaction,
    String query, {
    String? categoryName,
    String? subcategoryName,
    String? debtName,
    String? creditorName,
  }) {
    if (query.trim().isEmpty) return true;
    final q = query.trim().toLowerCase();
    final fields = [
      transaction.title,
      transaction.description ?? '',
      transaction.notes ?? '',
      transaction.tags ?? '',
      transaction.paymentMethod ?? '',
      categoryName ?? '',
      subcategoryName ?? '',
      debtName ?? '',
      creditorName ?? '',
      transaction.installmentNumber == null ? '' : 'parcela ${transaction.installmentNumber}/${transaction.totalInstallments ?? ''}',
    ];
    return fields.any((field) => field.toLowerCase().contains(q));
  }

  static String visibilityBadges(FinancialTransaction transaction) {
    final badges = <String>[];
    if (transaction.ignoreInTotals) badges.add('ignorada nos totais');
    if (transaction.ignoreInReports) badges.add('fora dos relatórios');
    if (transaction.ignoreInMonthlySavings) badges.add('fora da economia mensal');
    return badges.join(' • ');
  }
}
