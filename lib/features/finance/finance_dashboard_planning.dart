import 'package:flutter/material.dart';

import '../../core/utils/money_formatter.dart';
import '../../data/models/budget_model.dart';
import '../../data/models/financial_account_model.dart';
import '../../data/models/financial_goal_model.dart';
import '../../data/models/transaction_model.dart';
import 'finance_budget_rules.dart';

class FinanceDashboardPlanning extends StatelessWidget {
  final List<FinancialAccount> accounts;
  final List<Budget> budgets;
  final List<FinancialGoal> goals;
  final List<FinancialTransaction> transactions;
  final DateTime selectedMonth;
  final VoidCallback onAccounts;
  final VoidCallback onBudgets;
  final VoidCallback onGoals;

  const FinanceDashboardPlanning({
    super.key,
    required this.accounts,
    required this.budgets,
    required this.goals,
    required this.transactions,
    required this.selectedMonth,
    required this.onAccounts,
    required this.onBudgets,
    required this.onGoals,
  });

  @override
  Widget build(BuildContext context) {
    final activeAccounts = accounts.where((a) => !a.isArchived).toList();
    final totalAccounts = activeAccounts.where((a) => !a.ignoreInTotals).fold<double>(0, (sum, a) => sum + a.currentBalance);
    final monthKey = _monthKey(selectedMonth);
    final monthBudgets = budgets.where((b) => !b.isArchived && b.month == monthKey).toList();
    final budgetUsages = FinanceBudgetRules.usageForAll(monthBudgets, transactions)..sort((a, b) => b.plannedRatio.compareTo(a.plannedRatio));
    final activeGoals = goals.where((g) => g.status == 'active' && !g.isArchived).toList()
      ..sort((a, b) => _goalRatio(b).compareTo(_goalRatio(a)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: 'Resumo de contas', actionLabel: 'Ver contas', onAction: onAccounts),
        const SizedBox(height: 8),
        SizedBox(
          height: 126,
          child: activeAccounts.isEmpty
              ? _EmptyPlanningCard(icon: Icons.account_balance_wallet_outlined, title: 'Nenhuma conta cadastrada', subtitle: 'Cadastre suas contas para ver o saldo por carteira.', onTap: onAccounts)
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: activeAccounts.take(6).length + 1,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) return _AccountSummaryCard(title: 'Total em contas', subtitle: '${activeAccounts.length} conta(s)', amount: totalAccounts, color: totalAccounts >= 0 ? Colors.green : Colors.red, onTap: onAccounts);
                    final account = activeAccounts[index - 1];
                    final color = _parseColor(account.color, Colors.blueGrey);
                    return _AccountSummaryCard(title: account.name, subtitle: account.ignoreInTotals ? 'Fora do total' : _accountTypeLabel(account.type), amount: account.currentBalance, color: color, onTap: onAccounts);
                  },
                ),
        ),
        const SizedBox(height: 18),
        _SectionHeader(title: 'Orçamentos do mês', actionLabel: 'Ver orçamentos', onAction: onBudgets),
        const SizedBox(height: 8),
        _BudgetPreviewCard(usages: budgetUsages, onTap: onBudgets),
        const SizedBox(height: 18),
        _SectionHeader(title: 'Metas financeiras', actionLabel: 'Ver metas', onAction: onGoals),
        const SizedBox(height: 8),
        _GoalsPreviewCard(goals: activeGoals, onTap: onGoals),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  const _SectionHeader({required this.title, required this.actionLabel, required this.onAction});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      );
}

class _AccountSummaryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double amount;
  final Color color;
  final VoidCallback onTap;
  const _AccountSummaryCard({required this.title, required this.subtitle, required this.amount, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 205,
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: color.withValues(alpha: 0.18))),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(Icons.account_balance_wallet_outlined, color: color)),
                const Spacer(),
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                const SizedBox(height: 4),
                Text(MoneyFormatter.format(amount), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
              ]),
            ),
          ),
        ),
      );
}

class _BudgetPreviewCard extends StatelessWidget {
  final List<FinanceBudgetUsage> usages;
  final VoidCallback onTap;
  const _BudgetPreviewCard({required this.usages, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (usages.isEmpty) return _EmptyPlanningCard(icon: Icons.speed_outlined, title: 'Nenhum orçamento neste mês', subtitle: 'Crie limites por categoria para controlar seus gastos.', onTap: onTap);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade300)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: usages.take(3).map((usage) => _BudgetUsageRow(usage: usage)).toList()),
        ),
      ),
    );
  }
}

class _BudgetUsageRow extends StatelessWidget {
  final FinanceBudgetUsage usage;
  const _BudgetUsageRow({required this.usage});

  @override
  Widget build(BuildContext context) {
    final ratio = usage.plannedRatio.clamp(0, 1).toDouble();
    final color = usage.isOverPlanned ? Colors.red : (usage.plannedRatio >= 0.8 ? Colors.orange : Colors.green);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(usage.budget.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
          Text('${(usage.plannedRatio * 100).clamp(0, 999).toStringAsFixed(0)}%', style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: ratio, minHeight: 8, color: color, backgroundColor: color.withValues(alpha: 0.14))),
        const SizedBox(height: 4),
        Text('${MoneyFormatter.format(usage.plannedAmount)} de ${MoneyFormatter.format(usage.budget.limitAmount)}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
      ]),
    );
  }
}

class _GoalsPreviewCard extends StatelessWidget {
  final List<FinancialGoal> goals;
  final VoidCallback onTap;
  const _GoalsPreviewCard({required this.goals, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) return _EmptyPlanningCard(icon: Icons.flag_outlined, title: 'Nenhuma meta ativa', subtitle: 'Crie objetivos de economia e acompanhe seu progresso.', onTap: onTap);
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: goals.take(6).length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => _GoalCard(goal: goals[index], onTap: onTap),
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  final FinancialGoal goal;
  final VoidCallback onTap;
  const _GoalCard({required this.goal, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ratio = _goalRatio(goal).clamp(0, 1).toDouble();
    final color = _parseColor(goal.color, Colors.green);
    return SizedBox(
      width: 218,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: color.withValues(alpha: 0.18))),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              SizedBox(
                width: 58,
                height: 58,
                child: Stack(alignment: Alignment.center, children: [
                  CircularProgressIndicator(value: ratio, strokeWidth: 7, color: color, backgroundColor: color.withValues(alpha: 0.12)),
                  Text('${(ratio * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                ]),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(goal.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(MoneyFormatter.format(goal.currentAmount), style: TextStyle(color: color, fontWeight: FontWeight.w800)),
                Text('de ${MoneyFormatter.format(goal.targetAmount)}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              ])),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EmptyPlanningCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _EmptyPlanningCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade300)),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: Icon(icon, color: Theme.of(context).colorScheme.primary)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
              ])),
            ]),
          ),
        ),
      );
}

Color _parseColor(String raw, Color fallback) {
  final value = int.tryParse(raw);
  return value == null ? fallback : Color(value);
}

double _goalRatio(FinancialGoal goal) => goal.targetAmount <= 0 ? 0 : goal.currentAmount / goal.targetAmount;
String _monthKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
String _accountTypeLabel(String type) => switch (type) { 'cash' => 'Dinheiro', 'credit' => 'Crédito', 'investment' => 'Investimento', _ => 'Conta' };
