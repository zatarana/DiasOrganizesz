import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../data/models/category_model.dart';
import '../../data/models/task_model.dart';

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
                  if (nameController.text.isNotEmpty) {
                    final cat = TaskCategory(name: nameController.text, color: '0xFF2196F3', createdAt: DateTime.now().toIso8601String());
                    ref.read(categoriesProvider.notifier).addCategory(cat);
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Salvar'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, int categoryId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Categoria?'),
        content: const Text('As tarefas vinculadas a esta categoria serão migradas para a categoria Pessoal. Deseja continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              // Migrar tarefas para a primeira categoria padrão (id=1 que geralmente é Pessoal)
              final tasks = ref.read(tasksProvider);
              for (var t in tasks) {
                if (t.categoryId == categoryId) {
                   ref.read(tasksProvider.notifier).updateTask(t.copyWith(categoryId: 1));
                }
              }
              // Deletar categoria
              ref.read(categoriesProvider.notifier).removeCategory(categoryId);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Categoria excluída com sucesso.')));
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
                    backgroundColor: Color(int.parse(cat.color)),
                    child: Icon(
                      cat.icon == 'person' ? Icons.person : (cat.icon == 'work' ? Icons.work : Icons.folder),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(cat.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.grey),
                    onPressed: () => _confirmDelete(context, ref, cat.id!),
                  ),
                );
              },
            ),
    );
  }
}
