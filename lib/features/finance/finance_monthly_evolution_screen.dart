import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/providers.dart';
import 'finance_monthly_evolution_report.dart';

class FinanceMonthlyEvolutionScreen extends ConsumerStatefulWidget {
  const FinanceMonthlyEvolutionScreen({super.key});

  @override
  ConsumerState<FinanceMonthlyEvolutionScreen> createState() => _FinanceMonthlyEvolutionScreenState();
}

class _FinanceMonthlyEvolutionScreenState extends ConsumerState<FinanceMonthlyEvolutionScreen> {
  DateTime _endMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int _monthsBack = 6;

  DateTime get _startMonth => DateTime(_endMonth.year, _endMonth.month - _monthsBack + 1, 1);

  void _previousPeriod() {
    setState(() => _endMonth = DateTime(_endMonth.year, _endMonth.month - _monthsBack, 1));
  }

  void _nextPeriod() {
    setState(() => _endMonth = DateTime(_endMonth.year, _endMonth.month + _monthsBack, 1));
  }

  void _currentPeriod() {
    final now = DateTime.now();
    setState(() => _endMonth = DateTime(now.year, now.month, 1));
  }

  String _money(num value) => 'R\$ ${value.toDouble().toStringAsFixed(2)}';

  String _monthLabel(DateTime month) => DateFormat('MMM/yy', 'pt_BR').format(month).toUpperCase();

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final report = FinanceMonthlyEvolutionReport.fromTransactions(
      transactions: transactions,
      startMonth: _startMonth,
      endMonth: _endMonth,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Evolução mensal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PeriodSelector(
            startMonth: _startMonth,
            endMonth: _endMonth,
            monthsBack: _monthsBack,
            onPrevious: _previousPeriod,
            onCurrent: _currentPeriod,
            onNext: _nextPeriod,
            onMonthsChanged: (value) => setState(() => _monthsBack = value),
          ),
          const SizedBox(height: 12),
          _EvolutionSummaryCard(report: report, money: _money, monthLabel: _monthLabel),
          const SizedBox(height: 12),
          if (report.items.isEmpty)
            const _EmptyEvolutionState()
          else
            ...report.items.map((item) => _EvolutionMonthCard(
                  item: item,
                  maxAbsResult: _maxAbsResult(report),
                  money: _money,
                  monthLabel: _monthLabel,
                )),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  double _maxAbsResult(FinanceMonthlyEvolutionReport report) {
    if (report.items.isEmpty) return 1;
    final max = report.items
        .map((item) => item.realizedResult.abs())
        .fold<double>(0, (current, value) => value > current ? value : current);
    return max <= 0 ? 1 : max;
  }
}

class _PeriodSelector extends StatelessWidget {
  final DateTime startMonth;
  final DateTime endMonth;
  final int monthsBack;
  final VoidCallback onPrevious;
  final VoidCallback onCurrent;
  final VoidCallback onNext;
  final ValueChanged<int> onMonthsChanged;

  const _PeriodSelector({
    required this.startMonth,
    required this.endMonth,
    required this.monthsBack,
    required this.onPrevious,
    required this.onCurrent,
    required this.onNext,
    required this.onMonthsChanged,
  });

  String _label(DateTime month) => DateFormat('MMM/yyyy', 'pt_BR').format(month).toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrevious),
                Expanded(
                  child: InkWell(
                    onTap: onCurrent,
                    child: Text(
                      '${_label(startMonth)} — ${_label(endMonth)}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
              ],
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 3, label: Text('3m')),
                ButtonSegment(value: 6, label: Text('6m')),
                ButtonSegment(value: 12, label: Text('12m')),
              ],
              selected: {monthsBack},
              onSelectionChanged: (selection) => onMonthsChanged(selection.first),
            ),
          ],
        ),
      ),
    );
  }
}

class _EvolutionSummaryCard extends StatelessWidget {
  final FinanceMonthlyEvolutionReport report;
  final String Function(num value) money;
  final String Function(DateTime month) monthLabel;

  const _EvolutionSummaryCard({required this.report, required this.money, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    final best = report.bestResultMonth;
    final worst = report.worstResultMonth;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumo do período', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Metric(label: 'Receitas', value: money(report.totalPaidIncome), icon: Icons.arrow_upward)),
                const SizedBox(width: 12),
                Expanded(child: _Metric(label: 'Despesas', value: money(report.totalPaidExpense), icon: Icons.arrow_downward)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _Metric(label: 'Resultado', value: money(report.totalRealizedResult), icon: Icons.balance)),
                const SizedBox(width: 12),
                Expanded(child: _Metric(label: 'Economia', value: money(report.totalSavings), icon: Icons.savings_outlined)),
              ],
            ),
            if (best != null && worst != null) ...[
              const SizedBox(height: 14),
              Text('Melhor mês: ${monthLabel(best.month)} • ${money(best.realizedResult)}'),
              Text('Pior mês: ${monthLabel(worst.month)} • ${money(worst.realizedResult)}'),
            ],
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

class _EvolutionMonthCard extends StatelessWidget {
  final FinanceMonthlyEvolutionItem item;
  final double maxAbsResult;
  final String Function(num value) money;
  final String Function(DateTime month) monthLabel;

  const _EvolutionMonthCard({required this.item, required this.maxAbsResult, required this.money, required this.monthLabel});

  @override
  Widget build(BuildContext context) {
    final result = item.realizedResult;
    final positive = result >= 0;
    final barValue = (result.abs() / maxAbsResult).clamp(0.0, 1.0).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: (positive ? Colors.green : Colors.red).withValues(alpha: 0.12),
                  child: Icon(positive ? Icons.trending_up : Icons.trending_down, color: positive ? Colors.green : Colors.red),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(monthLabel(item.month), style: const TextStyle(fontWeight: FontWeight.bold))),
                Text(money(result), style: TextStyle(fontWeight: FontWeight.bold, color: positive ? Colors.green : Colors.red)),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: barValue),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text('Receitas: ${money(item.paidIncome)}')),
                Expanded(child: Text('Despesas: ${money(item.paidExpense)}')),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text('Previsto: ${money(item.expectedResult)}')),
                Expanded(child: Text('Economia: ${money(item.monthlySavings)}')),
              ],
            ),
            const SizedBox(height: 4),
            Text('Realização: receitas ${(item.incomeRealizationRatio * 100).toStringAsFixed(0)}% • despesas ${(item.expenseRealizationRatio * 100).toStringAsFixed(0)}%'),
          ],
        ),
      ),
    );
  }
}

class _EmptyEvolutionState extends StatelessWidget {
  const _EmptyEvolutionState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: Text('Nenhuma movimentação encontrada no período.', style: TextStyle(color: Colors.grey))),
    );
  }
}
