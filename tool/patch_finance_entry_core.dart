import 'dart:io';

void main() {
  final file = File('lib/features/finance/finance_entry_screen.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }

  var text = file.readAsStringSync();

  text = text.replaceFirst(
    "import 'package:intl/intl.dart';\n\nimport '../../data/database/finance_planning_store.dart';",
    "import 'package:intl/intl.dart';\n\nimport '../../core/utils/money_formatter.dart';",
  );

  text = text.replaceAll("  late Future<double> _realBalanceFuture;\n", '');

  text = text.replaceFirst(
    '''    _selectedMonth = DateTime(now.year, now.month);
    _realBalanceFuture = _loadRealBalance();
''',
    '''    _selectedMonth = DateTime(now.year, now.month);
''',
  );

  final loadStart = text.indexOf('  Future<double> _loadRealBalance() async {');
  if (loadStart != -1) {
    final refreshStart = text.indexOf('  Future<void> _refreshData() async {', loadStart);
    if (refreshStart == -1) {
      stderr.writeln('ERRO: não foi possível localizar _refreshData após _loadRealBalance.');
      exit(1);
    }
    text = text.replaceRange(loadStart, refreshStart, '');
  }

  text = text.replaceFirst(
    '''  Future<void> _refreshData() async {
    await ref.read(transactionsProvider.notifier).loadTransactions();
    await ref.read(debtsProvider.notifier).loadDebts();
    final nextBalanceFuture = _loadRealBalance();
    if (mounted) setState(() => _realBalanceFuture = nextBalanceFuture);
    await nextBalanceFuture;
  }
''',
    '''  Future<void> _refreshData() async {
    await ref.read(transactionsProvider.notifier).loadTransactions();
    await ref.read(debtsProvider.notifier).loadDebts();
    ref.invalidate(realAccountBalanceProvider);
    await ref.read(realAccountBalanceProvider.future);
  }
''',
  );

  text = text.replaceFirst(
    '''    final monthTransactions = transactions.where((transaction) => _isSameMonth(_expectedDate(transaction), _selectedMonth)).toList();
    final dashboard = _FinanceDashboard.from(monthTransactions, debts);
''',
    '''    final realBalanceAsync = ref.watch(realAccountBalanceProvider);
    final monthTransactions = transactions.where((transaction) => _isSameMonth(_expectedDate(transaction), _selectedMonth)).toList();
    final dashboard = _FinanceDashboard.from(monthTransactions, debts);
''',
  );

  text = text.replaceFirst(
    '''            FutureBuilder<double>(
              future: _realBalanceFuture,
              builder: (context, snapshot) {
                return _MonthHeroCard(
                  month: _selectedMonth,
                  dashboard: dashboard,
                  realBalance: snapshot.data,
                  isLoadingRealBalance: snapshot.connectionState == ConnectionState.waiting,
                );
              },
            ),
''',
    '''            _MonthHeroCard(
              month: _selectedMonth,
              dashboard: dashboard,
              realBalance: realBalanceAsync.valueOrNull,
              isLoadingRealBalance: realBalanceAsync.isLoading,
            ),
''',
  );

  text = text.replaceFirst(
    "String _money(num value) {\n  return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\\\$', decimalDigits: 2).format(value);\n}\n",
    "String _money(num value) => MoneyFormatter.format(value);\n",
  );

  final checks = <String>[
    "import '../../core/utils/money_formatter.dart';",
    'realBalanceAsync = ref.watch(realAccountBalanceProvider)',
    'ref.invalidate(realAccountBalanceProvider)',
    'MoneyFormatter.format(value)',
  ];
  for (final check in checks) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO: patch da entrada financeira incompleto. Faltou: $check');
      exit(1);
    }
  }
  if (text.contains('FinancePlanningStore') || text.contains('_realBalanceFuture') || text.contains('_loadRealBalance') || text.contains('FutureBuilder<double>')) {
    stderr.writeln('ERRO: entrada financeira ainda mantém carregamento local de saldo.');
    exit(1);
  }

  file.writeAsStringSync(text);
  stdout.writeln('finance_entry_screen.dart atualizado para provider compartilhado e MoneyFormatter.');
}
