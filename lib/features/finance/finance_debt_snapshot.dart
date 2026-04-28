import '../../data/models/debt_model.dart';
import '../../data/models/transaction_model.dart';

class FinanceDebtSnapshot {
  final double totalDebt;
  final double totalRemaining;
  final double totalPaidOrAbated;
  final double dueInMonth;
  final double paidInMonth;
  final double overdueAmount;
  final int openDebtCount;
  final int overdueInstallments;
  final DateTime? nextDueDate;

  const FinanceDebtSnapshot({
    required this.totalDebt,
    required this.totalRemaining,
    required this.totalPaidOrAbated,
    required this.dueInMonth,
    required this.paidInMonth,
    required this.overdueAmount,
    required this.openDebtCount,
    required this.overdueInstallments,
    required this.nextDueDate,
  });

  bool get hasOpenDebts => openDebtCount > 0;
  bool get hasOverdueInstallments => overdueInstallments > 0 || overdueAmount > 0;

  static FinanceDebtSnapshot from({
    required List<Debt> debts,
    required List<FinancialTransaction> transactions,
    required DateTime selectedMonth,
    DateTime? now,
  }) {
    final todaySource = now ?? DateTime.now();
    final today = DateTime(todaySource.year, todaySource.month, todaySource.day);

    double totalDebt = 0;
    double totalRemaining = 0;
    double totalPaidOrAbated = 0;
    double dueInMonth = 0;
    double paidInMonth = 0;
    double overdueAmount = 0;
    int openDebtCount = 0;
    int overdueInstallments = 0;
    DateTime? nextDueDate;

    for (final debt in debts) {
      if (debt.status == 'canceled') continue;

      final linkedTransactions = transactions
          .where((transaction) => transaction.debtId == debt.id && transaction.status != 'canceled')
          .toList();

      final paidOrAbatedForDebt = linkedTransactions
          .where((transaction) => transaction.status == 'paid')
          .fold<double>(0, (sum, transaction) => sum + transaction.amount + (transaction.discountAmount ?? 0));

      final remainingForDebt = (debt.totalAmount - paidOrAbatedForDebt).clamp(0, double.infinity).toDouble();

      totalDebt += debt.totalAmount;
      totalRemaining += remainingForDebt;
      totalPaidOrAbated += paidOrAbatedForDebt;

      if (remainingForDebt > 0 && debt.status != 'paid') {
        openDebtCount++;
      }

      for (final transaction in linkedTransactions) {
        final expected = _expectedDate(transaction);
        final paid = _paidDate(transaction);
        final expectedInMonth = _isSameMonth(expected, selectedMonth);
        final paidInSelectedMonth = transaction.status == 'paid' &&
            (_isSameMonth(paid, selectedMonth) || (paid == null && expectedInMonth));

        if (expectedInMonth && transaction.status != 'paid') {
          dueInMonth += transaction.amount;
        }

        if (paidInSelectedMonth) {
          paidInMonth += transaction.amount + (transaction.discountAmount ?? 0);
        }

        if (_isOverdueDebtInstallment(transaction, today)) {
          overdueAmount += transaction.amount;
          overdueInstallments++;
        }

        if (transaction.status != 'paid' && expected != null) {
          if (nextDueDate == null || expected.isBefore(nextDueDate)) {
            nextDueDate = expected;
          }
        }
      }
    }

    return FinanceDebtSnapshot(
      totalDebt: totalDebt,
      totalRemaining: totalRemaining,
      totalPaidOrAbated: totalPaidOrAbated,
      dueInMonth: dueInMonth,
      paidInMonth: paidInMonth,
      overdueAmount: overdueAmount,
      openDebtCount: openDebtCount,
      overdueInstallments: overdueInstallments,
      nextDueDate: nextDueDate,
    );
  }

  static DateTime? _expectedDate(FinancialTransaction transaction) {
    return DateTime.tryParse(transaction.dueDate ?? transaction.transactionDate);
  }

  static DateTime? _paidDate(FinancialTransaction transaction) {
    return transaction.paidDate == null ? null : DateTime.tryParse(transaction.paidDate!);
  }

  static bool _isSameMonth(DateTime? date, DateTime month) {
    return date != null && date.month == month.month && date.year == month.year;
  }

  static bool _isOverdueDebtInstallment(FinancialTransaction transaction, DateTime today) {
    if (transaction.status == 'paid' || transaction.status == 'canceled') return false;
    if (transaction.status == 'overdue') return true;

    final expected = _expectedDate(transaction);
    if (expected == null) return false;

    final due = DateTime(expected.year, expected.month, expected.day);
    return due.isBefore(today);
  }
}
