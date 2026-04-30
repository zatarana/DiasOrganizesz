import 'dart:io';

void main() {
  final entry = File('lib/features/finance/finance_entry_screen.dart');
  final provider = File('lib/features/finance/finance_screen_data_provider.dart');

  if (!entry.existsSync() || !provider.existsSync()) {
    stderr.writeln('Arquivos financeiros esperados não encontrados.');
    exit(1);
  }

  final entryText = entry.readAsStringSync();
  final providerText = provider.readAsStringSync();

  final providerChecks = <String>[
    "import '../../data/models/budget_model.dart';",
    'final financeBudgetsProvider = FutureProvider<List<Budget>>',
    'FinancePlanningStore.getBudgets(db)',
  ];

  final entryChecks = <String>[
    "import 'finance_budget_rules.dart';",
    "import 'finance_budgets_screen.dart';",
    'financeBudgetsProvider',
    'FinanceBudgetRules.usageForAll',
    '_FinanceAttentionSnapshot.from(data: data, debts: debts, budgetUsages: budgetUsages)',
    '_ImmediateAttentionCarousel',
    'Dívidas críticas',
    'Orçamentos no limite',
    '_AttentionUrgency',
    '_AttentionUrgency.good',
    '_AttentionUrgency.warning',
    '_AttentionUrgency.danger',
    'criticalDebts',
    'budgetsAtLimit',
    'worstBudgetName',
    'plannedRatio >= 0.8',
    'FinanceBudgetsScreen',
  ];

  for (final check in providerChecks) {
    if (!providerText.contains(check)) {
      stderr.writeln('ERRO Etapa 3: provider financeiro incompleto. Faltou: $check');
      exit(1);
    }
  }

  for (final check in entryChecks) {
    if (!entryText.contains(check)) {
      stderr.writeln('ERRO Etapa 3: atenção imediata incompleta. Faltou: $check');
      exit(1);
    }
  }

  if (entryText.contains("title: 'Planejamento',\n        value: 'Metas e contas'")) {
    stderr.writeln('ERRO Etapa 3: card genérico de planejamento ainda aparece no lugar de orçamento real.');
    exit(1);
  }

  stdout.writeln('Etapa 3 OK: atenção imediata usa transações, dívidas críticas e orçamentos reais.');
}
