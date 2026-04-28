import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/task_model.dart';
import '../../domain/providers.dart';
import 'create_task_screen.dart';
import 'quick_add_task_button.dart';
import 'quick_add_task_sheet.dart';
import 'task_settings_screen.dart';
import 'task_smart_rules.dart';

class TaskTimelineScreen extends ConsumerWidget {
  const TaskTimelineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final sortKey = settings[TaskSettingsKeys.defaultSort] ?? TaskSettingsDefaults.defaultSort;
    final tasks = ref.watch(tasksProvider).where((task) {
      return TaskSmartRules.isParentTask(task) && !TaskSmartRules.isCanceled(task);
    }).toList();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(const Duration(days: 7));

    final overdue = tasks.where((task) => TaskSmartRules.isOverdue(task, now: now)).toList();
    TaskSmartRules.sortTasks(overdue, sortKey: sortKey);
    final todayTasks = tasks.where((task) => TaskSmartRules.isExactlyToday(task, now: now) && !TaskSmartRules.isOverdue(task, now: now)).toList();
    TaskSmartRules.sortTasks(todayTasks, sortKey: sortKey);
    final tomorrowTasks = tasks.where((task) {
      final date = TaskSmartRules.dateOnly(task);
      return date != null && _sameDay(date, tomorrow) && TaskSmartRules.isActive(task);
    }).toList();
    TaskSmartRules.sortTasks(tomorrowTasks, sortKey: sortKey);
    final nextWeekTasks = tasks.where((task) {
      final date = TaskSmartRules.dateOnly(task);
      if (date == null || !TaskSmartRules.isActive(task)) return false;
      return date.isAfter(tomorrow) && !date.isAfter(weekEnd);
    }).toList();
    TaskSmartRules.sortTasks(nextWeekTasks, sortKey: sortKey);
    final noDate = tasks.where((task) => TaskSmartRules.isNoDate(task) && TaskSmartRules.isActive(task)).toList();
    TaskSmartRules.sortTasks(noDate, sortKey: sortKey);
    final completed = tasks.where(TaskSmartRules.isCompleted).toList();
    TaskSmartRules.sortTasks(completed, sortKey: sortKey);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline'),
        actions: const [QuickAddTaskIconButton()],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _TimelineHeader(sortLabel: _sortLabel(sortKey)),
          const SizedBox(height: 16),
          _TimelineSection(title: 'Atrasadas', subtitle: 'Pendências vencidas antes de hoje.', icon: Icons.warning_amber, color: Colors.red, tasks: overdue),
          _TimelineSection(title: 'Hoje', subtitle: 'Ainda programadas para hoje.', icon: Icons.today, color: Colors.blue, tasks: todayTasks, quickDate: today),
          _TimelineSection(title: 'Amanhã', subtitle: 'Próximo dia útil de planejamento.', icon: Icons.event_available, color: Colors.teal, tasks: tomorrowTasks, quickDate: tomorrow),
          _TimelineSection(title: 'Próximos 7 dias', subtitle: 'Agenda curta da semana.', icon: Icons.date_range, color: Colors.indigo, tasks: nextWeekTasks),
          _TimelineSection(title: 'Sem data', subtitle: 'Tarefas para organizar depois.', icon: Icons.event_busy, color: Colors.orange, tasks: noDate),
          _TimelineSection(title: 'Concluídas', subtitle: 'Histórico visível para revisão rápida.', icon: Icons.check_circle, color: Colors.green, tasks: completed),
        ],
      ),
      floatingActionButton: const QuickAddTaskButton(label: 'Capturar'),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

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

class _TimelineHeader extends StatelessWidget {
  final String sortLabel;

  const _TimelineHeader({required this.sortLabel});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.timeline)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Timeline de tarefas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text('Veja tarefas por momento: atraso, hoje, amanhã, semana e sem data.', style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 2),
                  Text('Ordenação: $sortLabel', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Task> tasks;
  final DateTime? quickDate;

  const _TimelineSection({required this.title, required this.subtitle, required this.icon, required this.color, required this.tasks, this.quickDate});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 15, backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color, size: 17)),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              if (quickDate != null)
                IconButton(
                  tooltip: 'Capturar nesta data',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => QuickAddTaskSheet.show(context, contextData: QuickAddTaskContext(selectedDate: quickDate), title: 'Capturar em $title'),
                ),
              Text('${tasks.length}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            if (tasks.isEmpty)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Nenhuma tarefa neste período.', style: TextStyle(color: Colors.grey)))
            else
              ...tasks.map((task) => _TimelineTaskTile(task: task, color: color)),
          ]),
        ),
      ),
    );
  }
}

class _TimelineTaskTile extends ConsumerWidget {
  final Task task;
  final Color color;

  const _TimelineTaskTile({required this.task, required this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = TaskSmartRules.isCompleted(task);
    final scheduled = TaskSmartRules.scheduledDateTime(task);
    final dateLabel = scheduled == null
        ? 'Sem data'
        : DateFormat(TaskSmartRules.hasTime(task) ? 'dd/MM HH:mm' : 'dd/MM').format(scheduled);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconButton(
        icon: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? Colors.green : color),
        onPressed: () {
          final nextStatus = done ? 'pendente' : 'concluida';
          ref.read(tasksProvider.notifier).updateTask(task.copyWith(status: nextStatus, updatedAt: DateTime.now().toIso8601String()));
        },
      ),
      title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(decoration: done ? TextDecoration.lineThrough : null)),
      subtitle: Text('$dateLabel • ${task.priority} • ${task.status}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: task))),
    );
  }
}
