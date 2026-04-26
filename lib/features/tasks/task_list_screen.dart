import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../data/models/task_model.dart';
import 'create_task_screen.dart';

class TaskListScreen extends ConsumerStatefulWidget {
  const TaskListScreen({super.key});

  @override
  ConsumerState<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends ConsumerState<TaskListScreen> {
  String _searchQuery = '';
  String _statusFilter = 'Todas';

  bool _isTaskOverdue(Task task) {
    if (task.date == null) return false;
    final date = DateTime.tryParse(task.date!);
    if (date == null) return false;

    if (task.time != null) {
      final parts = task.time!.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 23;
        final minute = int.tryParse(parts[1]) ?? 59;
        return DateTime(date.year, date.month, date.day, hour, minute).isBefore(DateTime.now());
      }
    }

    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);
    return endOfDay.isBefore(DateTime.now());
  }

  String _statusWhenReopened(Task task) => _isTaskOverdue(task) ? 'atrasada' : 'pendente';

  String _formatTaskSubtitle(Task task) {
    final date = task.date ?? 'Sem data';
    final time = task.time == null ? '' : ' às ${task.time}';
    return '$date$time • Prioridade: ${task.priority} • ${task.status}';
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(tasksProvider).where((task) => task.status != 'canceled').toList()
      ..sort((a, b) {
        final ad = DateTime.tryParse(a.date ?? '') ?? DateTime(2100);
        final bd = DateTime.tryParse(b.date ?? '') ?? DateTime(2100);
        if (ad.compareTo(bd) != 0) return ad.compareTo(bd);
        return (a.time ?? '99:99').compareTo(b.time ?? '99:99');
      });

    final tasks = allTasks.where((task) {
      final normalizedSearch = _searchQuery.trim().toLowerCase();
      final matchesSearch = normalizedSearch.isEmpty ||
          task.title.toLowerCase().contains(normalizedSearch) ||
          (task.description?.toLowerCase().contains(normalizedSearch) ?? false);

      bool matchesStatus = true;
      if (_statusFilter == 'Pendentes') matchesStatus = task.status == 'pendente';
      if (_statusFilter == 'Concluídas') matchesStatus = task.status == 'concluida';
      if (_statusFilter == 'Atrasadas') matchesStatus = task.status == 'atrasada';

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
              children: ['Todas', 'Pendentes', 'Concluídas', 'Atrasadas'].map((filter) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(filter),
                    selected: _statusFilter == filter,
                    onSelected: (_) => setState(() => _statusFilter = filter),
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
                      final task = tasks[i];
                      final isDone = task.status == 'concluida';
                      final isOverdue = task.status == 'atrasada';

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          title: Text(
                            task.title,
                            style: TextStyle(
                              decoration: isDone ? TextDecoration.lineThrough : null,
                              color: isOverdue ? Colors.red : null,
                            ),
                          ),
                          subtitle: Text(_formatTaskSubtitle(task)),
                          leading: Icon(
                            isDone ? Icons.check_circle : (isOverdue ? Icons.warning_amber : Icons.radio_button_unchecked),
                            color: isDone ? Colors.green : (isOverdue ? Colors.red : Colors.grey),
                          ),
                          trailing: Checkbox(
                            value: isDone,
                            onChanged: (val) {
                              final updated = task.copyWith(
                                status: val == true ? 'concluida' : _statusWhenReopened(task),
                                updatedAt: DateTime.now().toIso8601String(),
                              );
                              ref.read(tasksProvider.notifier).updateTask(updated);
                            },
                          ),
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: task)));
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
