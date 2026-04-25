import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../data/models/financial_category_model.dart';
import '../../core/utils/icon_mapper.dart'; // we will create / reuse

class FinanceCategoriesScreen extends ConsumerWidget {
  const FinanceCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(financialCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorias Fin.'),
      ),
      body: ListView.builder(
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final color = Color(int.parse(cat.color));
          
          return ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Icon(Icons.category, color: color), // Simplified for now, can map real icons
            ),
            title: Text(cat.name),
            subtitle: Text(cat.type == 'income' ? 'Receita' : (cat.type == 'expense' ? 'Despesa' : 'Misto')),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => CreateFinanceCategoryScreen(category: cat)));
            },
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
  String _selectedColor = "0xFF9E9E9E";
  String _selectedIcon = "category";

  final List<String> _colors = [
    "0xFFF44336", "0xFFE91E63", "0xFF9C27B0", "0xFF673AB7",
    "0xFF3F51B5", "0xFF2196F3", "0xFF03A9F4", "0xFF00BCD4",
    "0xFF009688", "0xFF4CAF50", "0xFF8BC34A", "0xFFCDDC39",
    "0xFFFFEB3B", "0xFFFFC107", "0xFFFF9800", "0xFFFF5722",
    "0xFF795548", "0xFF9E9E9E", "0xFF607D8B",
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category == null ? 'Nova Categoria' : 'Editar Categoria'),
        actions: [
          if (widget.category != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                ref.read(financialCategoriesProvider.notifier).removeCategory(widget.category!.id!);
                Navigator.pop(context);
              },
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
                value: _type,
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
                final color = Color(int.parse(c));
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              onPressed: () {
                if (_nameController.text.isNotEmpty) {
                  final cat = FinancialCategory(
                    id: widget.category?.id,
                    name: _nameController.text,
                    type: _type,
                    color: _selectedColor,
                    icon: _selectedIcon,
                    createdAt: widget.category?.createdAt ?? DateTime.now().toIso8601String(),
                    updatedAt: DateTime.now().toIso8601String(),
                  );
                  if (widget.category == null) {
                    ref.read(financialCategoriesProvider.notifier).addCategory(cat);
                  } else {
                    ref.read(financialCategoriesProvider.notifier).updateCategory(cat);
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
