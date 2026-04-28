import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/providers.dart';
import 'finance_category_report.dart';

class FinanceCategoryReportScreen extends ConsumerStatefulWidget {
  const FinanceCategoryReportScreen({super.key});

  @override
  ConsumerState<FinanceCategoryReportScreen> createState() => _FinanceCategoryReportScreenState();
}

class _FinanceCategoryReportScreenState extends ConsumerState<FinanceCategoryReportScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);

  void _previousMonth() {
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1));
  }

  void _nextMonth() {
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1));
  }

  void _currentMonth() {
    final now = DateTime.now();
    setState(() => _selectedMonth = DateTime(now.year, now.month, 1));
  }

  String _money(num value) => 'R\$ ${value.toDouble().toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final categories = ref.watch(financialCategoriesProvider);
    final report = FinanceCategoryReport.fromTransactions(
      month: _selectedMonth,
      transactions: transactions,
      categories: categories,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Gastos por categoria')),
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
          _ReportSummaryCard(report: report, money: _money),
          const SizedBox(height: 16),
          if (report.items.isEmpty)
            const _ReportEmptyState()
          else
            ...report.items.map((item) => _ReportItemCard(item: item, total: report.total, money: _money)),
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

  const _MonthSelector({
    required this.selectedMonth,
    required this.onPrevious,
    required this.onCurrent,
    required this.onNext,
  });

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

class _ReportSummaryCard extends StatelessWidget {
  final FinanceCategoryReport report;
  final String Function(num value) money;

  const _ReportSummaryCard({required this.report, required this.money});

  @override
  Widget build(BuildContext context) {
    final top = report.topItem;
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
                Expanded(child: _SummaryValue(label: 'Total analisado', value: money(report.total), icon: Icons.payments_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _SummaryValue(label: 'Categorias', value: '${report.items.length}', icon: Icons.category_outlined)),
              ],
            ),
            if (top != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                child: Row(
                  children: [
                    const Icon(Icons.leaderboard_outlined, color: Colors.green),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Maior categoria: ${top.categoryName} — ${money(top.amount)} (${top.percentOf(report.total).toStringAsFixed(1)}%)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SummaryValue({required this.label, required this.value, required this.icon});

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

class _ReportItemCard extends StatelessWidget {
  final FinanceCategoryReportItem item;
  final double total;
  final String Function(num value) money;

  const _ReportItemCard({required this.item, required this.total, required this.money});

  @override
  Widget build(BuildContext context) {
    final percent = item.percentOf(total);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.withValues(alpha: 0.12),
          child: const Icon(Icons.category_outlined, color: Colors.green),
        ),
        title: Text(item.categoryName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            LinearProgressIndicator(value: (percent / 100).clamp(0.0, 1.0).toDouble()),
            const SizedBox(height: 6),
            Text('${item.transactionCount} transação(ões) • ${percent.toStringAsFixed(1)}% do total'),
          ],
        ),
        trailing: Text(money(item.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _ReportEmptyState extends StatelessWidget {
  const _ReportEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text(
          'Nenhum gasto pago com impacto em relatório neste mês.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}
