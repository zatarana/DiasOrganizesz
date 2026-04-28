import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/task_model.dart';
import '../../domain/providers.dart';
import 'create_task_screen.dart';
import 'quick_add_task_button.dart';
import 'task_smart_rules.dart';

class TaskKanbanScreen extends ConsumerWidget {
  const TaskKanbanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(tasksProvider).where((task) => TaskSmartRules.isParentTask(task) && !TaskSmartRules.isCanceled(task)).toList();
    final overdue = allTasks.where((task) => TaskSmartRules.isOverdue(task)).toList()..sort(TaskSmartRules.compareByScheduleAndPriority);
    final pending = allTasks.where((task) => TaskSmartRules.isActive(task) && !TaskSmartRules.isOverdue(task)).toList()..sort(TaskSmartRules.compareByScheduleAndPriority);
    final completed = allTasks.where(TaskSmartRules.isCompleted).toList()..sort(TaskSmartRules.compareByScheduleAndPriority);

    return Scaffold(
      appBar: AppBar(title: const Text('Kanban de tarefas'), actions: const [QuickAddTaskIconButton()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          const _KanbanHeader(),
          const SizedBox(height: 16),
          _KanbanColumn(title: 'Atrasadas', subtitle: 'Tarefas vencidas que precisam de decisão.', icon: Icons.warning_amber, color: Colors.red, tasks: overdue, targetStatus: 'pendente'),
          _KanbanColumn(title: 'Pendentes', subtitle: 'Tarefas ativas ainda não concluídas.', icon: Icons.radio_button_unchecked, color: Colors.blue, tasks: pending, targetStatus: 'concluida'),
          _KanbanColumn(title: 'Concluídas', subtitle: 'Histórico recente de tarefas finalizadas.', icon: Icons.check_circle, color: Colors.green, tasks: completed, targetStatus: 'pendente'),
        ],
      ),
      floatingActionButton: const QuickAddTaskButton(label: 'Capturar'),
    );
  }
}

class _KanbanHeader extends StatelessWidget {
  const _KanbanHeader();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(child: Icon(Icons.view_kanban)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kanban operacional', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Visualize tarefas por situação sem alterar a tela clássica.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Task> tasks;
  final String targetStatus;

  const _KanbanColumn({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tasks,
    required this.targetStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(radius: 15, backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color, size: 17)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
                  Text('${tasks.length}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const SizedBox(height: 8),
              if (tasks.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Nenhuma tarefa nesta coluna.', style: TextStyle(color: Colors.grey)))
              else
                ...tasks.map((task) => _KanbanTaskCard(task: task, color: color, targetStatus: targetStatus)),
            ],
          ),
        ),
      ),
    );
  }
}

class _KanbanTaskCard extends ConsumerWidget {
  final Task task;
  final Color color;
  final String targetStatus;

  const _KanbanTaskCard({required this.task, required this.color, required this.targetStatus});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduled = TaskSmartRules.scheduledDateTime(task);
    final dateLabel = scheduled == null
        ? 'Sem data'
        : '${scheduled.day.toString().padLeft(2, '0')}/${scheduled.month.toString().padLeft(2, '0')}${TaskSmartRules.hasTime(task) ? ' ${task.time}' : ''}';
    final actionLabel = targetStatus == 'concluida' ? 'Concluir' : 'Reabrir';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('$dateLabel • ${task.priority} • ${task.status}'),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'open') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: task)));
              }
              if (value == 'toggle') {
                ref.read(tasksProvider.notifier).updateTask(task.copyWith(status: targetStatus, updatedAt: DateTime.now().toIso8601String()));
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'open', child: Text('Abrir detalhes')),
              PopupMenuItem(value: 'toggle', child: Text(actionLabel)),
            ],
          ),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: task))),
        ),
      ),
    );
  }
}
