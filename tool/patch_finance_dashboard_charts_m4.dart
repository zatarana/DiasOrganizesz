import 'dart:io';

void main() {
  final file = File('lib/features/finance/finance_entry_screen.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }

  var text = file.readAsStringSync();

  if (!text.contains("import 'finance_dashboard_charts.dart';")) {
    text = text.replaceFirst(
      "import 'finance_categories_screen.dart';\n",
      "import 'finance_categories_screen.dart';\nimport 'finance_dashboard_charts.dart';\n",
    );
  }

  text = text.replaceFirst(
    '    final categoryHighlights = _categoryHighlights(data, categories);\n',
    '',
  );

  text = text.replaceFirst(
    '''                child: _QuickChartsCard(
                  data: data,
                  categoryHighlights: categoryHighlights,
                ),
''',
    '''                child: FinanceDashboardCharts(
                  data: data,
                  categories: categories,
                  transactions: transactions,
                  selectedMonth: _selectedMonth,
                ),
''',
  );

  final checks = <String>[
    "import 'finance_dashboard_charts.dart';",
    'FinanceDashboardCharts(',
    'categories: categories',
    'transactions: transactions',
    'selectedMonth: _selectedMonth',
  ];

  for (final check in checks) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO Etapa 4: FinanceEntryScreen não foi ligada aos gráficos. Faltou: $check');
      exit(1);
    }
  }

  if (text.contains('child: _QuickChartsCard(')) {
    stderr.writeln('ERRO Etapa 4: dashboard ainda usa o card antigo de gráficos.');
    exit(1);
  }

  file.writeAsStringSync(text);
  stdout.writeln('Etapa 4 aplicada: FinanceEntryScreen ligada aos gráficos fl_chart.');
}
