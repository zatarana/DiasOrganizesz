import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/providers.dart';
import 'finance_debit_credit_report.dart';

class FinanceDebitCreditScreen extends ConsumerStatefulWidget {
  const FinanceDebitCreditScreen({super.key});

  @override
  ConsumerState<FinanceDebitCreditScreen> createState() => _FinanceDebitCreditScreenState();
}

class _FinanceDebitCreditScreenState extends ConsumerState<FinanceDebitCreditScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  void _previousMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1));
  void _nextMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1));
  void _currentMonth() {
    final now = DateTime.now();
    setState(() => _selectedMonth = DateTime(now.year, now.month, 1));
  }

  String _money(num value) => 'R\$ ${value.toDouble().toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final report = FinanceDebitCreditReport.fromTransactions(
      transactions: ref.watch(transactionsProvider),
      month: _selectedMonth,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Débito vs Crédito')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MonthSelector(
            selectedMonth: _selectedMonth,
            onPrevious: _previousMonth,
            onCurrent: _currentMonth,
            onNext: _nextMonth,
          ),
          const SizedBox(height: 12),
          _SummaryCard(report: report, money: _money),
          const SizedBox(height: 12),
          _UsageCard(
            title: 'Compras no débito / dinheiro / pix',
            amount: report.debitAmount,
            count: report.debitCount,
            percent: report.debitPercent,
            icon: Icons.account_balance_wallet_outlined,
            money: _money,
          ),
          const SizedBox(height: 8),
          _UsageCard(
            title: 'Compras no crédito',
            amount: report.creditAmount,
            count: report.creditCount,
            percent: report.creditPercent,
            icon: Icons.credit_card,
            money: _money,
          ),
          const SizedBox(height: 8),
          _UsageCard(
            title: 'Pagamentos de fatura',
            amount: report.invoicePaymentAmount,
            count: report.invoicePaymentCount,
            percent: report.invoicePaymentPercentOfCashOut,
            icon: Icons.receipt_long,
            money: _money,
            subtitle: 'Conta como saída de caixa, mas não duplica o gasto do cartão.',
          ),
          if (report.hasInvoicePaymentRisk) ...[
            const SizedBox(height: 12),
            const _RiskCard(),
          ],
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onCurrent;
  final VoidCallback onNext;

  const _MonthSelector({required this.selectedMonth, required this.onPrevious, required this.onCurrent, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrevious),
            Expanded(
              child: InkWell(
                onTap: onCurrent,
                child: Text(
                  DateFormat('MMMM yyyy', 'pt_BR').format(selectedMonth).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final FinanceDebitCreditReport report;
  final String Function(num value) money;

  const _SummaryCard({required this.report, required this.money});

  @override
  Widget build(BuildContext context) {
    final creditDominant = report.usesMoreCreditThanDebit;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumo do mês', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Metric(label: 'Gasto sem fatura', value: money(report.totalSpending), icon: Icons.shopping_bag_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _Metric(label: 'Saída de caixa', value: money(report.totalCashOut), icon: Icons.payments_outlined)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (creditDominant ? Colors.deepPurple : Colors.green).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(creditDominant ? Icons.credit_card : Icons.account_balance_wallet_outlined, color: creditDominant ? Colors.deepPurple : Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      creditDominant ? 'Uso maior de crédito no mês.' : 'Uso maior de débito/dinheiro/pix no mês.',
                      style: TextStyle(fontWeight: FontWeight.w600, color: creditDominant ? Colors.deepPurple : Colors.green),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Metric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 18, child: Icon(icon, size: 20)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _UsageCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final double amount;
  final int count;
  final double percent;
  final IconData icon;
  final String Function(num value) money;

  const _UsageCard({required this.title, this.subtitle, required this.amount, required this.count, required this.percent, required this.icon, required this.money});

  @override
  Widget build(BuildContext context) {
    final value = (percent / 100).clamp(0.0, 1.0).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Icon(icon)),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
                Text('${percent.toStringAsFixed(1)}%'),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: value),
            const SizedBox(height: 8),
            Text('${money(amount)} • $count lançamento(ões)'),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.withValues(alpha: 0.10),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.warning_amber_outlined, color: Colors.orange),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'A saída com faturas ficou maior que as compras de crédito do mês. Pode haver faturas antigas pesando no caixa atual.',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
