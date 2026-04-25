import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import 'create_task_screen.dart';

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'Todas';

  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(tasksProvider);
    
    final tasks = allTasks.where((t) {
      final matchesSearch = t.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                            (t.description?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      
      bool matchesStatus = true;
      if (_statusFilter == 'Pendentes') matchesStatus = t.status == 'pendente';
      if (_statusFilter == 'Concluídas') matchesStatus = t.status == 'concluida';
      if (_statusFilter == 'Atrasadas') matchesStatus = t.status == 'atrasada';

      return matchesSearch && matchesStatus;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Tarefas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar tarefas...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: ['Todas', 'Pendentes', 'Concluídas', 'Atrasadas'].map((f) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(f),
                    selected: _statusFilter == f,
                    onSelected: (val) => setState(() => _statusFilter = f),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: tasks.isEmpty
                ? const Center(child: Text('Nenhuma tarefa encontrada.'))
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (ctx, i) {
                      final t = tasks[i];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(t.title, style: TextStyle(decoration: t.status == 'concluida' ? TextDecoration.lineThrough : null)),
                          subtitle: Text('${t.date} ${t.time ?? ""} - Prioridade: ${t.priority}'),
                          trailing: Checkbox(
                            value: t.status == 'concluida',
                            onChanged: (val) {
                              ref.read(tasksProvider.notifier).updateTask(
                                t.copyWith(
                                  status: val == true ? 'concluida' : 'pendente',
                                  updatedAt: DateTime.now().toIso8601String()
                                )
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
          ),
        ],
      ),
    );
  }
}
