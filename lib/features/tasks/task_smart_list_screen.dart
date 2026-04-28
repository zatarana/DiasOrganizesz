import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/task_model.dart';
import '../../domain/providers.dart';
import 'create_task_screen.dart';
import 'task_smart_rules.dart';

class TaskSmartListScreen extends ConsumerWidget {
  final TaskSmartListType type;

  const TaskSmartListScreen({super.key, required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(tasksProvider);
    final now = DateTime.now();
    final tasks = _tasksForType(allTasks, now);
    final title = _titleForType(type);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: tasks.isEmpty
          ? _TaskSmartEmptyState(type: type)
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _TaskSmartTile(
                  task: task,
                  onToggle: () {
                    final reopenedStatus = TaskSmartRules.isOverdue(task) ? 'atrasada' : 'pendente';
                    final nextStatus = TaskSmartRules.isCompleted(task) ? reopenedStatus : 'concluida';
                    ref.read(tasksProvider.notifier).updateTask(
                          task.copyWith(status: nextStatus, updatedAt: DateTime.now().toIso8601String()),
                        );
                  },
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: task))),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(selectedDate: _suggestedDate(type)))),
        icon: const Icon(Icons.add),
        label: const Text('Nova tarefa'),
      ),
    );
  }

  List<Task> _tasksForType(List<Task> allTasks, DateTime now) {
    switch (type) {
      case TaskSmartListType.today:
        return TaskSmartRules.todayTasks(allTasks, now: now);
      case TaskSmartListType.inbox:
        return TaskSmartRules.inboxTasks(allTasks);
      case TaskSmartListType.nextSevenDays:
        final filtered = allTasks.where((task) => TaskSmartRules.isNextSevenDays(task, now: now) && TaskSmartRules.isParentTask(task)).toList();
        filtered.sort(TaskSmartRules.compareByScheduleAndPriority);
        return filtered;
      case TaskSmartListType.overdue:
        final filtered = allTasks.where((task) => TaskSmartRules.isOverdue(task, now: now) && TaskSmartRules.isParentTask(task)).toList();
        filtered.sort(TaskSmartRules.compareByScheduleAndPriority);
        return filtered;
      case TaskSmartListType.noDate:
        final filtered = allTasks.where((task) => TaskSmartRules.isNoDate(task) && TaskSmartRules.isParentTask(task)).toList();
        filtered.sort(TaskSmartRules.compareByScheduleAndPriority);
        return filtered;
      case TaskSmartListType.highPriority:
        final filtered = allTasks.where((task) => TaskSmartRules.isActive(task) && TaskSmartRules.isParentTask(task) && task.priority == 'alta').toList();
        filtered.sort(TaskSmartRules.compareByScheduleAndPriority);
        return filtered;
      case TaskSmartListType.allActive:
        return TaskSmartRules.parentTasks(allTasks, includeCompleted: false);
      case TaskSmartListType.completed:
        final filtered = allTasks.where((task) => TaskSmartRules.isCompleted(task) && TaskSmartRules.isParentTask(task)).toList();
        filtered.sort(TaskSmartRules.compareByScheduleAndPriority);
        return filtered;
    }
  }

  String _titleForType(TaskSmartListType type) {
    switch (type) {
      case TaskSmartListType.today:
        return 'Hoje';
      case TaskSmartListType.inbox:
        return 'Inbox';
      case TaskSmartListType.nextSevenDays:
        return 'Próximos 7 dias';
      case TaskSmartListType.overdue:
        return 'Atrasadas';
      case TaskSmartListType.noDate:
        return 'Sem data';
      case TaskSmartListType.highPriority:
        return 'Alta prioridade';
      case TaskSmartListType.allActive:
        return 'Todas ativas';
      case TaskSmartListType.completed:
        return 'Concluídas';
    }
  }

  DateTime? _suggestedDate(TaskSmartListType type) {
    switch (type) {
      case TaskSmartListType.today:
        return DateTime.now();
      case TaskSmartListType.nextSevenDays:
        return DateTime.now().add(const Duration(days: 1));
      default:
        return null;
    }
  }
}

enum TaskSmartListType {
  today,
  inbox,
  nextSevenDays,
  overdue,
  noDate,
  highPriority,
  allActive,
  completed,
}

class _TaskSmartTile extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  const _TaskSmartTile({required this.task, required this.onTap, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final done = TaskSmartRules.isCompleted(task);
    final overdue = TaskSmartRules.isOverdue(task);
    final scheduled = TaskSmartRules.scheduledDateTime(task);
    final dateLabel = scheduled == null
        ? 'Sem data'
        : '${scheduled.day.toString().padLeft(2, '0')}/${scheduled.month.toString().padLeft(2, '0')}${TaskSmartRules.hasTime(task) ? ' ${task.time}' : ''}';

    return Card(
      child: ListTile(
        leading: IconButton(
          icon: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? Colors.green : overdue ? Colors.red : Colors.grey),
          onPressed: onToggle,
        ),
        title: Text(
          task.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(decoration: done ? TextDecoration.lineThrough : null),
        ),
        subtitle: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            _MiniBadge(icon: Icons.event, label: dateLabel, color: overdue ? Colors.red : Colors.blueGrey),
            _MiniBadge(icon: Icons.flag, label: task.priority, color: _priorityColor(task.priority)),
            if (task.projectId != null) const _MiniBadge(icon: Icons.rocket_launch, label: 'Projeto', color: Colors.purple),
            if (task.recurrenceType != 'none') const _MiniBadge(icon: Icons.repeat, label: 'Recorrente', color: Colors.indigo),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'alta':
        return Colors.red;
      case 'media':
        return Colors.orange;
      case 'baixa':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

class _MiniBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _TaskSmartEmptyState extends StatelessWidget {
  final TaskSmartListType type;

  const _TaskSmartEmptyState({required this.type});

  @override
  Widget build(BuildContext context) {
    final title = switch (type) {
      TaskSmartListType.today => 'Nada para hoje.',
      TaskSmartListType.inbox => 'Inbox limpo.',
      TaskSmartListType.nextSevenDays => 'Nada nos próximos 7 dias.',
      TaskSmartListType.overdue => 'Nenhuma tarefa atrasada.',
      TaskSmartListType.noDate => 'Nenhuma tarefa sem data.',
      TaskSmartListType.highPriority => 'Nenhuma tarefa de alta prioridade.',
      TaskSmartListType.allActive => 'Nenhuma tarefa ativa.',
      TaskSmartListType.completed => 'Nenhuma tarefa concluída.',
    };

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.task_alt, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Use o botão abaixo para criar uma nova tarefa.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
