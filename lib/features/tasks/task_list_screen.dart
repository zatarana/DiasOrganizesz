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
    final date = DateTime.tryParse(task.date ?? '');
    if (date == null) return false;
    if (task.time != null) {
      final parts = task.time!.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 23;
        final minute = int.tryParse(parts[1]) ?? 59;
        return DateTime(date.year, date.month, date.day, hour, minute).isBefore(DateTime.now());
      }
    }
    return DateTime(date.year, date.month, date.day, 23, 59, 59).isBefore(DateTime.now());
  }

  String _statusWhenReopened(Task task) => _isTaskOverdue(task) ? 'atrasada' : 'pendente';

  String _dateLabel(Task task) {
    final date = DateTime.tryParse(task.date ?? '');
    final formattedDate = date == null ? 'Sem data' : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    return task.time == null ? formattedDate : '$formattedDate ${task.time}';
  }

  String _recurrenceLabel(String recurrenceType) {
    switch (recurrenceType) {
      case 'daily':
        return 'Diária';
      case 'weekly':
        return 'Semanal';
      case 'monthly':
        return 'Mensal';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTasksRaw = ref.watch(tasksProvider).where((task) => task.status != 'canceled').toList();
    final parentTasks = allTasksRaw.where((task) => task.parentTaskId == null).toList()
      ..sort((a, b) {
        final ad = DateTime.tryParse(a.date ?? '') ?? DateTime(2100);
        final bd = DateTime.tryParse(b.date ?? '') ?? DateTime(2100);
        if (ad.compareTo(bd) != 0) return ad.compareTo(bd);
        return (a.time ?? '99:99').compareTo(b.time ?? '99:99');
      });

    final tasks = parentTasks.where((task) {
      final normalizedSearch = _searchQuery.trim().toLowerCase();
      final matchesSearch = normalizedSearch.isEmpty || task.title.toLowerCase().contains(normalizedSearch) || (task.description?.toLowerCase().contains(normalizedSearch) ?? false);
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: const InputDecoration(labelText: 'Buscar tarefas...', prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), isDense: true),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: ['Todas', 'Pendentes', 'Concluídas', 'Atrasadas'].map((filter) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(label: Text(filter), selected: _statusFilter == filter, onSelected: (_) => setState(() => _statusFilter = filter), visualDensity: VisualDensity.compact),
                  )).toList(),
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: tasks.isEmpty
                ? const Center(child: Text('Nenhuma tarefa encontrada.'))
                : ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (ctx, i) {
                      final task = tasks[i];
                      final isDone = task.status == 'concluida';
                      final isOverdue = task.status == 'atrasada';
                      final subtasks = allTasksRaw.where((sub) => sub.parentTaskId == task.id).toList();
                      final doneSubtasks = subtasks.where((sub) => sub.status == 'concluida').length;
                      final recurrence = _recurrenceLabel(task.recurrenceType);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          minLeadingWidth: 28,
                          title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(decoration: isDone ? TextDecoration.lineThrough : null, color: isOverdue ? Colors.red : null)),
                          subtitle: Text(
                            '${_dateLabel(task)} • ${task.priority}${recurrence.isEmpty ? '' : ' • $recurrence'}${subtasks.isEmpty ? '' : ' • Subtarefas $doneSubtasks/${subtasks.length}'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          leading: Icon(isDone ? Icons.check_circle : (isOverdue ? Icons.warning_amber : Icons.radio_button_unchecked), color: isDone ? Colors.green : (isOverdue ? Colors.red : Colors.grey), size: 22),
                          trailing: Checkbox(
                            value: isDone,
                            visualDensity: VisualDensity.compact,
                            onChanged: (val) {
                              ref.read(tasksProvider.notifier).updateTask(task.copyWith(status: val == true ? 'concluida' : _statusWhenReopened(task), updatedAt: DateTime.now().toIso8601String()));
                            },
                          ),
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: task))),
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
