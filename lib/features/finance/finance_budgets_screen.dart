import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/finance_planning_store.dart';
import '../../data/models/budget_model.dart';
import '../../data/models/financial_category_model.dart';
import '../../data/models/financial_subcategory_model.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/providers.dart';
import 'finance_budget_rules.dart';

class FinanceBudgetsScreen extends ConsumerStatefulWidget {
  const FinanceBudgetsScreen({super.key});

  @override
  ConsumerState<FinanceBudgetsScreen> createState() => _FinanceBudgetsScreenState();
}

class _FinanceBudgetsScreenState extends ConsumerState<FinanceBudgetsScreen> {
  bool _loading = true;
  List<Budget> _budgets = [];
  List<FinancialSubcategory> _subcategories = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final db = await ref.read(dbProvider).database;
    final budgets = await FinancePlanningStore.getBudgets(db);
    final subcategories = await FinancePlanningStore.getSubcategories(db, includeArchived: true);
    if (!mounted) return;
    setState(() {
      _budgets = budgets;
      _subcategories = subcategories;
      _loading = false;
    });
  }

  String _money(num value) => 'R\$ ${value.toDouble().toStringAsFixed(2)}';

  bool _validMonth(String value) {
    if (!RegExp(r'^\d{4}-\d{2}$').hasMatch(value)) return false;
    final month = int.tryParse(value.split('-')[1]) ?? 0;
    return month >= 1 && month <= 12;
  }

  String _currentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  String _monthLabel(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    return '${parts[1]}/${parts[0]}';
  }

  FinancialCategory? _categoryById(List<FinancialCategory> categories, int? id) {
    if (id == null) return null;
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  FinancialSubcategory? _subcategoryById(int? id) {
    if (id == null) return null;
    for (final subcategory in _subcategories) {
      if (subcategory.id == id) return subcategory;
    }
    return null;
  }

  List<FinancialSubcategory> _subcategoriesForCategory(int? categoryId, {int? keepId}) {
    if (categoryId == null) return [];
    return _subcategories
        .where((subcategory) => subcategory.categoryId == categoryId && (!subcategory.isArchived || subcategory.id == keepId))
        .toList();
  }

  String _scopeLabel(Budget budget, List<FinancialCategory> categories) {
    final category = _categoryById(categories, budget.categoryId);
    final subcategory = _subcategoryById(budget.subcategoryId);
    if (category == null) return 'Todas as categorias';
    if (subcategory == null) return category.name;
    return '${category.name} / ${subcategory.name}${subcategory.isArchived ? ' (arquivada)' : ''}';
  }

  Future<void> _showBudgetDialog({Budget? budget}) async {
    final categories = ref.read(financialCategoriesProvider).where((category) => category.type == 'expense' || category.type == 'both').toList();
    final nameController = TextEditingController(text: budget?.name ?? '');
    final limitController = TextEditingController(text: budget == null ? '' : budget.limitAmount.toStringAsFixed(2));
    final monthController = TextEditingController(text: budget?.month ?? _currentMonth());
    int? categoryId = categories.any((category) => category.id == budget?.categoryId) ? budget?.categoryId : null;
    int? subcategoryId = _subcategoriesForCategory(categoryId, keepId: budget?.subcategoryId).any((item) => item.id == budget?.subcategoryId)
        ? budget?.subcategoryId
        : null;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final selectableSubcategories = _subcategoriesForCategory(categoryId, keepId: budget?.subcategoryId);
          final safeSubcategoryId = selectableSubcategories.any((item) => item.id == subcategoryId) ? subcategoryId : null;

          return AlertDialog(
            title: Text(budget == null ? 'Novo orçamento' : 'Editar orçamento'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome')),
                  TextField(
                    controller: limitController,
                    decoration: const InputDecoration(labelText: 'Limite mensal', prefixText: 'R\$ '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: categoryId,
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('Todas as categorias')),
                      ...categories.map((category) => DropdownMenuItem<int>(value: category.id, child: Text(category.name))),
                    ],
                    onChanged: (value) => setLocal(() {
                      categoryId = value;
                      if (!_subcategoriesForCategory(value, keepId: budget?.subcategoryId).any((item) => item.id == subcategoryId)) {
                        subcategoryId = null;
                      }
                    }),
                    decoration: const InputDecoration(labelText: 'Categoria'),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: safeSubcategoryId,
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('Todas as subcategorias')),
                      ...selectableSubcategories.map((subcategory) => DropdownMenuItem<int>(
                            value: subcategory.id,
                            child: Text('${subcategory.name}${subcategory.isArchived ? ' (arquivada)' : ''}'),
                          )),
                    ],
                    onChanged: categoryId == null ? null : (value) => setLocal(() => subcategoryId = value),
                    decoration: InputDecoration(
                      labelText: 'Subcategoria',
                      helperText: categoryId == null ? 'Escolha uma categoria para limitar por subcategoria.' : null,
                    ),
                  ),
                  TextField(controller: monthController, decoration: const InputDecoration(labelText: 'Mês (AAAA-MM)')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              TextButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final limit = double.tryParse(limitController.text.replaceAll(',', '.')) ?? 0;
                  final month = monthController.text.trim();
                  final safeSubcategory = _subcategoriesForCategory(categoryId, keepId: budget?.subcategoryId).any((item) => item.id == subcategoryId)
                      ? subcategoryId
                      : null;

                  if (name.isEmpty || limit <= 0 || !_validMonth(month)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe nome, limite maior que zero e mês válido.')));
                    return;
                  }
                  if (safeSubcategory != null && categoryId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subcategoria exige uma categoria.')));
                    return;
                  }

                  final now = DateTime.now().toIso8601String();
                  final data = Budget(
                    id: budget?.id,
                    name: name,
                    categoryId: categoryId,
                    subcategoryId: safeSubcategory,
                    limitAmount: limit,
                    month: month,
                    isArchived: budget?.isArchived ?? false,
                    createdAt: budget?.createdAt ?? now,
                    updatedAt: now,
                  );
                  await FinancePlanningStore.upsertBudget(await ref.read(dbProvider).database, data);
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
    limitController.dispose();
    monthController.dispose();
    if (saved == true) await _loadAll();
  }

  Future<void> _archiveBudget(Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arquivar orçamento?'),
        content: Text('O orçamento "${budget.name}" será removido da lista ativa, mas preservado no banco.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Arquivar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    await FinancePlanningStore.upsertBudget(
      await ref.read(dbProvider).database,
      budget.copyWith(isArchived: true, updatedAt: DateTime.now().toIso8601String()),
    );
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(financialCategoriesProvider);
    final transactions = ref.watch(transactionsProvider);
    final activeBudgets = _budgets.where((budget) => !budget.isArchived).toList();
    final usages = FinanceBudgetRules.usageForAll(activeBudgets, transactions);

    return Scaffold(
      appBar: AppBar(title: const Text('Orçamentos')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ElevatedButton.icon(
                  onPressed: () => _showBudgetDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Novo orçamento'),
                ),
                const SizedBox(height: 12),
                if (usages.isEmpty)
                  const _BudgetEmptyState()
                else
                  ...usages.map((usage) => _BudgetUsageCard(
                        usage: usage,
                        scopeLabel: _scopeLabel(usage.budget, categories),
                        money: _money,
                        monthLabel: _monthLabel,
                        onTap: () => _showBudgetDialog(budget: usage.budget),
                        onArchive: () => _archiveBudget(usage.budget),
                      )),
              ],
            ),
    );
  }
}

