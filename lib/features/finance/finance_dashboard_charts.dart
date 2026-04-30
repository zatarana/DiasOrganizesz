import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money_formatter.dart';
import '../../data/models/financial_category_model.dart';
import '../../data/models/transaction_model.dart';
import 'finance_screen_data.dart';
import 'finance_transaction_rules.dart';

class FinanceDashboardCharts extends StatelessWidget {
  final FinanceScreenData data;
  final List<FinancialCategory> categories;
  final List<FinancialTransaction> transactions;
  final DateTime selectedMonth;

  const FinanceDashboardCharts({
    super.key,
    required this.data,
    required this.categories,
    required this.transactions,
    required this.selectedMonth,
  });

  @override
  Widget build(BuildContext context) {
    final highlights = _categoryHighlights(data, categories);
    final monthlyFlow = _monthlyFlowItems(transactions, selectedMonth);
    return Column(
      children: [
        _ExpenseCategoryDonutChart(data: data, highlights: highlights),
        const SizedBox(height: 12),
        _MonthlyFlowBarChart(items: monthlyFlow),
      ],
    );
  }
}

class _ExpenseCategoryDonutChart extends StatelessWidget {
  final FinanceScreenData data;
  final List<_CategoryHighlight> highlights;

  const _ExpenseCategoryDonutChart({required this.data, required this.highlights});

  @override
  Widget build(BuildContext context) {
    final totalExpenses = data.summary.paidExpense;
    final hasData = totalExpenses > 0 && highlights.isNotEmpty;
    final sections = hasData
        ? highlights.map((item) {
            final percentage = totalExpenses <= 0 ? 0.0 : (item.amount / totalExpenses) * 100;
            return PieChartSectionData(
              value: item.amount,
              color: item.color,
              radius: 36,
              showTitle: percentage >= 12,
              title: '${percentage.toStringAsFixed(0)}%',
              titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
            );
          }).toList()
        : <PieChartSectionData>[PieChartSectionData(value: 1, color: Colors.grey.shade200, radius: 36, showTitle: false)];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Top categorias', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                Text(MoneyFormatter.format(totalExpenses), style: TextStyle(color: totalExpenses <= 0 ? Colors.grey : Colors.red, fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Despesas pagas no mês por categoria.', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 132,
                  height: 132,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      PieChart(PieChartData(
                        sections: sections,
                        sectionsSpace: hasData ? 2 : 0,
                        centerSpaceRadius: 42,
                        startDegreeOffset: -90,
                        borderData: FlBorderData(show: false),
                        pieTouchData: PieTouchData(enabled: false),
                      )),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(hasData ? '${highlights.length}' : '0', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                          Text('categorias', style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: hasData
                      ? Column(children: highlights.take(5).map((item) => _CategoryHighlightRow(item: item, total: totalExpenses)).toList())
                      : Text('Quando houver despesas pagas, a divisão por categoria aparece aqui.', style: TextStyle(color: Colors.grey.shade700)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthlyFlowBarChart extends StatelessWidget {
  final List<_MonthlyFlowItem> items;

  const _MonthlyFlowBarChart({required this.items});

  @override
  Widget build(BuildContext context) {
    final maxAmount = items.fold<double>(0, (maxValue, item) => [maxValue, item.income, item.expense].reduce((a, b) => a > b ? a : b));
    final hasData = maxAmount > 0;
    final safeMaxY = hasData ? maxAmount * 1.25 : 100.0;
    final groups = List.generate(items.length, (index) {
      final item = items[index];
      return BarChartGroupData(
        x: index,
        barsSpace: 4,
        barRods: [
          BarChartRodData(toY: item.income, width: 8, color: Colors.green, borderRadius: BorderRadius.circular(6)),
          BarChartRodData(toY: item.expense, width: 8, color: Colors.red, borderRadius: BorderRadius.circular(6)),
        ],
      );
    });

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Receitas x despesas', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 4),
            Text('Comparativo realizado dos últimos 6 meses.', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 10),
            Row(children: const [_ChartLegendDot(color: Colors.green, label: 'Receitas'), SizedBox(width: 14), _ChartLegendDot(color: Colors.red, label: 'Despesas')]),
            const SizedBox(height: 16),
            SizedBox(
              height: 210,
              child: hasData
                  ? BarChart(BarChartData(
                      minY: 0,
                      maxY: safeMaxY,
                      barGroups: groups,
                      alignment: BarChartAlignment.spaceAround,
                      barTouchData: BarTouchData(enabled: false),
                      gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1)),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 30, getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= items.length) return const SizedBox.shrink();
                          return SideTitleWidget(axisSide: meta.axisSide, child: Text(items[index].label, style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w700)));
                        })),
                      ),
                    ))
                  : _EmptyChartState(icon: Icons.bar_chart_outlined, title: 'Sem histórico suficiente', subtitle: 'Registre receitas e despesas pagas para montar o comparativo.'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _ChartLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    ]);
  }
}

class _CategoryHighlightRow extends StatelessWidget {
  final _CategoryHighlight item;
  final double total;

  const _CategoryHighlightRow({required this.item, required this.total});

  @override
  Widget build(BuildContext context) {
    final percent = total <= 0 ? 0 : (item.amount / total) * 100;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: item.color)),
        const SizedBox(width: 8),
        Expanded(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text('${percent.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

class _EmptyChartState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyChartState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 36, color: Colors.grey.shade600),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
        ]),
      ),
    );
  }
}

class _CategoryHighlight {
  final String name;
  final double amount;
  final Color color;

  const _CategoryHighlight({required this.name, required this.amount, required this.color});
}

class _MonthlyFlowItem {
  final DateTime month;
  final String label;
  final double income;
  final double expense;

  const _MonthlyFlowItem({required this.month, required this.label, required this.income, required this.expense});
}

List<_CategoryHighlight> _categoryHighlights(FinanceScreenData data, List<FinancialCategory> categories) {
  final categoryMap = {for (final category in categories) category.id: category};
  final entries = data.summary.paidExpensesByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return entries.take(5).map((entry) {
    final category = categoryMap[entry.key];
    return _CategoryHighlight(name: category?.name ?? 'Sem categoria', amount: entry.value, color: _categoryColor(category));
  }).toList();
}

List<_MonthlyFlowItem> _monthlyFlowItems(List<FinancialTransaction> transactions, DateTime selectedMonth) {
  return List.generate(6, (index) {
    final month = DateTime(selectedMonth.year, selectedMonth.month - (5 - index));
    return _MonthlyFlowItem(
      month: month,
      label: DateFormat('MMM', 'pt_BR').format(month).replaceAll('.', ''),
      income: FinanceTransactionRules.paidIncomeForMonth(transactions, month),
      expense: FinanceTransactionRules.paidExpenseForMonth(transactions, month),
    );
  });
}

Color _categoryColor(FinancialCategory? category) {
  if (category == null) return Colors.blueGrey;
  final parsed = int.tryParse(category.color);
  if (parsed == null) return Colors.blueGrey;
  return Color(parsed);
}
