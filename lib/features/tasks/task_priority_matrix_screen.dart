import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/task_model.dart';
import '../../domain/providers.dart';
import 'create_task_screen.dart';
import 'quick_add_task_button.dart';
import 'task_settings_screen.dart';
import 'task_smart_rules.dart';

class TaskPriorityMatrixScreen extends ConsumerWidget {
  const TaskPriorityMatrixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final sortKey = settings[TaskSettingsKeys.defaultSort] ?? TaskSettingsDefaults.defaultSort;
    final tasks = ref.watch(tasksProvider).where((task) => TaskSmartRules.isParentTask(task) && TaskSmartRules.isActive(task)).toList();
    final urgentHigh = tasks.where((task) => task.priority == 'alta' && TaskSmartRules.hasDate(task)).toList();
    TaskSmartRules.sortTasks(urgentHigh, sortKey: sortKey);
    final importantNoDate = tasks.where((task) => task.priority == 'alta' && !TaskSmartRules.hasDate(task)).toList();
    TaskSmartRules.sortTasks(importantNoDate, sortKey: sortKey);
    final scheduledNormal = tasks.where((task) => task.priority != 'alta' && TaskSmartRules.hasDate(task)).toList();
    TaskSmartRules.sortTasks(scheduledNormal, sortKey: sortKey);
    final lowLoose = tasks.where((task) => task.priority != 'alta' && !TaskSmartRules.hasDate(task)).toList();
    TaskSmartRules.sortTasks(lowLoose, sortKey: sortKey);

    return Scaffold(
      appBar: AppBar(title: const Text('Matriz de prioridade'), actions: const [QuickAddTaskIconButton()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _MatrixHeader(sortLabel: _sortLabel(sortKey)),
          const SizedBox(height: 16),
          _MatrixSection(title: 'Fazer agora', subtitle: 'Alta prioridade com data definida.', color: Colors.red, tasks: urgentHigh),
          _MatrixSection(title: 'Planejar', subtitle: 'Alta prioridade ainda sem data.', color: Colors.deepOrange, tasks: importantNoDate),
          _MatrixSection(title: 'Acompanhar', subtitle: 'Tarefas normais com data.', color: Colors.indigo, tasks: scheduledNormal),
          _MatrixSection(title: 'Revisar depois', subtitle: 'Tarefas normais sem data.', color: Colors.blueGrey, tasks: lowLoose),
        ],
      ),
      floatingActionButton: const QuickAddTaskButton(label: 'Capturar'),
    );
  }

  static String _sortLabel(String sortKey) {
    switch (sortKey) {
      case 'priority_schedule':
        return 'Prioridade e data';
      case 'title':
        return 'Título';
      case 'created_desc':
        return 'Mais recentes';
      case 'schedule_priority':
      default:
        return 'Data e prioridade';
    }
  }
}

class _MatrixHeader extends StatelessWidget {
  final String sortLabel;

  const _MatrixHeader({required this.sortLabel});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.grid_view)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Matriz de prioridade', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Text('Cruza prioridade e data para decidir o que fazer, planejar ou revisar.', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 2),
                Text('Ordenação: $sortLabel', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _MatrixSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<Task> tasks;

  const _MatrixSection({required this.title, required this.subtitle, required this.color, required this.tasks});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 15, backgroundColor: color.withValues(alpha: 0.12), child: Icon(Icons.flag, color: color, size: 17)),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              Text('${tasks.length}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            if (tasks.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Nenhuma tarefa neste quadrante.', style: TextStyle(color: Colors.grey)))
            else
              ...tasks.map((task) => _MatrixTaskTile(task: task, color: color)),
          ]),
        ),
      ),
    );
  }
}

class _MatrixTaskTile extends ConsumerWidget {
  final Task task;
  final Color color;

  const _MatrixTaskTile({required this.task, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduled = TaskSmartRules.scheduledDateTime(task);
    final dateLabel = scheduled == null ? 'Sem data' : '${scheduled.day.toString().padLeft(2, '0')}/${scheduled.month.toString().padLeft(2, '0')}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconButton(
        icon: Icon(Icons.radio_button_unchecked, color: color),
        onPressed: () => ref.read(tasksProvider.notifier).updateTask(task.copyWith(status: 'concluida', updatedAt: DateTime.now().toIso8601String())),
      ),
      title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('$dateLabel • ${task.priority}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: task))),
    );
  }
}
