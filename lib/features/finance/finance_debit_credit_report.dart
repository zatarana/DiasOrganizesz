import '../../data/models/transaction_model.dart';
import 'finance_transaction_rules.dart';

class FinanceDebitCreditReport {
  final DateTime month;
  final double debitAmount;
  final double creditAmount;
  final double invoicePaymentAmount;
  final int debitCount;
  final int creditCount;
  final int invoicePaymentCount;

  const FinanceDebitCreditReport({
    required this.month,
    required this.debitAmount,
    required this.creditAmount,
    required this.invoicePaymentAmount,
    required this.debitCount,
    required this.creditCount,
    required this.invoicePaymentCount,
  });

  double get totalSpending => debitAmount + creditAmount;
  double get totalCashOut => debitAmount + invoicePaymentAmount;
  double get creditPercent => totalSpending <= 0 ? 0 : (creditAmount / totalSpending) * 100;
  double get debitPercent => totalSpending <= 0 ? 0 : (debitAmount / totalSpending) * 100;
  double get invoicePaymentPercentOfCashOut => totalCashOut <= 0 ? 0 : (invoicePaymentAmount / totalCashOut) * 100;

  bool get usesMoreCreditThanDebit => creditAmount > debitAmount;
  bool get hasInvoicePaymentRisk => invoicePaymentAmount > creditAmount && creditAmount > 0;

  static FinanceDebitCreditReport fromTransactions({
    required List<FinancialTransaction> transactions,
    required DateTime month,
  }) {
    double debitAmount = 0;
    double creditAmount = 0;
    double invoicePaymentAmount = 0;
    int debitCount = 0;
    int creditCount = 0;
    int invoicePaymentCount = 0;

    for (final transaction in transactions) {
      if (!FinanceTransactionRules.countsInTotals(transaction)) continue;
      if (transaction.type != 'expense') continue;
      if (!FinanceTransactionRules.belongsToMonth(transaction, month)) continue;

      if (_isInvoicePayment(transaction)) {
        if (FinanceTransactionRules.isPaidInMonth(transaction, month)) {
          invoicePaymentAmount += transaction.amount;
          invoicePaymentCount++;
        }
        continue;
      }

      if (_isCreditPurchase(transaction)) {
        creditAmount += transaction.amount;
        creditCount++;
      } else {
        debitAmount += transaction.amount;
        debitCount++;
      }
    }

    return FinanceDebitCreditReport(
      month: DateTime(month.year, month.month, 1),
      debitAmount: debitAmount,
      creditAmount: creditAmount,
      invoicePaymentAmount: invoicePaymentAmount,
      debitCount: debitCount,
      creditCount: creditCount,
      invoicePaymentCount: invoicePaymentCount,
    );
  }

  static bool _isCreditPurchase(FinancialTransaction transaction) {
    if (transaction.creditCardId != null || transaction.creditCardInvoiceId != null) return true;
    final method = transaction.paymentMethod?.toLowerCase() ?? '';
    return method.contains('cartão de crédito') || method.contains('cartao de credito') || method == 'crédito' || method == 'credito';
  }

  static bool _isInvoicePayment(FinancialTransaction transaction) {
    if (transaction.creditCardPaymentInvoiceId != null) return true;
    final method = transaction.paymentMethod?.toLowerCase() ?? '';
    return method.contains('pagamento de fatura');
  }
}
