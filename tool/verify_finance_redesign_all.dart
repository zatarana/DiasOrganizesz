import 'dart:io';

void main() {
  final checks = <_FileCheck>[
    _FileCheck('lib/features/dashboard/app_drawer.dart', contains: [
      'finance_entry_screen.dart',
      'FinanceEntryScreen',
    ], notContains: [
      'finance_screen.dart',
      'FinanceScreen()',
    ]),
    _FileCheck('lib/features/finance/finance_entry_screen.dart', contains: [
      'CustomScrollView',
      'SliverAppBar',
      'financeScreenDataProvider',
      'realAccountBalanceProvider',
      'FinanceDashboardCharts',
      'FinanceDashboardPlanning',
      'showQuickTransactionBottomSheet',
      'Planejamento financeiro',
      'Transações recentes',
    ], notContains: [
      'FutureBuilder<double>',
      '_realBalanceFuture',
      '_loadRealBalance',
    ]),
    _FileCheck('lib/features/finance/finance_dashboard_charts.dart', contains: [
      'PieChart',
      'BarChart',
      'Top categorias',
      'Receitas x despesas',
    ]),
    _FileCheck('lib/features/finance/finance_dashboard_planning.dart', contains: [
      'Resumo de contas',
      'Orçamentos do mês',
      'Metas financeiras',
      'FinanceBudgetRules.usageForAll',
    ]),
    _FileCheck('lib/features/finance/widgets/quick_transaction_bottom_sheet.dart', contains: [
      'QuickTransactionBottomSheet',
      'MoneyInputFormatter',
      'Salvar lançamento',
      'Mais detalhes',
      'transactionsProvider.notifier).addTransaction',
    ]),
    _FileCheck('lib/features/finance/finance_screen.dart', contains: [
      'flutter_slidable',
      '_buildQuickFilterBar',
      'Slidable',
      'SlidableAction',
      'showQuickTransactionBottomSheet',
    ], notContains: [
      'Dismissible(',
      'DismissDirection.horizontal',
    ]),
    _FileCheck('lib/features/finance/finance_hub_screen.dart', contains: [
      'Ferramentas financeiras',
      'O dashboard principal fica na aba Finanças',
      'Configurar e organizar',
      'Planejar',
      'Analisar e exportar',
    ], notContains: [
      'Central Financeira',
      'Tudo que move seu dinheiro, em um só lugar',
    ]),
    _FileCheck('pubspec.yaml', contains: [
      'fl_chart:',
      'flutter_slidable:',
    ]),
  ];

  for (final check in checks) {
    check.run();
  }

  stdout.writeln('Redesign financeiro OK: etapas 1 a 8 verificadas.');
}

class _FileCheck {
  final String path;
  final List<String> contains;
  final List<String> notContains;

  const _FileCheck(this.path, {this.contains = const [], this.notContains = const []});

  void run() {
    final file = File(path);
    if (!file.existsSync()) {
      stderr.writeln('ERRO: arquivo não encontrado: $path');
      exit(1);
    }
    final text = file.readAsStringSync();
    for (final item in contains) {
      if (!text.contains(item)) {
        stderr.writeln('ERRO em $path: faltou "$item"');
        exit(1);
      }
    }
    for (final item in notContains) {
      if (text.contains(item)) {
        stderr.writeln('ERRO em $path: texto antigo/proibido encontrado "$item"');
        exit(1);
      }
    }
  }
}
