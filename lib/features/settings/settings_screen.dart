import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import 'categories_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Geral', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Categorias'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Tema'),
            subtitle: const Text('Alterar tema atual'),
            trailing: const Icon(Icons.expand_more),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comportamento de tema automático do sistema.')));
            },
          ),
          const Divider(),
          const Padding(padding: EdgeInsets.all(16), child: Text('Gerenciamento', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('Limpar Concluídas'),
            subtitle: const Text('Remove todas as tarefas já marcadas como concluídas'),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirmar Exclusão'),
                  content: const Text('Deseja realmente remover todas as tarefas concluídas? Esta ação não pode ser desfeita.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                    TextButton(
                      onPressed: () {
                        ref.read(tasksProvider.notifier).clearCompletedTasks();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarefas limpas com sucesso!')));
                      }, 
                      child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.warning, color: Colors.red),
            title: const Text('Resetar Aplicativo', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Apaga todas as tarefas e dados.'),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Resetar Tudo?'),
                  content: const Text('Deseja apagar todas as tarefas? As categorias padrões serão mantidas.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                    TextButton(
                      onPressed: () async {
                        final tasks = ref.read(tasksProvider);
                        for (var t in tasks) {
                           if (t.id != null) await ref.read(tasksProvider.notifier).removeTask(t.id!);
                        }
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aplicativo resetado.')));
                      },
                      child: const Text('Apagar Tudo', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          const Padding(padding: EdgeInsets.all(16), child: Text('Sistema', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.data_usage),
            title: const Text('Uso de Dados'),
            subtitle: const Text('Offline-first habilitado. Tudo salvo localmente no SQLite.'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Sobre'),
            subtitle: const Text('DiasOrganize v1.0.0\nCompilado offline via GitHub Actions'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
