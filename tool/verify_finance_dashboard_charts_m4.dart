import 'dart:io';

void main() {
  final charts = File('lib/features/finance/finance_dashboard_charts.dart');
  final entry = File('lib/features/finance/finance_entry_screen.dart');
  final pubspec = File('pubspec.yaml');

  if (!charts.existsSync() || !entry.existsSync() || !pubspec.existsSync()) {
    stderr.writeln('ERRO Etapa 4: arquivos esperados não encontrados.');
    exit(1);
  }

  final chartsText = charts.readAsStringSync();
  final entryText = entry.readAsStringSync();
  final pubspecText = pubspec.readAsStringSync();

  final checks = <String, List<String>>{
    'pubspec.yaml': ['fl_chart:'],
    'finance_dashboard_charts.dart': [
      "import 'package:fl_chart/fl_chart.dart';",
      'class FinanceDashboardCharts extends StatelessWidget',
      'PieChart(',
      'PieChartData(',
      'PieChartSectionData',
      'BarChart(',
      'BarChartData(',
      'BarChartGroupData',
      'BarChartRodData',
      'FinanceTransactionRules.paidIncomeForMonth',
      'FinanceTransactionRules.paidExpenseForMonth',
      'Top categorias',
      'Receitas x despesas',
    ],
    'finance_entry_screen.dart': [
      "import 'finance_dashboard_charts.dart';",
      'FinanceDashboardCharts(',
      'categories: categories',
      'transactions: transactions',
      'selectedMonth: _selectedMonth',
    ],
  };

  for (final item in checks['pubspec.yaml']!) {
    if (!pubspecText.contains(item)) {
      stderr.writeln('ERRO Etapa 4: pubspec.yaml sem $item');
      exit(1);
    }
  }

  for (final item in checks['finance_dashboard_charts.dart']!) {
    if (!chartsText.contains(item)) {
      stderr.writeln('ERRO Etapa 4: finance_dashboard_charts.dart sem $item');
      exit(1);
    }
  }

  for (final item in checks['finance_entry_screen.dart']!) {
    if (!entryText.contains(item)) {
      stderr.writeln('ERRO Etapa 4: finance_entry_screen.dart sem $item');
      exit(1);
    }
  }

  if (entryText.contains('child: _QuickChartsCard(')) {
    stderr.writeln('ERRO Etapa 4: FinanceEntryScreen ainda usa o gráfico antigo.');
    exit(1);
  }

  stdout.writeln('Etapa 4 OK: dashboard financeiro usa gráficos fl_chart reais.');
}
