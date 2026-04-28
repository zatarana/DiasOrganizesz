import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/finance_planning_store.dart';
import '../../data/database/financial_goal_store.dart';
import '../../data/models/financial_account_model.dart';
import '../../data/models/financial_goal_model.dart';
import '../../domain/providers.dart';
import 'financial_goal_rules.dart';

class FinancialGoalsScreen extends ConsumerStatefulWidget {
  const FinancialGoalsScreen({super.key});

  @override
  ConsumerState<FinancialGoalsScreen> createState() => _FinancialGoalsScreenState();
}

class _FinancialGoalsScreenState extends ConsumerState<FinancialGoalsScreen> {
  bool _loading = true;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<FinancialGoal> _goals = [];
  List<FinancialAccount> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final db = await ref.read(dbProvider).database;
    final goals = await FinancialGoalStore.getGoals(db);
    final accounts = await FinancePlanningStore.getAccounts(db, recalculateBeforeRead: true);
    if (!mounted) return;
    setState(() {
      _goals = goals;
      _accounts = accounts;
      _loading = false;
    });
  }

  String _money(num value) => 'R\$ ${value.toDouble().toStringAsFixed(2)}';

  FinancialAccount? _accountById(int? id) {
    if (id == null) return null;
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  void _previousMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1));
  void _nextMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1));
  void _currentMonth() {
    final now = DateTime.now();
    setState(() => _selectedMonth = DateTime(now.year, now.month, 1));
  }

  Future<void> _showGoalDialog({FinancialGoal? goal}) async {
    final nameController = TextEditingController(text: goal?.name ?? '');
    final descriptionController = TextEditingController(text: goal?.description ?? '');
    final targetController = TextEditingController(text: goal == null ? '' : goal.targetAmount.toStringAsFixed(2));
    final currentController = TextEditingController(text: goal == null ? '0.00' : goal.currentAmount.toStringAsFixed(2));
    DateTime? targetDate = goal?.targetDate == null ? null : DateTime.tryParse(goal!.targetDate!);
    int? accountId = goal?.accountId;
    String status = goal?.status ?? 'active';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final selectableAccounts = _accounts.where((account) => !account.isArchived || account.id == accountId).toList();
          final safeAccountId = selectableAccounts.any((account) => account.id == accountId) ? accountId : null;

          return AlertDialog(
            title: Text(goal == null ? 'Novo objetivo' : 'Editar objetivo'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome do objetivo')),
                  TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Descrição'), maxLines: 2),
                  TextField(
                    controller: targetController,
                    decoration: const InputDecoration(labelText: 'Valor alvo', prefixText: 'R\$ '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: currentController,
                    decoration: const InputDecoration(labelText: 'Valor atual', prefixText: 'R\$ '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: targetDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setLocal(() => targetDate = picked);
                    },
                    icon: const Icon(Icons.event),
                    label: Text(targetDate == null ? 'Sem data alvo' : 'Data alvo: ${DateFormat('dd/MM/yyyy').format(targetDate!)}'),
                  ),
                  if (targetDate != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => setLocal(() => targetDate = null),
                        child: const Text('Limpar data'),
                      ),
                    ),
                  DropdownButtonFormField<int>(
                    initialValue: safeAccountId,
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('Sem conta vinculada')),
                      ...selectableAccounts.map((account) => DropdownMenuItem<int>(value: account.id, child: Text('${account.name}${account.isArchived ? ' (arquivada)' : ''}'))),
                    ],
                    onChanged: (value) => setLocal(() => accountId = value),
                    decoration: const InputDecoration(labelText: 'Conta vinculada'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    items: const [
                      DropdownMenuItem(value: 'active', child: Text('Ativo')),
                      DropdownMenuItem(value: 'paused', child: Text('Pausado')),
                      DropdownMenuItem(value: 'completed', child: Text('Concluído')),
                    ],
                    onChanged: (value) => setLocal(() => status = value ?? 'active'),
                    decoration: const InputDecoration(labelText: 'Status'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              TextButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final targetAmount = double.tryParse(targetController.text.replaceAll(',', '.')) ?? 0;
                  final currentAmount = double.tryParse(currentController.text.replaceAll(',', '.')) ?? 0;

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o nome do objetivo.')));
                    return;
                  }
                  if (targetAmount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O valor alvo deve ser maior que zero.')));
                    return;
                  }
                  if (currentAmount < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O valor atual não pode ser negativo.')));
                    return;
                  }

                  final now = DateTime.now().toIso8601String();
                  final effectiveStatus = currentAmount >= targetAmount ? 'completed' : status == 'completed' ? 'active' : status;
                  final data = FinancialGoal(
                    id: goal?.id,
                    name: name,
                    description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                    targetAmount: targetAmount,
                    currentAmount: currentAmount,
                    accountId: accountId,
                    targetDate: targetDate?.toIso8601String(),
                    status: effectiveStatus,
                    color: goal?.color ?? '0xFF4CAF50',
                    icon: goal?.icon ?? 'flag',
                    isArchived: goal?.isArchived ?? false,
                    createdAt: goal?.createdAt ?? now,
                    updatedAt: now,
                  );
                  await FinancialGoalStore.upsertGoal(await ref.read(dbProvider).database, data);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    descriptionController.dispose();
    targetController.dispose();
    currentController.dispose();
    if (saved == true) await _loadAll();
  }

  Future<void> _showProgressDialog(FinancialGoal goal) async {
    final controller = TextEditingController(text: goal.currentAmount.toStringAsFixed(2));
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Atualizar ${goal.name}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Valor atual', prefixText: 'R\$ '),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final value = double.tryParse(controller.text.replaceAll(',', '.')) ?? -1;
              if (value < 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um valor atual válido.')));
                return;
              }
              await FinancialGoalStore.updateGoalProgress(await ref.read(dbProvider).database, goal.id!, value);
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (saved == true) await _loadAll();
  }

  Future<void> _archiveGoal(FinancialGoal goal) async {
    if (goal.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arquivar objetivo?'),
        content: Text('O objetivo "${goal.name}" será ocultado da lista ativa, mas preservado no banco.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Arquivar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    await FinancialGoalStore.archiveGoal(await ref.read(dbProvider).database, goal.id!);
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final monthlySavings = FinancialGoalRules.monthlySavings(transactions: transactions, month: _selectedMonth);
    final suggestedContribution = FinancialGoalRules.suggestedGoalContribution(transactions: transactions, month: _selectedMonth, allocationPercent: 50);
    final progressItems = FinancialGoalRules.progressForAll(_goals);

    return Scaffold(
      appBar: AppBar(title: const Text('Objetivos financeiros')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showGoalDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Objetivo'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _MonthSelector(
                    selectedMonth: _selectedMonth,
                    onPrevious: _previousMonth,
                    onCurrent: _currentMonth,
                    onNext: _nextMonth,
                  ),
                  const SizedBox(height: 12),
                  _SavingsSummaryCard(
                    monthlySavings: monthlySavings,
                    suggestedContribution: suggestedContribution,
                    money: _money,
                  ),
                  const SizedBox(height: 12),
                  if (progressItems.isEmpty)
                    const _EmptyGoalsState()
                  else
                    ...progressItems.map((progress) => _GoalCard(
                          progress: progress,
                          accountName: _accountById(progress.goal.accountId)?.name,
                          money: _money,
                          onEdit: () => _showGoalDialog(goal: progress.goal),
                          onUpdateProgress: progress.goal.id == null ? null : () => _showProgressDialog(progress.goal),
                          onArchive: () => _archiveGoal(progress.goal),
                        )),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final VoidCallback onPrevious;
  final VoidCallback onCurrent;
  final VoidCallback onNext;

  const _MonthSelector({required this.selectedMonth, required this.onPrevious, required this.onCurrent, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: onPrevious),
            Expanded(
              child: InkWell(
                onTap: onCurrent,
                child: Text(
                  DateFormat('MMMM yyyy', 'pt_BR').format(selectedMonth).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: onNext),
          ],
        ),
      ),
    );
  }
}

class _SavingsSummaryCard extends StatelessWidget {
  final double monthlySavings;
  final double suggestedContribution;
  final String Function(num value) money;

  const _SavingsSummaryCard({required this.monthlySavings, required this.suggestedContribution, required this.money});

  @override
  Widget build(BuildContext context) {
    final positive = monthlySavings >= 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Economia mensal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _Metric(label: 'Economia do mês', value: money(monthlySavings), icon: positive ? Icons.trending_up : Icons.trending_down)),
                const SizedBox(width: 12),
                Expanded(child: _Metric(label: 'Sugestão 50%', value: money(suggestedContribution), icon: Icons.savings_outlined)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              positive ? 'A sugestão usa metade da economia mensal positiva para avançar objetivos.' : 'Sem economia positiva neste mês para sugerir aporte.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _Metric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 18, child: Icon(icon, size: 20)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _GoalCard extends StatelessWidget {
  final FinancialGoalProgress progress;
  final String? accountName;
  final String Function(num value) money;
  final VoidCallback onEdit;
  final VoidCallback? onUpdateProgress;
  final VoidCallback onArchive;

  const _GoalCard({required this.progress, required this.accountName, required this.money, required this.onEdit, required this.onUpdateProgress, required this.onArchive});

  @override
  Widget build(BuildContext context) {
    final goal = progress.goal;
    final days = progress.daysRemaining();
    final monthly = progress.requiredMonthlySaving();
    final completed = progress.isCompleted || goal.status == 'completed';

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (completed ? Colors.green : Colors.blue).withValues(alpha: 0.12),
          child: Icon(completed ? Icons.check : Icons.flag_outlined, color: completed ? Colors.green : Colors.blue),
        ),
        title: Text(goal.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (goal.description != null && goal.description!.isNotEmpty) Text(goal.description!),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress.ratio),
            const SizedBox(height: 6),
            Text('${money(progress.currentAmount)} de ${money(progress.targetAmount)} • ${progress.percent.toStringAsFixed(1)}%'),
            Text('Restante: ${money(progress.remainingAmount)}'),
            if (accountName != null) Text('Conta: $accountName'),
            if (days != null) Text(days >= 0 ? 'Prazo: $days dia(s)' : 'Prazo vencido há ${days.abs()} dia(s)'),
            if (monthly != null && progress.remainingAmount > 0) Text('Necessário/mês: ${money(monthly)}'),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'progress' && onUpdateProgress != null) onUpdateProgress!();
            if (value == 'edit') onEdit();
            if (value == 'archive') onArchive();
          },
          itemBuilder: (context) => [
            if (onUpdateProgress != null) const PopupMenuItem(value: 'progress', child: Text('Atualizar progresso')),
            const PopupMenuItem(value: 'edit', child: Text('Editar')),
            const PopupMenuItem(value: 'archive', child: Text('Arquivar')),
          ],
        ),
      ),
    );
  }
}

class _EmptyGoalsState extends StatelessWidget {
  const _EmptyGoalsState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text('Nenhum objetivo financeiro cadastrado ainda.', style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}
