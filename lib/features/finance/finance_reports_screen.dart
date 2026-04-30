import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money_formatter.dart';
import '../../data/models/financial_category_model.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/providers.dart';
import 'finance_budgets_screen.dart';
import 'finance_category_report_screen.dart';
import 'finance_debit_credit_screen.dart';
import 'finance_export_screen.dart';
import 'finance_monthly_evolution_screen.dart';
import 'finance_planned_vs_realized_report_screen.dart';
import 'finance_subcategory_report_screen.dart';

class FinanceReportsScreen extends ConsumerStatefulWidget {
  const FinanceReportsScreen({super.key});

  @override
  ConsumerState<FinanceReportsScreen> createState() => _FinanceReportsScreenState();
}

class _FinanceReportsScreenState extends ConsumerState<FinanceReportsScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  void _changeMonth(int delta) {
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta));
  }

  void _goToCurrentMonth() {
    final now = DateTime.now();
    setState(() => _selectedMonth = DateTime(now.year, now.month));
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return now.year == _selectedMonth.year && now.month == _selectedMonth.month;
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final categories = ref.watch(financialCategoriesProvider);
    final categoryTotals = _buildExpenseCategorySlices(transactions, categories, _selectedMonth);
    final monthlyReports = _buildMonthlyReports(transactions, _selectedMonth);
    final selectedMonthSummary = _summaryForMonth(transactions, _selectedMonth);

    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios Financeiros')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReportsHeader(summary: selectedMonthSummary, selectedMonth: _selectedMonth),
          const SizedBox(height: 12),
          _MonthNavigator(
            selectedMonth: _selectedMonth,
            isCurrentMonth: _isCurrentMonth,
            onPrevious: () => _changeMonth(-1),
            onNext: () => _changeMonth(1),
            onToday: _goToCurrentMonth,
          ),
          const SizedBox(height: 16),
          _ExpenseDonutReportCard(
            month: _selectedMonth,
            slices: categoryTotals,
          ),
          const SizedBox(height: 16),
          _MonthlyIncomeExpenseBarCard(reports: monthlyReports),
          const SizedBox(height: 20),
          const Text('Relatórios detalhados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _ReportNavigationCard(
            icon: Icons.show_chart,
            title: 'Evolução mensal',
            subtitle: 'Compare receitas, despesas, resultado e economia mês a mês.',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceMonthlyEvolutionScreen())),
          ),
          const SizedBox(height: 8),
          _ReportNavigationCard(
            icon: Icons.credit_score_outlined,
            title: 'Débito vs crédito',
            subtitle: 'Compare gastos diretos, compras no cartão e pagamentos de fatura.',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceDebitCreditScreen())),
          ),
          const SizedBox(height: 8),
          _ReportNavigationCard(
            icon: Icons.file_download_outlined,
            title: 'Exportação CSV',
            subtitle: 'Gere CSV de transações, evolução mensal e débito vs crédito.',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceExportScreen())),
          ),
          const SizedBox(height: 8),
          _ReportNavigationCard(
            icon: Icons.compare_arrows,
            title: 'Previsto x realizado',
            subtitle: 'Compare receitas, despesas e resultado planejado com o que foi pago.',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancePlannedVsRealizedReportScreen())),
          ),
          const SizedBox(height: 8),
          _ReportNavigationCard(
            icon: Icons.category_outlined,
            title: 'Gastos por categoria',
            subtitle: 'Veja ranking mensal das maiores categorias de gasto.',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceCategoryReportScreen())),
          ),
          const SizedBox(height: 8),
          _ReportNavigationCard(
            icon: Icons.leaderboard_outlined,
            title: 'Gastos por subcategoria',
            subtitle: 'Ranking mensal, percentuais e maiores focos de gasto.',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceSubcategoryReportScreen())),
          ),
          const SizedBox(height: 8),
          _ReportNavigationCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Orçamentos avançados',
            subtitle: 'Acompanhe limites gerais, por categoria e por subcategoria.',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceBudgetsScreen())),
          ),
        ],
      ),
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  final _MonthSummary summary;
  final DateTime selectedMonth;

  const _ReportsHeader({required this.summary, required this.selectedMonth});

  @override
  Widget build(BuildContext context) {
    final result = summary.income - summary.expense;
    final resultColor = result >= 0 ? Colors.green : Colors.red;
    final monthLabel = _capitalize(DateFormat('MMMM yyyy', 'pt_BR').format(selectedMonth));

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: const Icon(Icons.analytics_outlined)),
                const SizedBox(width: 12),
                const Expanded(child: Text('Central de análise', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 10),
            Text('Resumo realizado de $monthLabel', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _SummaryPill(label: 'Receitas', value: MoneyFormatter.format(summary.income), color: Colors.green, icon: Icons.arrow_upward),
                _SummaryPill(label: 'Despesas', value: MoneyFormatter.format(summary.expense), color: Colors.red, icon: Icons.arrow_downward),
                _SummaryPill(label: 'Resultado', value: MoneyFormatter.format(result), color: resultColor, icon: Icons.account_balance_wallet_outlined),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _SummaryPill({required this.label, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthNavigator extends StatelessWidget {
  final DateTime selectedMonth;
  final bool isCurrentMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _MonthNavigator({required this.selectedMonth, required this.isCurrentMonth, required this.onPrevious, required this.onNext, required this.onToday});

  @override
  Widget build(BuildContext context) {
    final label = _capitalize(DateFormat('MMMM yyyy', 'pt_BR').format(selectedMonth));
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(tooltip: 'Mês anterior', onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
            Expanded(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            IconButton(tooltip: 'Próximo mês', onPressed: onNext, icon: const Icon(Icons.chevron_right)),
            if (!isCurrentMonth) TextButton(onPressed: onToday, child: const Text('Hoje')),
          ],
        ),
      ),
    );
  }
}

class _ExpenseDonutReportCard extends StatelessWidget {
  final DateTime month;
  final List<_CategoryExpenseSlice> slices;

  const _ExpenseDonutReportCard({required this.month, required this.slices});

  @override
  Widget build(BuildContext context) {
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.amount);
    final monthLabel = _capitalize(DateFormat('MMMM yyyy', 'pt_BR').format(month));

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Despesas por categoria', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                Text(MoneyFormatter.format(total), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Gráfico de rosca com despesas pagas em $monthLabel.', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 16),
            if (slices.isEmpty)
              const _ReportEmptyState(icon: Icons.donut_large_outlined, title: 'Sem despesas pagas no mês', subtitle: 'Quando houver despesas pagas, a rosca de categorias aparece aqui.')
            else ...[
              SizedBox(
                height: 220,
                child: Center(
                  child: CustomPaint(
                    size: const Size(210, 210),
                    painter: _DonutChartPainter(slices: slices),
                    child: SizedBox(
                      width: 210,
                      height: 210,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Total', style: TextStyle(color: Colors.grey)),
                            Text(MoneyFormatter.format(total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ...slices.take(8).map((slice) => _CategoryLegendTile(slice: slice, total: total)),
              if (slices.length > 8)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('+${slices.length - 8} categoria(s) menores agrupadas visualmente na rosca.', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MonthlyIncomeExpenseBarCard extends StatelessWidget {
  final List<_MonthlyReport> reports;

  const _MonthlyIncomeExpenseBarCard({required this.reports});

  @override
  Widget build(BuildContext context) {
    final hasData = reports.any((report) => report.income > 0 || report.expense > 0);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Receita vs despesa mensal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Barras dos últimos 6 meses com valores pagos/realizados.', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            Row(
              children: const [
                _LegendDot(color: Colors.green, label: 'Receitas'),
                SizedBox(width: 16),
                _LegendDot(color: Colors.red, label: 'Despesas'),
              ],
            ),
            const SizedBox(height: 16),
            if (!hasData)
              const _ReportEmptyState(icon: Icons.bar_chart_outlined, title: 'Sem histórico para comparar', subtitle: 'Registre receitas e despesas pagas para montar o gráfico mensal.')
            else ...[
              SizedBox(
                height: 230,
                width: double.infinity,
                child: CustomPaint(painter: _MonthlyBarChartPainter(reports: reports)),
              ),
              const SizedBox(height: 12),
              ...reports.reversed.map((report) => _MonthlyReportTile(report: report)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportNavigationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportNavigationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _CategoryLegendTile extends StatelessWidget {
  final _CategoryExpenseSlice slice;
  final double total;

  const _CategoryLegendTile({required this.slice, required this.total});

  @override
  Widget build(BuildContext context) {
    final percentage = total <= 0 ? 0 : (slice.amount / total) * 100;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: slice.color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(child: Text(slice.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(width: 10),
          Text(MoneyFormatter.format(slice.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _MonthlyReportTile extends StatelessWidget {
  final _MonthlyReport report;

  const _MonthlyReportTile({required this.report});

  @override
  Widget build(BuildContext context) {
    final result = report.income - report.expense;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          SizedBox(width: 48, child: Text(report.label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text('Receitas ${MoneyFormatter.format(report.income)} · Despesas ${MoneyFormatter.format(report.expense)}', overflow: TextOverflow.ellipsis)),
          Text(MoneyFormatter.format(result), style: TextStyle(color: result >= 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class _ReportEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _ReportEmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Icon(icon, size: 42, color: Colors.grey.shade600),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<_CategoryExpenseSlice> slices;

  const _DonutChartPainter({required this.slices});

  @override
  void paint(Canvas canvas, Size size) {
    final total = slices.fold<double>(0, (sum, slice) => sum + slice.amount);
    if (total <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius - 10);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 34
      ..strokeCap = StrokeCap.round;

    var startAngle = -math.pi / 2;
    for (final slice in slices) {
      final sweep = (slice.amount / total) * math.pi * 2;
      paint.color = slice.color;
      canvas.drawArc(rect, startAngle, math.max(0.02, sweep - 0.012), false, paint);
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => oldDelegate.slices != slices;
}

class _MonthlyBarChartPainter extends CustomPainter {
  final List<_MonthlyReport> reports;

  const _MonthlyBarChartPainter({required this.reports});

  @override
  void paint(Canvas canvas, Size size) {
    if (reports.isEmpty) return;

    final maxAmount = reports.fold<double>(0, (maxValue, report) => math.max(maxValue, math.max(report.income, report.expense)));
    if (maxAmount <= 0) return;

    final axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    final incomePaint = Paint()..color = Colors.green;
    final expensePaint = Paint()..color = Colors.red;
    final textPainter = TextPainter(textDirection: TextDirection.ltr, textAlign: TextAlign.center);

    const leftPadding = 8.0;
    const bottomPadding = 28.0;
    const topPadding = 8.0;
    final chartHeight = size.height - bottomPadding - topPadding;
    final columnWidth = (size.width - leftPadding) / reports.length;
    final barWidth = math.min(20.0, columnWidth / 4.2);

    canvas.drawLine(Offset(leftPadding, size.height - bottomPadding), Offset(size.width, size.height - bottomPadding), axisPaint);

    for (var index = 0; index < reports.length; index++) {
      final report = reports[index];
      final groupCenter = leftPadding + (columnWidth * index) + columnWidth / 2;
      final incomeHeight = (report.income / maxAmount) * chartHeight;
      final expenseHeight = (report.expense / maxAmount) * chartHeight;
      final baseline = size.height - bottomPadding;

      final incomeRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(groupCenter - barWidth - 3, baseline - incomeHeight, barWidth, incomeHeight),
        const Radius.circular(6),
      );
      final expenseRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(groupCenter + 3, baseline - expenseHeight, barWidth, expenseHeight),
        const Radius.circular(6),
      );
      canvas.drawRRect(incomeRect, incomePaint);
      canvas.drawRRect(expenseRect, expensePaint);

      textPainter.text = TextSpan(text: report.label, style: TextStyle(color: Colors.grey.shade700, fontSize: 11));
      textPainter.layout(maxWidth: columnWidth);
      textPainter.paint(canvas, Offset(groupCenter - columnWidth / 2, size.height - bottomPadding + 8));
    }
  }

  @override
  bool shouldRepaint(covariant _MonthlyBarChartPainter oldDelegate) => oldDelegate.reports != reports;
}

class _CategoryExpenseSlice {
  final String name;
  final double amount;
  final Color color;

  const _CategoryExpenseSlice({required this.name, required this.amount, required this.color});
}

class _MonthlyReport {
  final DateTime month;
  final String label;
  final double income;
  final double expense;

  const _MonthlyReport({required this.month, required this.label, required this.income, required this.expense});
}

class _MonthSummary {
  final double income;
  final double expense;

  const _MonthSummary({required this.income, required this.expense});
}

List<_CategoryExpenseSlice> _buildExpenseCategorySlices(List<FinancialTransaction> transactions, List<FinancialCategory> categories, DateTime month) {
  final categoryMap = {for (final category in categories) category.id: category};
  final totals = <int?, double>{};

  for (final transaction in transactions) {
    if (!_isReportExpense(transaction, month)) continue;
    totals[transaction.categoryId] = (totals[transaction.categoryId] ?? 0) + transaction.amount;
  }

  final slices = totals.entries.map((entry) {
    final category = categoryMap[entry.key];
    return _CategoryExpenseSlice(
      name: category?.name ?? 'Sem categoria',
      amount: entry.value,
      color: _categoryColor(category),
    );
  }).toList()
    ..sort((a, b) => b.amount.compareTo(a.amount));
  return slices;
}

List<_MonthlyReport> _buildMonthlyReports(List<FinancialTransaction> transactions, DateTime selectedMonth) {
  return List.generate(6, (index) {
    final month = DateTime(selectedMonth.year, selectedMonth.month - (5 - index));
    final summary = _summaryForMonth(transactions, month);
    return _MonthlyReport(
      month: month,
      label: DateFormat('MMM', 'pt_BR').format(month).replaceAll('.', ''),
      income: summary.income,
      expense: summary.expense,
    );
  });
}

_MonthSummary _summaryForMonth(List<FinancialTransaction> transactions, DateTime month) {
  double income = 0;
  double expense = 0;

  for (final transaction in transactions) {
    if (!_isReportTransactionInMonth(transaction, month)) continue;
    if (transaction.type == 'income') income += transaction.amount;
    if (transaction.type == 'expense') expense += transaction.amount;
  }

  return _MonthSummary(income: income, expense: expense);
}

bool _isReportExpense(FinancialTransaction transaction, DateTime month) {
  return transaction.type == 'expense' && _isReportTransactionInMonth(transaction, month);
}

bool _isReportTransactionInMonth(FinancialTransaction transaction, DateTime month) {
  if (transaction.status != 'paid') return false;
  if (transaction.status == 'canceled') return false;
  if (transaction.ignoreInReports) return false;
  final date = _reportDate(transaction);
  return date != null && date.year == month.year && date.month == month.month;
}

DateTime? _reportDate(FinancialTransaction transaction) {
  return DateTime.tryParse(transaction.paidDate ?? transaction.dueDate ?? transaction.transactionDate);
}

Color _categoryColor(FinancialCategory? category) {
  if (category == null) return Colors.blueGrey;
  final parsed = int.tryParse(category.color);
  if (parsed == null) return Colors.blueGrey;
  return Color(parsed);
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}
