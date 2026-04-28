import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/providers.dart';
import 'finance_planned_vs_realized_report.dart';

class FinancePlannedVsRealizedReportScreen extends ConsumerStatefulWidget {
  const FinancePlannedVsRealizedReportScreen({super.key});

  @override
  ConsumerState<FinancePlannedVsRealizedReportScreen> createState() => _FinancePlannedVsRealizedReportScreenState();
}

class _FinancePlannedVsRealizedReportScreenState extends ConsumerState<FinancePlannedVsRealizedReportScreen> {
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
    final report = FinancePlannedVsRealizedReport.fromTransactions(
      month: _selectedMonth,
      transactions: ref.watch(transactionsProvider),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Previsto x Realizado')),
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
          _ResultSummaryCard(report: report, money: _money),
          const SizedBox(height: 12),
          _ComparisonCard(
            title: 'Receitas',
            icon: Icons.arrow_upward,
            expectedLabel: 'Receita prevista',
            realizedLabel: 'Receita realizada',
            expected: report.expectedIncome,
            realized: report.realizedIncome,
            ratio: report.incomeRealizationRatio,
            money: _money,
          ),
          const SizedBox(height: 8),
          _ComparisonCard(
            title: 'Despesas',
            icon: Icons.arrow_downward,
            expectedLabel: 'Despesa prevista',
            realizedLabel: 'Despesa realizada',
            expected: report.expectedExpense,
            realized: report.realizedExpense,
            ratio: report.expenseRealizationRatio,
            money: _money,
          ),
          const SizedBox(height: 8),
          _DifferenceCard(report: report, money: _money),
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

class _ResultSummaryCard extends StatelessWidget {
  final FinancePlannedVsRealizedReport report;
  final String Function(num value) money;

  const _ResultSummaryCard({required this.report, required this.money});

  @override
  Widget build(BuildContext context) {
    final better = report.realizedBetterThanExpected;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resultado do mês', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _SummaryValue(label: 'Previsto', value: money(report.expectedResult), icon: Icons.event_note_outlined)),
                const SizedBox(width: 12),
                Expanded(child: _SummaryValue(label: 'Realizado', value: money(report.realizedResult), icon: Icons.check_circle_outline)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (better ? Colors.green : Colors.orange).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(better ? Icons.trending_up : Icons.trending_down, color: better ? Colors.green : Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${better ? 'Melhor' : 'Abaixo'} do previsto em ${money(report.resultDifference.abs())}',
                      style: TextStyle(fontWeight: FontWeight.w600, color: better ? Colors.green : Colors.orange),
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

class _ComparisonCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String expectedLabel;
  final String realizedLabel;
  final double expected;
  final double realized;
  final double ratio;
  final String Function(num value) money;

  const _ComparisonCard({
    required this.title,
    required this.icon,
    required this.expectedLabel,
    required this.realizedLabel,
    required this.expected,
    required this.realized,
    required this.ratio,
    required this.money,
  });

  @override
  Widget build(BuildContext context) {
    final diff = realized - expected;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Icon(icon)),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                Text('${(ratio * 100).toStringAsFixed(0)}%'),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: ratio),
            const SizedBox(height: 12),
            Text('$expectedLabel: ${money(expected)}'),
            Text('$realizedLabel: ${money(realized)}'),
            Text(
              'Diferença: ${diff >= 0 ? '+' : '-'}${money(diff.abs())}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _DifferenceCard extends StatelessWidget {
  final FinancePlannedVsRealizedReport report;
  final String Function(num value) money;

  const _DifferenceCard({required this.report, required this.money});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Leitura rápida', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Receitas: ${report.incomeDifference >= 0 ? '+' : '-'}${money(report.incomeDifference.abs())} em relação ao previsto.'),
            Text('Despesas: ${report.expenseDifference >= 0 ? '+' : '-'}${money(report.expenseDifference.abs())} em relação ao previsto.'),
            Text('Resultado final: ${report.resultDifference >= 0 ? '+' : '-'}${money(report.resultDifference.abs())} em relação ao plano.'),
          ],
        ),
      ),
    );
  }
}
