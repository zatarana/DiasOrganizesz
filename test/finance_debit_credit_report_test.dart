import 'package:diasorganize/data/models/transaction_model.dart';
import 'package:diasorganize/features/finance/finance_debit_credit_report.dart';
import 'package:flutter_test/flutter_test.dart';

FinancialTransaction tx({
  required String title,
  required double amount,
  String date = '2026-04-10T00:00:00.000',
  String status = 'paid',
  String? paymentMethod,
  int? creditCardId,
  int? creditCardInvoiceId,
  int? creditCardPaymentInvoiceId,
  bool ignoreInTotals = false,
}) {
  return FinancialTransaction(
    title: title,
    amount: amount,
    type: 'expense',
    transactionDate: date,
    paidDate: status == 'paid' ? date : null,
    paymentMethod: paymentMethod,
    status: status,
    creditCardId: creditCardId,
    creditCardInvoiceId: creditCardInvoiceId,
    creditCardPaymentInvoiceId: creditCardPaymentInvoiceId,
    ignoreInTotals: ignoreInTotals,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  group('FinanceDebitCreditReport', () {
    test('separa compras em débito e crédito', () {
      final report = FinanceDebitCreditReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(title: 'Mercado débito', amount: 100, paymentMethod: 'débito'),
          tx(title: 'Farmácia crédito', amount: 200, creditCardId: 1, creditCardInvoiceId: 2),
          tx(title: 'Online crédito', amount: 50, paymentMethod: 'cartão de crédito'),
        ],
      );

      expect(report.debitAmount, 100);
      expect(report.creditAmount, 250);
      expect(report.totalSpending, 350);
      expect(report.debitCount, 1);
      expect(report.creditCount, 2);
    });

    test('pagamento de fatura entra como saída de caixa sem duplicar gasto', () {
      final report = FinanceDebitCreditReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(title: 'Compra crédito', amount: 300, creditCardId: 1, creditCardInvoiceId: 2),
          tx(title: 'Pagamento fatura', amount: 300, creditCardPaymentInvoiceId: 2, paymentMethod: 'pagamento de fatura'),
          tx(title: 'Débito normal', amount: 100, paymentMethod: 'débito'),
        ],
      );

      expect(report.creditAmount, 300);
      expect(report.debitAmount, 100);
      expect(report.invoicePaymentAmount, 300);
      expect(report.totalSpending, 400);
      expect(report.totalCashOut, 400);
      expect(report.invoicePaymentCount, 1);
    });

    test('calcula percentuais de uso', () {
      final report = FinanceDebitCreditReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(title: 'Débito', amount: 100),
          tx(title: 'Crédito', amount: 300, creditCardId: 1, creditCardInvoiceId: 1),
          tx(title: 'Pagamento fatura', amount: 300, creditCardPaymentInvoiceId: 1),
        ],
      );

      expect(report.debitPercent, 25);
      expect(report.creditPercent, 75);
      expect(report.invoicePaymentPercentOfCashOut, 75);
      expect(report.usesMoreCreditThanDebit, true);
    });

    test('ignora canceladas, ignoradas nos totais e meses diferentes', () {
      final report = FinanceDebitCreditReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(title: 'Débito válido', amount: 100),
          tx(title: 'Cancelada', amount: 999, status: 'canceled'),
          tx(title: 'Ignorada', amount: 999, ignoreInTotals: true),
          tx(title: 'Outro mês', amount: 999, date: '2026-05-01T00:00:00.000'),
        ],
      );

      expect(report.debitAmount, 100);
      expect(report.creditAmount, 0);
      expect(report.invoicePaymentAmount, 0);
    });

    test('detecta risco quando pagamento de fatura supera compras de crédito do mês', () {
      final report = FinanceDebitCreditReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(title: 'Compra crédito', amount: 100, creditCardId: 1, creditCardInvoiceId: 1),
          tx(title: 'Pagamento fatura', amount: 300, creditCardPaymentInvoiceId: 1),
        ],
      );

      expect(report.hasInvoicePaymentRisk, true);
    });
  });
}
