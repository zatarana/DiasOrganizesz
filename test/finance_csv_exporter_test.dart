import 'package:diasorganize/data/models/transaction_model.dart';
import 'package:diasorganize/features/finance/finance_csv_exporter.dart';
import 'package:diasorganize/features/finance/finance_debit_credit_report.dart';
import 'package:diasorganize/features/finance/finance_monthly_evolution_report.dart';
import 'package:flutter_test/flutter_test.dart';

FinancialTransaction tx({
  required String title,
  required double amount,
  String type = 'expense',
  String date = '2026-04-10T00:00:00.000',
  String status = 'paid',
  String? description,
  String? notes,
  String? paymentMethod,
  int? creditCardId,
  int? creditCardInvoiceId,
  int? creditCardPaymentInvoiceId,
}) {
  return FinancialTransaction(
    id: 1,
    title: title,
    description: description,
    amount: amount,
    type: type,
    transactionDate: date,
    paidDate: status == 'paid' ? date : null,
    paymentMethod: paymentMethod,
    status: status,
    notes: notes,
    creditCardId: creditCardId,
    creditCardInvoiceId: creditCardInvoiceId,
    creditCardPaymentInvoiceId: creditCardPaymentInvoiceId,
    createdAt: date,
    updatedAt: date,
  );
}

void main() {
  group('FinanceCsvExporter', () {
    test('transactionsToCsv exporta cabeçalho e campos principais', () {
      final csv = FinanceCsvExporter.transactionsToCsv([
        tx(
          title: 'Mercado, feira',
          amount: 123.45,
          description: 'Compra com vírgula',
          notes: 'Observação com "aspas"',
          paymentMethod: 'cartão de crédito',
          creditCardId: 2,
          creditCardInvoiceId: 3,
        ),
      ]);

      expect(csv, contains('id,titulo,descricao,valor,tipo'));
      expect(csv, contains('"Mercado, feira"'));
      expect(csv, contains('"Observação com ""aspas"""'));
      expect(csv, contains('123.45'));
      expect(csv, contains('cartão de crédito'));
      expect(csv, contains(',2,3,'));
    });

    test('monthlyEvolutionToCsv exporta evolução mensal', () {
      final report = FinanceMonthlyEvolutionReport.fromTransactions(
        startMonth: DateTime(2026, 4, 1),
        endMonth: DateTime(2026, 4, 1),
        transactions: [
          tx(title: 'Salário', amount: 3000, type: 'income'),
          tx(title: 'Aluguel', amount: 1000),
        ],
      );

      final csv = FinanceCsvExporter.monthlyEvolutionToCsv(report);

      expect(csv, contains('mes,receita_prevista,despesa_prevista,resultado_previsto'));
      expect(csv, contains('2026-04'));
      expect(csv, contains('3000.00'));
      expect(csv, contains('1000.00'));
      expect(csv, contains('2000.00'));
    });

    test('debitCreditToCsv exporta visão débito versus crédito', () {
      final report = FinanceDebitCreditReport.fromTransactions(
        month: DateTime(2026, 4, 1),
        transactions: [
          tx(title: 'Débito', amount: 100, paymentMethod: 'débito'),
          tx(title: 'Crédito', amount: 300, creditCardId: 1, creditCardInvoiceId: 1),
          tx(title: 'Fatura', amount: 300, creditCardPaymentInvoiceId: 1),
        ],
      );

      final csv = FinanceCsvExporter.debitCreditToCsv(report);

      expect(csv, contains('campo,valor'));
      expect(csv, contains('compras_debito_dinheiro_pix,100.00'));
      expect(csv, contains('compras_credito,300.00'));
      expect(csv, contains('pagamentos_fatura,300.00'));
      expect(csv, contains('percentual_credito,75.00'));
    });
  });
}
