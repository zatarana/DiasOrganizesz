import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/finance_planning_store.dart';
import '../../data/models/budget_model.dart';
import '../../data/models/financial_account_model.dart';
import '../../data/models/financial_goal_model.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/providers.dart';

class FinancePlanningScreen extends ConsumerStatefulWidget {
  const FinancePlanningScreen({super.key});

  @override
  ConsumerState<FinancePlanningScreen> createState() => _FinancePlanningScreenState();
}

class _FinancePlanningScreenState extends ConsumerState<FinancePlanningScreen> {
  bool _loading = true;
  List<FinancialAccount> _accounts = [];
  List<Budget> _budgets = [];
  List<FinancialGoal> _goals = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final db = await ref.read(dbProvider).database;
    final accounts = await FinancePlanningStore.getAccounts(db);
    final budgets = await FinancePlanningStore.getBudgets(db);
    final goals = await FinancePlanningStore.getGoals(db);
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _budgets = budgets;
      _goals = goals;
      _loading = false;
    });
  }

  String _money(num value) => 'R\$ ${value.toDouble().toStringAsFixed(2)}';

  bool _validMonth(String value) {
    if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(value)) return false;
    final month = int.tryParse(value.split('-')[1]) ?? 0;
    return month >= 1 && month <= 12;
  }

  String _transactionMonth(FinancialTransaction transaction) {
    final date = DateTime.tryParse(transaction.dueDate ?? transaction.transactionDate);
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}';
  }

  bool _matchesBudget(FinancialTransaction transaction, Budget budget) {
    if (transaction.status == 'canceled' || transaction.type != 'expense') return false;
    if (budget.categoryId != null && transaction.categoryId != budget.categoryId) return false;
    return _transactionMonth(transaction) == budget.month;
  }

  double _plannedForBudget(Budget budget) {
    return ref.read(transactionsProvider).where((transaction) => _matchesBudget(transaction, budget)).fold<double>(0, (sum, transaction) => sum + transaction.amount);
  }

  double _paidForBudget(Budget budget) {
    return ref.read(transactionsProvider).where((transaction) => _matchesBudget(transaction, budget) && transaction.status == 'paid').fold<double>(0, (sum, transaction) => sum + transaction.amount);
  }

  FinancialAccount? _accountById(int? id) {
    if (id == null) return null;
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final totalBalance = _accounts.where((a) => !a.isArchived).fold<double>(0, (sum, account) => sum + account.currentBalance);
    final activeGoals = _goals.where((goal) => goal.status != 'canceled').toList();
    final totalTarget = activeGoals.fold<double>(0, (sum, goal) => sum + goal.targetAmount);
    final totalSaved = activeGoals.fold<double>(0, (sum, goal) => sum + goal.currentAmount);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Planejamento Financeiro'),
          bottom: const TabBar(tabs: [Tab(text: 'Contas'), Tab(text: 'Orçamentos'), Tab(text: 'Metas')]),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _accountsTab(totalBalance),
                  _budgetsTab(),
                  _goalsTab(totalTarget, totalSaved),
                ],
              ),
      ),
    );
  }

  Widget _accountsTab(double totalBalance) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryCard('Saldo total em contas', _money(totalBalance), Icons.account_balance_wallet, Colors.blue),
        const SizedBox(height: 12),
        ElevatedButton.icon(onPressed: () => _showAccountDialog(), icon: const Icon(Icons.add), label: const Text('Adicionar conta')),
        const SizedBox(height: 12),
        if (_accounts.isEmpty)
          const _EmptyState(text: 'Nenhuma conta cadastrada ainda.')
        else
          ..._accounts.map((account) => Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.12), child: Icon(_accountIcon(account.type), color: Colors.blue)),
                  title: Text(account.name),
                  subtitle: Text('${_accountTypeLabel(account.type)}${account.isArchived ? ' • arquivada' : ''}\nBase: ${_money(account.initialBalance)}'),
                  trailing: Text(_money(account.currentBalance), style: const TextStyle(fontWeight: FontWeight.bold)),
                  onTap: () => _showAccountDialog(account: account),
                ),
              )),
      ],
    );
  }

  Widget _budgetsTab() {
    final categories = ref.watch(financialCategoriesProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ElevatedButton.icon(onPressed: () => _showBudgetDialog(), icon: const Icon(Icons.add), label: const Text('Adicionar orçamento')),
        const SizedBox(height: 12),
        if (_budgets.where((b) => !b.isArchived).isEmpty)
          const _EmptyState(text: 'Nenhum orçamento cadastrado ainda.')
        else
          ..._budgets.where((budget) => !budget.isArchived).map((budget) {
            final planned = _plannedForBudget(budget);
            final paid = _paidForBudget(budget);
            final available = budget.limitAmount - planned;
            final ratio = budget.limitAmount <= 0 ? 0.0 : (planned / budget.limitAmount).clamp(0.0, 1.0).toDouble();
            final categoryIndex = categories.indexWhere((category) => category.id == budget.categoryId);
            final categoryName = categoryIndex == -1 ? 'Todas as categorias' : categories[categoryIndex].name;
            final overLimit = planned > budget.limitAmount;
            return Card(
              child: ListTile(
                title: Text(budget.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${_monthLabel(budget.month)} • $categoryName'),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: ratio),
                    const SizedBox(height: 6),
                    Text('Previsto: ${_money(planned)}'),
                    Text('Pago: ${_money(paid)}'),
                    Text('${overLimit ? 'Estourado em' : 'Disponível previsto'}: ${_money(available.abs())}', style: TextStyle(color: overLimit ? Colors.red : Colors.green)),
                  ],
                ),
                trailing: Icon(overLimit ? Icons.warning_amber : Icons.check_circle_outline, color: overLimit ? Colors.red : Colors.green),
                onTap: () => _showBudgetDialog(budget: budget),
              ),
            );
          }),
      ],
    );
  }

  Widget _goalsTab(double totalTarget, double totalSaved) {
    final ratio = totalTarget <= 0 ? 0.0 : (totalSaved / totalTarget).clamp(0.0, 1.0).toDouble();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _summaryCard('Progresso geral das metas', '${(ratio * 100).toStringAsFixed(1)}%', Icons.flag, Colors.green),
        const SizedBox(height: 12),
        ElevatedButton.icon(onPressed: () => _showGoalDialog(), icon: const Icon(Icons.add), label: const Text('Adicionar meta')),
        const SizedBox(height: 12),
        if (_goals.where((g) => g.status != 'canceled').isEmpty)
          const _EmptyState(text: 'Nenhuma meta cadastrada ainda.')
        else
          ..._goals.where((goal) => goal.status != 'canceled').map((goal) {
            final goalRatio = goal.targetAmount <= 0 ? 0.0 : (goal.currentAmount / goal.targetAmount).clamp(0.0, 1.0).toDouble();
            final account = _accountById(goal.accountId);
            return Card(
              child: ListTile(
                isThreeLine: true,
                title: Text(goal.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (goal.description != null && goal.description!.isNotEmpty) Text(goal.description!, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('Guardado: ${_money(goal.currentAmount)} de ${_money(goal.targetAmount)}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(account == null ? 'Controle manual' : 'Conta de aporte: ${account.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: goalRatio),
                    if (goal.targetDate != null) Text('Prazo: ${_safeDateLabel(goal.targetDate)}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (account == null) const Text('Dica: vincule uma conta para registrar aportes.', style: TextStyle(fontSize: 12, color: Colors.orange), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
                trailing: SizedBox(
                  width: 76,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(child: Text('${(goalRatio * 100).toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                      if (account != null && goal.status != 'completed')
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.add_circle_outline, size: 22),
                          tooltip: 'Aportar',
                          onPressed: () => _showGoalDepositDialog(goal),
                        ),
                    ],
                  ),
                ),
                onTap: () => _showGoalDialog(goal: goal),
              ),
            );
          }),
      ],
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withOpacity(0.12), child: Icon(icon, color: color)),
        title: Text(title),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Future<void> _showAccountDialog({FinancialAccount? account}) async {
    final nameController = TextEditingController(text: account?.name ?? '');
    final balanceController = TextEditingController(text: account == null ? '' : account.initialBalance.toStringAsFixed(2));
    String type = account?.type ?? 'bank';
    bool archived = account?.isArchived ?? false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(account == null ? 'Nova conta' : 'Editar conta'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome da conta')),
                TextField(controller: balanceController, decoration: const InputDecoration(labelText: 'Saldo inicial/base', helperText: 'O saldo atual será calculado com as transações pagas desta conta.'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                DropdownButtonFormField<String>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: 'bank', child: Text('Banco')),
                    DropdownMenuItem(value: 'wallet', child: Text('Carteira/Dinheiro')),
                    DropdownMenuItem(value: 'credit_card', child: Text('Cartão')),
                    DropdownMenuItem(value: 'investment', child: Text('Investimento')),
                    DropdownMenuItem(value: 'other', child: Text('Outro')),
                  ],
                  onChanged: (value) { if (value != null) setLocal(() => type = value); },
                  decoration: const InputDecoration(labelText: 'Tipo'),
                ),
                if (account != null) SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Arquivar'), value: archived, onChanged: (v) => setLocal(() => archived = v)),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final baseBalance = double.tryParse(balanceController.text.replaceAll(',', '.'));
                if (name.isEmpty || baseBalance == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe nome e saldo inicial válido.')));
                  return;
                }
                final now = DateTime.now().toIso8601String();
                final data = FinancialAccount(id: account?.id, name: name, type: type, initialBalance: baseBalance, currentBalance: account?.currentBalance ?? baseBalance, isArchived: archived, createdAt: account?.createdAt ?? now, updatedAt: now);
                await FinancePlanningStore.upsertAccount(await ref.read(dbProvider).database, data);
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadAll();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    balanceController.dispose();
  }

  Future<void> _showBudgetDialog({Budget? budget}) async {
    final nameController = TextEditingController(text: budget?.name ?? '');
    final limitController = TextEditingController(text: budget == null ? '' : budget.limitAmount.toStringAsFixed(2));
    final monthController = TextEditingController(text: budget?.month ?? '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}');
    final categories = ref.read(financialCategoriesProvider).where((c) => c.type == 'expense' || c.type == 'both').toList();
    int? categoryId = categories.any((c) => c.id == budget?.categoryId) ? budget?.categoryId : null;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(budget == null ? 'Novo orçamento' : 'Editar orçamento'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome')),
              TextField(controller: limitController, decoration: const InputDecoration(labelText: 'Limite mensal'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              DropdownButtonFormField<int>(value: categoryId, items: [const DropdownMenuItem<int>(value: null, child: Text('Todas as categorias')), ...categories.map((c) => DropdownMenuItem<int>(value: c.id, child: Text(c.name)))], onChanged: (value) => setLocal(() => categoryId = value), decoration: const InputDecoration(labelText: 'Categoria')),
              TextField(controller: monthController, decoration: const InputDecoration(labelText: 'Mês (AAAA-MM)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final limit = double.tryParse(limitController.text.replaceAll(',', '.')) ?? 0;
                final month = monthController.text.trim();
                if (name.isEmpty || limit <= 0 || !_validMonth(month)) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe nome, limite maior que zero e mês válido.')));
                  return;
                }
                final now = DateTime.now().toIso8601String();
                final data = Budget(id: budget?.id, name: name, categoryId: categoryId, limitAmount: limit, month: month, isArchived: budget?.isArchived ?? false, createdAt: budget?.createdAt ?? now, updatedAt: now);
                await FinancePlanningStore.upsertBudget(await ref.read(dbProvider).database, data);
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadAll();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    limitController.dispose();
    monthController.dispose();
  }

  Future<void> _showGoalDialog({FinancialGoal? goal}) async {
    final nameController = TextEditingController(text: goal?.name ?? '');
    final descriptionController = TextEditingController(text: goal?.description ?? '');
    final targetController = TextEditingController(text: goal == null ? '' : goal.targetAmount.toStringAsFixed(2));
    final currentController = TextEditingController(text: goal == null ? '' : goal.currentAmount.toStringAsFixed(2));
    DateTime? targetDate = goal?.targetDate == null ? null : DateTime.tryParse(goal!.targetDate!);
    String status = goal?.status ?? 'active';
    int? accountId = _accounts.any((a) => !a.isArchived && a.id == goal?.accountId) ? goal?.accountId : null;
    final selectableAccounts = _accounts.where((account) => !account.isArchived).toList();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(goal == null ? 'Nova meta' : 'Editar meta'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome')),
              TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Descrição')),
              TextField(controller: targetController, decoration: const InputDecoration(labelText: 'Valor-alvo'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              TextField(controller: currentController, decoration: const InputDecoration(labelText: 'Valor atual/manual'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
              DropdownButtonFormField<int>(value: accountId, items: [const DropdownMenuItem<int>(value: null, child: Text('Sem conta vinculada')), ...selectableAccounts.map((a) => DropdownMenuItem<int>(value: a.id, child: Text(a.name)))], onChanged: (value) => setLocal(() => accountId = value), decoration: const InputDecoration(labelText: 'Conta para aportes')),
              OutlinedButton.icon(onPressed: () async { final picked = await showDatePicker(context: context, initialDate: targetDate ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100)); if (picked != null) setLocal(() => targetDate = picked); }, icon: const Icon(Icons.event), label: Text(targetDate == null ? 'Definir prazo' : _safeDateLabel(targetDate!.toIso8601String()))),
              DropdownButtonFormField<String>(value: status, items: const [DropdownMenuItem(value: 'active', child: Text('Ativa')), DropdownMenuItem(value: 'completed', child: Text('Concluída')), DropdownMenuItem(value: 'paused', child: Text('Pausada')), DropdownMenuItem(value: 'canceled', child: Text('Cancelada'))], onChanged: (value) { if (value != null) setLocal(() => status = value); }, decoration: const InputDecoration(labelText: 'Status')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final target = double.tryParse(targetController.text.replaceAll(',', '.')) ?? 0;
                final current = double.tryParse(currentController.text.replaceAll(',', '.')) ?? 0;
                if (name.isEmpty || target <= 0 || current < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe nome, alvo maior que zero e valor atual válido.')));
                  return;
                }
                final normalizedCurrent = current > target ? target : current;
                final normalizedStatus = normalizedCurrent >= target ? 'completed' : status;
                final now = DateTime.now().toIso8601String();
                final data = FinancialGoal(id: goal?.id, name: name, description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(), targetAmount: target, currentAmount: normalizedCurrent, accountId: accountId, targetDate: targetDate?.toIso8601String(), status: normalizedStatus, createdAt: goal?.createdAt ?? now, updatedAt: now);
                await FinancePlanningStore.upsertGoal(await ref.read(dbProvider).database, data);
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadAll();
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    nameController.dispose();
    descriptionController.dispose();
    targetController.dispose();
    currentController.dispose();
  }

  Future<void> _showGoalDepositDialog(FinancialGoal goal) async {
    final account = _accountById(goal.accountId);
    if (account == null || account.isArchived) return;
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Aportar em ${goal.name}'),
        content: TextField(controller: controller, decoration: InputDecoration(labelText: 'Valor do aporte', helperText: 'Será registrado como saída da conta ${account.name}.'), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
              if (amount <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um valor maior que zero.')));
                return;
              }
              final newCurrent = (goal.currentAmount + amount).clamp(0, goal.targetAmount).toDouble();
              final now = DateTime.now().toIso8601String();
              await ref.read(transactionsProvider.notifier).addTransaction(FinancialTransaction(title: 'Aporte - ${goal.name}', description: 'Aporte registrado pela meta financeira', amount: amount, type: 'expense', transactionDate: now, paidDate: now, accountId: account.id, paymentMethod: 'transferência', status: 'paid', notes: 'Aporte vinculado à meta ${goal.name}', createdAt: now, updatedAt: now));
              await FinancePlanningStore.upsertGoal(await ref.read(dbProvider).database, goal.copyWith(currentAmount: newCurrent, status: newCurrent >= goal.targetAmount ? 'completed' : goal.status, updatedAt: now));
              if (ctx.mounted) Navigator.pop(ctx);
              await ref.read(transactionsProvider.notifier).loadTransactions();
              await _loadAll();
            },
            child: const Text('Aportar'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  String _monthLabel(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    final parsedMonth = int.tryParse(parts[1]);
    return parsedMonth == null ? month : '${parsedMonth.toString().padLeft(2, '0')}/${parts[0]}';
  }

  IconData _accountIcon(String type) {
    switch (type) { case 'wallet': return Icons.account_balance_wallet; case 'credit_card': return Icons.credit_card; case 'investment': return Icons.trending_up; default: return Icons.account_balance; }
  }

  String _accountTypeLabel(String type) {
    switch (type) { case 'wallet': return 'Carteira/Dinheiro'; case 'credit_card': return 'Cartão'; case 'investment': return 'Investimento'; case 'other': return 'Outro'; default: return 'Banco'; }
  }

  String _safeDateLabel(String? raw) {
    if (raw == null) return 'Sem prazo';
    final date = DateTime.tryParse(raw);
    if (date == null) return 'Data inválida';
    return DateFormat('dd/MM/yyyy').format(date);
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 32), child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey))));
  }
}
