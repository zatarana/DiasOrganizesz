import 'dart:io';

void main() {
  final file = File('lib/features/finance/finance_entry_screen.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }

  var text = file.readAsStringSync();

  text = _patchRefreshData(text);
  text = _patchOpenCalls(text);
  text = _patchOpenMethod(text);
  text = _patchInitialRefresh(text);
  _validate(text);

  file.writeAsStringSync(text);
  stdout.writeln('Dashboard financeiro: refresh vivo de contas/metas/orçamentos aplicado.');
}

String _patchRefreshData(String text) {
  if (!text.contains('ref.invalidate(_financeDashboardPlanningProvider);')) {
    text = text.replaceFirst(
      '    ref.invalidate(financeBudgetsProvider);\n    ref.invalidate(realAccountBalanceProvider);',
      '    ref.invalidate(financeBudgetsProvider);\n    ref.invalidate(_financeDashboardPlanningProvider);\n    ref.invalidate(realAccountBalanceProvider);',
    );
  }

  if (!text.contains('ref.read(_financeDashboardPlanningProvider.future)')) {
    text = text.replaceFirst(
      '      ref.read(financeBudgetsProvider.future),\n    ]);',
      '      ref.read(financeBudgetsProvider.future),\n      ref.read(_financeDashboardPlanningProvider.future),\n    ]);',
    );
  }

  return text;
}

String _patchOpenCalls(String text) {
  text = text.replaceAll('_open(context, const FinanceScreen())', '_openAndRefresh(const FinanceScreen())');
  text = text.replaceAll('_open(context, const FinanceHubScreen())', '_openAndRefresh(const FinanceHubScreen())');
  text = text.replaceAll('_open(context, const DebtsScreen())', '_openAndRefresh(const DebtsScreen())');
  text = text.replaceAll('_open(context, const FinanceBudgetsScreen())', '_openAndRefresh(const FinanceBudgetsScreen())');
  text = text.replaceAll('_open(context, const FinanceReportsScreen())', '_openAndRefresh(const FinanceReportsScreen())');
  text = text.replaceAll('_open(context, const CreateTransactionScreen())', '_openAndRefresh(const CreateTransactionScreen())');
  text = text.replaceAll('_open(context, const FinancePlanningScreen())', '_openAndRefresh(const FinancePlanningScreen())');
  text = text.replaceAll('_open(context, const CreditCardsScreen())', '_openAndRefresh(const CreditCardsScreen())');
  text = text.replaceAll('_open(context, const FinancialGoalsScreen())', '_openAndRefresh(const FinancialGoalsScreen())');
  text = text.replaceAll('_open(context, const FinanceCategoriesScreen())', '_openAndRefresh(const FinanceCategoriesScreen())');
  text = text.replaceAll('_open(context, const FinanceExportScreen())', '_openAndRefresh(const FinanceExportScreen())');
  text = text.replaceAll('_open(context, CreateTransactionScreen(transaction: transaction))', '_openAndRefresh(CreateTransactionScreen(transaction: transaction))');
  return text;
}

String _patchOpenMethod(String text) {
  final oldMethod = '''
  static void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
''';
  final newMethod = '''
  Future<void> _openAndRefresh(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    await _refreshData();
  }
''';

  if (text.contains(oldMethod)) {
    return text.replaceFirst(oldMethod, newMethod);
  }

  if (!text.contains('Future<void> _openAndRefresh(Widget screen) async')) {
    final marker = '\n}\n\nclass _SliverBalanceHeader';
    if (!text.contains(marker)) {
      stderr.writeln('ERRO: não foi possível inserir _openAndRefresh.');
      exit(1);
    }
    return text.replaceFirst(marker, '$newMethod\n}\n\nclass _SliverBalanceHeader');
  }

  return text;
}

String _patchInitialRefresh(String text) {
  if (text.contains('_financeEntryInitialRefreshScheduled')) return text;

  text = text.replaceFirst(
    '  late DateTime _selectedMonth;\n',
    '  late DateTime _selectedMonth;\n  bool _financeEntryInitialRefreshScheduled = false;\n',
  );

  text = text.replaceFirst(
    '  @override\n  Widget build(BuildContext context) {',
    '''  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_financeEntryInitialRefreshScheduled) return;
    _financeEntryInitialRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshData();
    });
  }

  @override
  Widget build(BuildContext context) {''',
  );

  return text;
}

void _validate(String text) {
  final required = <String>[
    'ref.invalidate(_financeDashboardPlanningProvider);',
    'ref.read(_financeDashboardPlanningProvider.future)',
    'Future<void> _openAndRefresh(Widget screen) async',
    'await _refreshData();',
    '_openAndRefresh(const FinancePlanningScreen())',
    '_openAndRefresh(const FinancialGoalsScreen())',
    '_openAndRefresh(const FinanceBudgetsScreen())',
    'WidgetsBinding.instance.addPostFrameCallback',
  ];

  for (final check in required) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO refresh dashboard financeiro: faltou "$check".');
      exit(1);
    }
  }

  if (text.contains('_open(context,')) {
    stderr.writeln('ERRO refresh dashboard financeiro: ainda existe navegação sem refresh na aba Finanças.');
    exit(1);
  }
}
