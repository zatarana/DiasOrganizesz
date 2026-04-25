import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/riverpod_providers.dart';
import 'create_task_screen.dart';

class TaskListScreen extends ConsumerWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Todas as Tarefas')),
      body: tasks.isEmpty
          ? const Center(child: Text('Nenhuma tarefa cadastrada.'))
          : ListView.builder(
              itemCount: tasks.length,
              itemBuilder: (ctx, i) {
                final t = tasks[i];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(t.title, style: TextStyle(decoration: t.status == 'concluida' ? TextDecoration.lineThrough : null)),
                    subtitle: Text('${t.date} ${t.time ?? ""} - Priority: ${t.priority}'),
                    trailing: Checkbox(
                      value: t.status == 'concluida',
                      onChanged: (val) {
                        ref.read(tasksProvider.notifier).updateTask(
                          t.copyWith(status: val == true ? 'concluida' : 'pendente')
                        );
                      },
                    ),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: t)));
                    },
                  ),
                );
              },
            ),
    );
  }
}
