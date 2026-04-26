import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../data/models/category_model.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  void _showAddCategoryModal(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Nova Categoria', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nome da Categoria',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  if (name.isEmpty) return;

                  final exists = ref.read(categoriesProvider).any((c) => c.name.toLowerCase() == name.toLowerCase());
                  if (exists) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Já existe uma categoria com esse nome.')));
                    return;
                  }

                  final cat = TaskCategory(
                    name: name,
                    color: '0xFF2196F3',
                    createdAt: DateTime.now().toIso8601String(),
                  );
                  ref.read(categoriesProvider.notifier).addCategory(cat);
                  Navigator.pop(ctx);
                },
                child: const Text('Salvar'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    ).whenComplete(nameController.dispose);
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, TaskCategory category) {
    final categories = ref.read(categoriesProvider);
    if (categories.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mantenha pelo menos uma categoria para as tarefas.')));
      return;
    }
    if (category.id == null) return;

    final fallback = categories.firstWhere((c) => c.id != category.id, orElse: () => categories.first);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Categoria?'),
        content: Text('As tarefas vinculadas a "${category.name}" serão migradas para "${fallback.name}". Deseja continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              await ref.read(categoriesProvider.notifier).removeCategory(category.id!);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoria excluída com sucesso.')));
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Categorias')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCategoryModal(context, ref),
        child: const Icon(Icons.add),
      ),
      body: categories.isEmpty
          ? const Center(child: Text('Nenhuma categoria.'))
          : ListView.builder(
              itemCount: categories.length,
              itemBuilder: (ctx, i) {
                final cat = categories[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(int.tryParse(cat.color) ?? 0xFF2196F3),
                    child: Icon(
                      cat.icon == 'person' ? Icons.person : (cat.icon == 'work' ? Icons.work : Icons.folder),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(cat.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.grey),
                    onPressed: () => _confirmDelete(context, ref, cat),
                  ),
                );
              },
            ),
    );
  }
}
