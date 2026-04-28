import '../../data/models/debt_model.dart';
import '../../data/models/transaction_model.dart';
import 'finance_transaction_rules.dart';

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
          .where((transaction) => transaction.debtId == debt.id && FinanceTransactionRules.countsInTotals(transaction))
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
        final expected = FinanceTransactionRules.expectedDate(transaction);
        final expectedInMonth = FinanceTransactionRules.isSameMonth(expected, selectedMonth);
        final paidInSelectedMonth = FinanceTransactionRules.isPaidInMonth(transaction, selectedMonth);

        if (expectedInMonth && transaction.status != 'paid') {
          dueInMonth += transaction.amount;
        }

        if (paidInSelectedMonth) {
          paidInMonth += transaction.amount + (transaction.discountAmount ?? 0);
        }

        if (FinanceTransactionRules.isOverdue(transaction, now: today)) {
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
}
