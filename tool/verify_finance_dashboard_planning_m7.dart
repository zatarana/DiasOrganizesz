import 'dart:io';

void main() {
  final widget = File('lib/features/finance/finance_dashboard_planning.dart');
  final entry = File('lib/features/finance/finance_entry_screen.dart');
  if (!widget.existsSync() || !entry.existsSync()) {
    stderr.writeln('ERRO Etapa 7: arquivos esperados não encontrados.');
    exit(1);
  }

  final widgetText = widget.readAsStringSync();
  final entryText = entry.readAsStringSync();

  final widgetChecks = [
    'class FinanceDashboardPlanning extends StatelessWidget',
    'Resumo de contas',
    'Orçamentos do mês',
    'Metas financeiras',
    'FinanceBudgetRules.usageForAll',
    'LinearProgressIndicator',
    'CircularProgressIndicator',
    'MoneyFormatter.format',
    'FinancialAccount',
    'Budget',
    'FinancialGoal',
  ];

  final entryChecks = [
    "import 'finance_dashboard_planning.dart';",
    '_financeDashboardPlanningProvider',
    'FinancePlanningStore.getAccounts',
    'FinancePlanningStore.getBudgets',
    'FinancePlanningStore.getGoals',
    'FinanceDashboardPlanning(',
    "title: 'Planejamento financeiro'",
    'FinanceBudgetsScreen',
    'FinancialGoalsScreen',
  ];

  for (final check in widgetChecks) {
    if (!widgetText.contains(check)) {
      stderr.writeln('ERRO Etapa 7: widget incompleto. Faltou: $check');
      exit(1);
    }
  }

  for (final check in entryChecks) {
    if (!entryText.contains(check)) {
      stderr.writeln('ERRO Etapa 7: entrada financeira incompleta. Faltou: $check');
      exit(1);
    }
  }

  stdout.writeln('Etapa 7 OK: contas, orçamentos e metas aparecem no dashboard financeiro.');
}
