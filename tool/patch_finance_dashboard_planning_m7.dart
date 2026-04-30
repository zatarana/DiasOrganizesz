import 'dart:io';

void main() {
  final file = File('lib/features/finance/finance_entry_screen.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }
  var text = file.readAsStringSync();

  text = _ensureImport(text, "import '../../core/utils/money_formatter.dart';", "import '../../data/database/finance_planning_store.dart';");
  text = _ensureImport(text, "import '../../data/models/debt_model.dart';", "import '../../data/models/budget_model.dart';");
  text = _ensureImport(text, "import '../../data/models/financial_category_model.dart';", "import '../../data/models/financial_account_model.dart';");
  text = _ensureImport(text, "import '../../data/models/financial_category_model.dart';", "import '../../data/models/financial_goal_model.dart';");
  text = _ensureImport(text, "import 'finance_budget_rules.dart';", "import 'finance_budgets_screen.dart';");
  text = _ensureImport(text, "import 'finance_dashboard_charts.dart';", "import 'finance_dashboard_planning.dart';");

  if (!text.contains('final planningDataAsync = ref.watch(_financeDashboardPlanningProvider);')) {
    text = text.replaceFirst(
      '    final transactions = ref.watch(transactionsProvider);\n',
      '    final transactions = ref.watch(transactionsProvider);\n    final planningDataAsync = ref.watch(_financeDashboardPlanningProvider);\n',
    );
  }

  if (!text.contains("title: 'Planejamento financeiro'")) {
    text = text.replaceFirst(
      "            SliverToBoxAdapter(\n              child: Padding(\n                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),\n                child: _DashboardSectionTitle(\n                  title: 'Transações recentes',",
      "            SliverToBoxAdapter(\n              child: Padding(\n                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),\n                child: _DashboardSectionTitle(title: 'Planejamento financeiro'),\n              ),\n            ),\n            SliverToBoxAdapter(\n              child: Padding(\n                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),\n                child: planningDataAsync.when(\n                  data: (planning) => FinanceDashboardPlanning(\n                    accounts: planning.accounts,\n                    budgets: planning.budgets,\n                    goals: planning.goals,\n                    transactions: transactions,\n                    selectedMonth: _selectedMonth,\n                    onAccounts: () => _open(context, const FinancePlanningScreen()),\n                    onBudgets: () => _open(context, const FinanceBudgetsScreen()),\n                    onGoals: () => _open(context, const FinancialGoalsScreen()),\n                  ),\n                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),\n                  error: (_, __) => const _EmptyFinancePanel(icon: Icons.error_outline, title: 'Não foi possível carregar o planejamento', subtitle: 'Abra Planejamento para verificar contas, orçamentos e metas.'),\n                ),\n              ),\n            ),\n            SliverToBoxAdapter(\n              child: Padding(\n                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),\n                child: _DashboardSectionTitle(\n                  title: 'Transações recentes',",
    );
  }

  if (!text.contains('class _FinanceDashboardPlanningData')) {
    final insertAt = text.lastIndexOf("String _capitalize(String value) {");
    if (insertAt == -1) {
      stderr.writeln('Não foi possível inserir provider de planejamento.');
      exit(1);
    }
    text = text.replaceRange(insertAt, insertAt, r'''
final _financeDashboardPlanningProvider = FutureProvider<_FinanceDashboardPlanningData>((ref) async {
  final db = await ref.watch(dbProvider).database;
  final accounts = await FinancePlanningStore.getAccounts(db, recalculateBeforeRead: true);
  final budgets = await FinancePlanningStore.getBudgets(db);
  final goals = await FinancePlanningStore.getGoals(db);
  return _FinanceDashboardPlanningData(accounts: accounts, budgets: budgets, goals: goals);
});

class _FinanceDashboardPlanningData {
  final List<FinancialAccount> accounts;
  final List<Budget> budgets;
  final List<FinancialGoal> goals;

  const _FinanceDashboardPlanningData({required this.accounts, required this.budgets, required this.goals});
}

''');
  }

  for (final check in [
    "import '../../data/models/budget_model.dart';",
    "import '../../data/models/financial_account_model.dart';",
    "import '../../data/models/financial_goal_model.dart';",
    "import 'finance_dashboard_planning.dart';",
    '_financeDashboardPlanningProvider',
    'FinancePlanningStore.getAccounts',
    'FinancePlanningStore.getBudgets',
    'FinancePlanningStore.getGoals',
    'FinanceDashboardPlanning(',
    "title: 'Planejamento financeiro'",
    'FinanceBudgetsScreen',
    'FinancialGoalsScreen',
  ]) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO Etapa 7: dashboard financeiro incompleto. Faltou: $check');
      exit(1);
    }
  }

  file.writeAsStringSync(text);
  stdout.writeln('Etapa 7 aplicada: planejamento financeiro no dashboard.');
}

String _ensureImport(String text, String after, String importLine) {
  if (text.contains(importLine)) return text;
  return text.replaceFirst(after, '$after\n$importLine');
}
