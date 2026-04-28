import '../../data/models/transaction_model.dart';
import 'finance_debit_credit_report.dart';
import 'finance_monthly_evolution_report.dart';

class FinanceCsvExporter {
  const FinanceCsvExporter._();

  static String transactionsToCsv(List<FinancialTransaction> transactions) {
    final rows = <List<Object?>>[
      [
        'id',
        'titulo',
        'descricao',
        'valor',
        'tipo',
        'data_lancamento',
        'vencimento',
        'data_pagamento',
        'categoria_id',
        'subcategoria_id',
        'conta_id',
        'metodo_pagamento',
        'status',
        'fixa',
        'recorrencia',
        'tags',
        'ignorada_totais',
        'fora_relatorios',
        'fora_economia_mensal',
        'divida_id',
        'cartao_id',
        'fatura_id',
        'pagamento_fatura_id',
        'parcela',
        'total_parcelas',
        'desconto',
        'observacoes',
      ],
      ...transactions.map((transaction) => [
            transaction.id,
            transaction.title,
            transaction.description,
            _money(transaction.amount),
            transaction.type,
            transaction.transactionDate,
            transaction.dueDate,
            transaction.paidDate,
            transaction.categoryId,
            transaction.subcategoryId,
            transaction.accountId,
            transaction.paymentMethod,
            transaction.status,
            transaction.isFixed ? 'sim' : 'nao',
            transaction.recurrenceType,
            transaction.tags,
            transaction.ignoreInTotals ? 'sim' : 'nao',
            transaction.ignoreInReports ? 'sim' : 'nao',
            transaction.ignoreInMonthlySavings ? 'sim' : 'nao',
            transaction.debtId,
            transaction.creditCardId,
            transaction.creditCardInvoiceId,
            transaction.creditCardPaymentInvoiceId,
            transaction.installmentNumber,
            transaction.totalInstallments,
            transaction.discountAmount == null ? null : _money(transaction.discountAmount!),
            transaction.notes,
          ]),
    ];
    return _toCsv(rows);
  }

  static String monthlyEvolutionToCsv(FinanceMonthlyEvolutionReport report) {
    final rows = <List<Object?>>[
      [
        'mes',
        'receita_prevista',
        'despesa_prevista',
        'resultado_previsto',
        'receita_realizada',
        'despesa_realizada',
        'resultado_realizado',
        'economia_mensal',
        'percentual_receita_realizada',
        'percentual_despesa_realizada',
      ],
      ...report.items.map((item) => [
            _monthKey(item.month),
            _money(item.expectedIncome),
            _money(item.expectedExpense),
            _money(item.expectedResult),
            _money(item.paidIncome),
            _money(item.paidExpense),
            _money(item.realizedResult),
            _money(item.monthlySavings),
            item.incomeRealizationRatio.toStringAsFixed(4),
            item.expenseRealizationRatio.toStringAsFixed(4),
          ]),
    ];
    return _toCsv(rows);
  }

  static String debitCreditToCsv(FinanceDebitCreditReport report) {
    final rows = <List<Object?>>[
      ['campo', 'valor'],
      ['mes', _monthKey(report.month)],
      ['compras_debito_dinheiro_pix', _money(report.debitAmount)],
      ['compras_credito', _money(report.creditAmount)],
      ['pagamentos_fatura', _money(report.invoicePaymentAmount)],
      ['total_gasto_sem_duplicar_fatura', _money(report.totalSpending)],
      ['saida_de_caixa', _money(report.totalCashOut)],
      ['quantidade_debito', report.debitCount],
      ['quantidade_credito', report.creditCount],
      ['quantidade_pagamentos_fatura', report.invoicePaymentCount],
      ['percentual_debito', report.debitPercent.toStringAsFixed(2)],
      ['percentual_credito', report.creditPercent.toStringAsFixed(2)],
      ['percentual_fatura_na_saida_caixa', report.invoicePaymentPercentOfCashOut.toStringAsFixed(2)],
      ['usa_mais_credito_que_debito', report.usesMoreCreditThanDebit ? 'sim' : 'nao'],
      ['alerta_fatura_antiga', report.hasInvoicePaymentRisk ? 'sim' : 'nao'],
    ];
    return _toCsv(rows);
  }

  static String _toCsv(List<List<Object?>> rows) {
    return rows.map((row) => row.map(_escape).join(',')).join('\n');
  }

  static String _escape(Object? value) {
    if (value == null) return '';
    final raw = '$value';
    final escaped = raw.replaceAll('"', '""');
    final mustQuote = escaped.contains(',') || escaped.contains('"') || escaped.contains('\n') || escaped.contains('\r');
    return mustQuote ? '"$escaped"' : escaped;
  }

  static String _money(num value) => value.toDouble().toStringAsFixed(2);

  static String _monthKey(DateTime month) {
    return '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';
  }
}