class _BudgetUsageCard extends StatelessWidget {
  final FinanceBudgetUsage usage;
  final String scopeLabel;
  final String Function(num value) money;
  final String Function(String month) monthLabel;
  final VoidCallback onTap;
  final VoidCallback onArchive;

  const _BudgetUsageCard({
    required this.usage,
    required this.scopeLabel,
    required this.money,
    required this.monthLabel,
    required this.onTap,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final color = usage.isOverPlanned ? Colors.red : Colors.green;
    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(usage.budget.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${monthLabel(usage.budget.month)} • $scopeLabel'),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: usage.plannedRatio),
            const SizedBox(height: 6),
            Text('Limite: ${money(usage.budget.limitAmount)}'),
            Text('Previsto: ${money(usage.plannedAmount)}'),
            Text('Pago: ${money(usage.paidAmount)}'),
            Text(
              '${usage.isOverPlanned ? 'Estourado em' : 'Disponível previsto'}: ${money(usage.availableAmount.abs())}',
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'archive') onArchive();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'archive', child: Text('Arquivar')),
          ],
        ),
      ),
    );
  }
}

class _BudgetEmptyState extends StatelessWidget {
  const _BudgetEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Text('Nenhum orçamento cadastrado ainda.', style: TextStyle(color: Colors.grey)),
      ),
    );
  }
}
