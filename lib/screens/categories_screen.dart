import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/riverpod_providers.dart';
import '../models/category_model.dart';

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
                    final cat = TaskCategory(name: nameController.text, color: 0xFF2196F3);
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
                    backgroundColor: Color(cat.color),
                    child: Icon(
                      cat.icon == 'person' ? Icons.person : (cat.icon == 'work' ? Icons.work : Icons.folder),
                      color: Colors.white,
                    ),
                  ),
                  title: Text(cat.name),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      ref.read(categoriesProvider.notifier).removeCategory(cat.id!);
                    },
                  ),
                );
              },
            ),
    );
  }
}
