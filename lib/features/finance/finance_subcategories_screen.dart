import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database/finance_planning_store.dart';
import '../../data/models/financial_category_model.dart';
import '../../data/models/financial_subcategory_model.dart';
import '../../domain/providers.dart';

class FinanceSubcategoriesScreen extends ConsumerStatefulWidget {
  final FinancialCategory category;

  const FinanceSubcategoriesScreen({super.key, required this.category});

  @override
  ConsumerState<FinanceSubcategoriesScreen> createState() => _FinanceSubcategoriesScreenState();
}

class _FinanceSubcategoriesScreenState extends ConsumerState<FinanceSubcategoriesScreen> {
  bool _loading = true;
  List<FinancialSubcategory> _subcategories = [];

  @override
  void initState() {
    super.initState();
    _loadSubcategories();
  }

  Future<void> _loadSubcategories() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final db = await ref.read(dbProvider).database;
    final items = await FinancePlanningStore.getSubcategories(db, categoryId: widget.category.id, includeArchived: true);
    if (!mounted) return;
    setState(() {
      _subcategories = items;
      _loading = false;
    });
  }

  Future<void> _showSubcategoryDialog({FinancialSubcategory? subcategory}) async {
    if (widget.category.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Salve a categoria antes de criar subcategorias.')));
      return;
    }

    final nameController = TextEditingController(text: subcategory?.name ?? '');
    bool isArchived = subcategory?.isArchived ?? false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(subcategory == null ? 'Nova subcategoria' : 'Editar subcategoria'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Nome da subcategoria'),
                ),
                if (subcategory != null && !subcategory.isDefault)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Arquivar'),
                    subtitle: const Text('Mantém histórico, mas remove dos novos lançamentos.'),
                    value: isArchived,
                    onChanged: (value) => setLocal(() => isArchived = value),
                  ),
                if (subcategory?.isDefault == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'A subcategoria padrão "Outros" não pode ser arquivada.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o nome da subcategoria.')));
                  return;
                }

                final duplicate = _subcategories.any((item) {
                  final sameName = item.name.toLowerCase() == name.toLowerCase();
                  final differentId = item.id != subcategory?.id;
                  return sameName && differentId && item.categoryId == widget.category.id;
                });
                if (duplicate) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Já existe uma subcategoria com esse nome nesta categoria.')));
                  return;
                }

                final now = DateTime.now().toIso8601String();
                final data = FinancialSubcategory(
                  id: subcategory?.id,
                  categoryId: widget.category.id!,
                  name: name,
                  isDefault: subcategory?.isDefault ?? false,
                  isArchived: subcategory?.isDefault == true ? false : isArchived,
                  createdAt: subcategory?.createdAt ?? now,
                  updatedAt: now,
                );
                await FinancePlanningStore.upsertSubcategory(await ref.read(dbProvider).database, data);
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    if (saved == true) await _loadSubcategories();
  }

  Future<void> _archiveSubcategory(FinancialSubcategory subcategory) async {
    if (subcategory.id == null) return;
    if (subcategory.isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A subcategoria padrão não pode ser arquivada.')));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arquivar subcategoria?'),
        content: Text('Transações e orçamentos vinculados a "${subcategory.name}" ficarão sem subcategoria. Deseja continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Arquivar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed != true) return;
    await FinancePlanningStore.archiveSubcategory(await ref.read(dbProvider).database, subcategory.id!);
    await ref.read(transactionsProvider.notifier).loadTransactions();
    await _loadSubcategories();
  }

  @override
  Widget build(BuildContext context) {
    final active = _subcategories.where((item) => !item.isArchived).toList();
    final archived = _subcategories.where((item) => item.isArchived).toList();

    return Scaffold(
      appBar: AppBar(title: Text('Subcategorias — ${widget.category.name}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.account_tree_outlined)),
                    title: Text(widget.category.name),
                    subtitle: Text(_typeLabel(widget.category.type)),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => _showSubcategoryDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova subcategoria'),
                ),
                const SizedBox(height: 16),
                const Text('Ativas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (active.isEmpty)
                  const _EmptySubcategoryState(text: 'Nenhuma subcategoria ativa ainda.')
                else
                  ...active.map((item) => _SubcategoryTile(
                        subcategory: item,
                        onTap: () => _showSubcategoryDialog(subcategory: item),
                        onArchive: item.isDefault ? null : () => _archiveSubcategory(item),
                      )),
                if (archived.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Arquivadas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...archived.map((item) => _SubcategoryTile(
                        subcategory: item,
                        onTap: () => _showSubcategoryDialog(subcategory: item),
                        onArchive: null,
                      )),
                ],
              ],
            ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'income':
        return 'Categoria de receita';
      case 'expense':
        return 'Categoria de despesa';
      default:
        return 'Categoria mista';
    }
  }
}

class _SubcategoryTile extends StatelessWidget {
  final FinancialSubcategory subcategory;
  final VoidCallback onTap;
  final VoidCallback? onArchive;

  const _SubcategoryTile({required this.subcategory, required this.onTap, required this.onArchive});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: subcategory.isArchived ? Colors.grey.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.12),
          child: Icon(subcategory.isDefault ? Icons.label_important_outline : Icons.label_outline, color: subcategory.isArchived ? Colors.grey : Colors.blue),
        ),
        title: Row(
          children: [
            Expanded(child: Text(subcategory.name)),
            if (subcategory.isDefault) const Chip(label: Text('Padrão'), visualDensity: VisualDensity.compact),
            if (subcategory.isArchived) const Padding(padding: EdgeInsets.only(left: 4), child: Chip(label: Text('Arquivada'), visualDensity: VisualDensity.compact)),
          ],
        ),
        subtitle: Text(subcategory.isDefault ? 'Usada como fallback para lançamentos sem detalhamento.' : 'Toque para editar.'),
        trailing: onArchive == null ? null : IconButton(icon: const Icon(Icons.archive_outlined), onPressed: onArchive),
        onTap: onTap,
      ),
    );
  }
}

class _EmptySubcategoryState extends StatelessWidget {
  final String text;
  const _EmptySubcategoryState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(child: Text(text, style: const TextStyle(color: Colors.grey))),
    );
  }
}
