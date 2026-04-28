import '../../data/models/debt_model.dart';
import '../../data/models/transaction_model.dart';

class DebtFinancialSummary {
  final Debt debt;
  final List<FinancialTransaction> installments;
  final double originalAmount;
  final double paidMoney;
  final double discounts;
  final double totalAbated;
  final double remaining;
  final double progress;
  final double overdueAmount;
  final double dueInMonth;
  final double paidInMonth;
  final int paidInstallments;
  final int pendingInstallments;
  final int overdueInstallments;
  final DateTime? nextDueDate;

  const DebtFinancialSummary({
    required this.debt,
    required this.installments,
    required this.originalAmount,
    required this.paidMoney,
    required this.discounts,
    required this.totalAbated,
    required this.remaining,
    required this.progress,
    required this.overdueAmount,
    required this.dueInMonth,
    required this.paidInMonth,
    required this.paidInstallments,
    required this.pendingInstallments,
    required this.overdueInstallments,
    required this.nextDueDate,
  });

  bool get isPaidByValue => remaining <= 0.01;
  bool get hasOverdue => overdueInstallments > 0 || overdueAmount > 0;
  bool get hasInstallments => installments.isNotEmpty;
  double get moneyDifferenceAgainstOriginal => paidMoney - originalAmount;

  static DebtFinancialSummary from({
    required Debt debt,
    required List<FinancialTransaction> transactions,
    required DateTime selectedMonth,
    DateTime? now,
  }) {
    final todaySource = now ?? DateTime.now();
    final today = DateTime(todaySource.year, todaySource.month, todaySource.day);

    final linked = transactions
        .where((transaction) => transaction.debtId == debt.id && transaction.status != 'canceled')
        .toList()
      ..sort((a, b) {
        if (a.installmentNumber != null && b.installmentNumber != null) {
          return a.installmentNumber!.compareTo(b.installmentNumber!);
        }
        final ad = _expectedDate(a) ?? DateTime(2100);
        final bd = _expectedDate(b) ?? DateTime(2100);
        return ad.compareTo(bd);
      });

    double paidMoney = 0;
    double discounts = 0;
    double overdueAmount = 0;
    double dueInMonth = 0;
    double paidInMonth = 0;
    int paidInstallments = 0;
    int pendingInstallments = 0;
    int overdueInstallments = 0;
    DateTime? nextDueDate;

    for (final installment in linked) {
      final expected = _expectedDate(installment);
      final paid = _paidDate(installment);
      final expectedInMonth = _isSameMonth(expected, selectedMonth);
      final paidInSelectedMonth = installment.status == 'paid' &&
          (_isSameMonth(paid, selectedMonth) || (paid == null && expectedInMonth));

      if (installment.status == 'paid') {
        paidInstallments++;
        paidMoney += installment.amount;
        discounts += installment.discountAmount ?? 0;
      } else {
        pendingInstallments++;
        if (expectedInMonth) dueInMonth += installment.amount;
      }

      if (paidInSelectedMonth) {
        paidInMonth += installment.amount + (installment.discountAmount ?? 0);
      }

      if (_isOverdue(installment, today)) {
        overdueInstallments++;
        overdueAmount += installment.amount;
      }

      if (installment.status != 'paid' && expected != null) {
        if (nextDueDate == null || expected.isBefore(nextDueDate)) {
          nextDueDate = expected;
        }
      }
    }

    final totalAbated = paidMoney + discounts;
    final remaining = (debt.totalAmount - totalAbated).clamp(0, double.infinity).toDouble();
    final progress = debt.totalAmount > 0 ? (totalAbated / debt.totalAmount).clamp(0.0, 1.0).toDouble() : 0.0;

    return DebtFinancialSummary(
      debt: debt,
      installments: linked,
      originalAmount: debt.totalAmount,
      paidMoney: paidMoney,
      discounts: discounts,
      totalAbated: totalAbated,
      remaining: remaining,
      progress: progress,
      overdueAmount: overdueAmount,
      dueInMonth: dueInMonth,
      paidInMonth: paidInMonth,
      paidInstallments: paidInstallments,
      pendingInstallments: pendingInstallments,
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
    return date != null && date.year == month.year && date.month == month.month;
  }

  static bool _isOverdue(FinancialTransaction transaction, DateTime today) {
    if (transaction.status == 'paid' || transaction.status == 'canceled') return false;
    if (transaction.status == 'overdue') return true;
    final expected = _expectedDate(transaction);
    if (expected == null) return false;
    final due = DateTime(expected.year, expected.month, expected.day);
    return due.isBefore(today);
  }
}
