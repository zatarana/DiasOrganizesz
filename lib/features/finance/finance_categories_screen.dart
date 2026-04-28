import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../data/models/financial_category_model.dart';
import '../../core/utils/icon_mapper.dart';
import 'finance_subcategories_screen.dart';

class FinanceCategoriesScreen extends ConsumerWidget {
  const FinanceCategoriesScreen({super.key});

  Color _safeColor(String rawColor) => Color(int.tryParse(rawColor) ?? 0xFF9E9E9E);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(financialCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categorias Fin.')),
      body: categories.isEmpty
          ? const Center(child: Text('Nenhuma categoria financeira.'))
          : ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final cat = categories[index];
                final color = _safeColor(cat.color);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.2),
                      child: Icon(IconMapper.fromName(cat.icon), color: color),
                    ),
                    title: Text(cat.name),
                    subtitle: Text('${cat.type == 'income' ? 'Receita' : (cat.type == 'expense' ? 'Despesa' : 'Misto')} • toque para editar'),
                    trailing: IconButton(
                      tooltip: 'Subcategorias',
                      icon: const Icon(Icons.account_tree_outlined),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => FinanceSubcategoriesScreen(category: cat)));
                      },
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => CreateFinanceCategoryScreen(category: cat)));
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateFinanceCategoryScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class CreateFinanceCategoryScreen extends ConsumerStatefulWidget {
  final FinancialCategory? category;
  const CreateFinanceCategoryScreen({super.key, this.category});

  @override
  ConsumerState<CreateFinanceCategoryScreen> createState() => _CreateFinanceCategoryScreenState();
}

class _CreateFinanceCategoryScreenState extends ConsumerState<CreateFinanceCategoryScreen> {
  final _nameController = TextEditingController();
  String _type = 'both';
  String _selectedColor = '0xFF9E9E9E';
  String _selectedIcon = 'category';

  final List<String> _colors = [
    '0xFFF44336',
    '0xFFE91E63',
    '0xFF9C27B0',
    '0xFF673AB7',
    '0xFF3F51B5',
    '0xFF2196F3',
    '0xFF03A9F4',
    '0xFF00BCD4',
    '0xFF009688',
    '0xFF4CAF50',
    '0xFF8BC34A',
    '0xFFCDDC39',
    '0xFFFFEB3B',
    '0xFFFFC107',
    '0xFFFF9800',
    '0xFFFF5722',
    '0xFF795548',
    '0xFF9E9E9E',
    '0xFF607D8B',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.category != null) {
      _nameController.text = widget.category!.name;
      _type = widget.category!.type;
      _selectedColor = widget.category!.color;
      _selectedIcon = widget.category!.icon;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _confirmDelete() {
    final category = widget.category;
    if (category?.id == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir categoria financeira?'),
        content: Text('Movimentações, subcategorias, orçamentos e dívidas vinculadas a "${category!.name}" ficarão sem categoria. Deseja continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              await ref.read(financialCategoriesProvider.notifier).removeCategory(category.id!);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o nome da categoria.')));
      return;
    }

    final duplicate = ref.read(financialCategoriesProvider).any((category) {
      final sameName = category.name.toLowerCase() == name.toLowerCase();
      final differentId = category.id != widget.category?.id;
      return sameName && differentId;
    });

    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Já existe uma categoria financeira com esse nome.')));
      return;
    }

    final cat = FinancialCategory(
      id: widget.category?.id,
      name: name,
      type: _type,
      color: _selectedColor,
      icon: _selectedIcon,
      createdAt: widget.category?.createdAt ?? DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    if (widget.category == null) {
      await ref.read(financialCategoriesProvider.notifier).addCategory(cat);
    } else {
      await ref.read(financialCategoriesProvider.notifier).updateCategory(cat);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null ? 'Nova Categoria' : 'Editar Categoria'),
        actions: [
          if (widget.category?.id != null)
            IconButton(
              tooltip: 'Subcategorias',
              icon: const Icon(Icons.account_tree_outlined),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => FinanceSubcategoriesScreen(category: widget.category!)));
              },
            ),
          if (widget.category != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
            )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome da Categoria', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _type,
              items: const [
                DropdownMenuItem(value: 'income', child: Text('Apenas Receitas')),
                DropdownMenuItem(value: 'expense', child: Text('Apenas Despesas')),
                DropdownMenuItem(value: 'both', child: Text('Misto (Receitas e Despesas)')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _type = v);
              },
              decoration: const InputDecoration(labelText: 'Tipo de Categoria', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            const Text('Cor:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _colors.map((c) {
                final isSelected = c == _selectedColor;
                final color = Color(int.tryParse(c) ?? 0xFF9E9E9E);
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = c),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected ? Border.all(color: Colors.black, width: 3) : null,
                    ),
                  ),
                );
              }).toList(),
            ),
            const Spacer(),
            if (widget.category?.id != null) ...[
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => FinanceSubcategoriesScreen(category: widget.category!)));
                },
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('Gerenciar subcategorias'),
              ),
              const SizedBox(height: 8),
            ],
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: _save,
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
