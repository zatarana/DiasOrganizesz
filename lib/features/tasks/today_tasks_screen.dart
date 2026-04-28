import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/task_model.dart';
import '../../domain/providers.dart';
import 'create_task_screen.dart';
import 'task_smart_rules.dart';

class TodayTasksScreen extends ConsumerWidget {
  const TodayTasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final now = DateTime.now();
    final progress = TaskSmartRules.dayProgress(tasks, now: now);

    final overdueTasks = tasks.where((task) {
      return TaskSmartRules.isParentTask(task) && TaskSmartRules.isOverdue(task, now: now);
    }).toList()
      ..sort(TaskSmartRules.compareByScheduleAndPriority);

    final exactTodayTasks = tasks.where((task) {
      return TaskSmartRules.isParentTask(task) && TaskSmartRules.isExactlyToday(task, now: now) && !TaskSmartRules.isCanceled(task);
    }).toList()
      ..sort(TaskSmartRules.compareByScheduleAndPriority);

    final noDateSuggestions = TaskSmartRules.suggestedForToday(tasks, now: now)
        .where((task) => !TaskSmartRules.hasDate(task) && TaskSmartRules.isParentTask(task))
        .take(5)
        .toList();

    final allEmpty = overdueTasks.isEmpty && exactTodayTasks.isEmpty && noDateSuggestions.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Hoje')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _TodayHeader(progress: progress, now: now),
          const SizedBox(height: 16),
          if (allEmpty)
            const _TodayEmptyState()
          else ...[
            if (overdueTasks.isNotEmpty)
              _TodaySection(
                title: 'Atrasadas',
                subtitle: 'Resolva, adie ou remova a data para reorganizar o dia.',
                icon: Icons.warning_amber,
                color: Colors.red,
                children: overdueTasks
                    .map((task) => _TodayTaskTile(
                          task: task,
                          accentColor: Colors.red,
                          onToggle: () => _toggleTask(ref, task),
                          onOpen: () => _openTask(context, task),
                          onTomorrow: () => _moveToTomorrow(ref, task),
                          onRemoveDate: () => _removeDate(ref, task),
                        ))
                    .toList(),
              ),
            if (exactTodayTasks.isNotEmpty)
              _TodaySection(
                title: 'Programadas para hoje',
                subtitle: 'Tarefas com data de hoje, incluindo horários e prioridades.',
                icon: Icons.today,
                color: Colors.blue,
                children: exactTodayTasks
                    .map((task) => _TodayTaskTile(
                          task: task,
                          accentColor: TaskSmartRules.isCompleted(task) ? Colors.green : Colors.blue,
                          onToggle: () => _toggleTask(ref, task),
                          onOpen: () => _openTask(context, task),
                          onTomorrow: () => _moveToTomorrow(ref, task),
                          onRemoveDate: () => _removeDate(ref, task),
                        ))
                    .toList(),
              ),
            if (noDateSuggestions.isNotEmpty)
              _TodaySection(
                title: 'Sugestões sem data',
                subtitle: 'Tarefas soltas que podem entrar no planejamento de hoje.',
                icon: Icons.lightbulb_outline,
                color: Colors.orange,
                children: noDateSuggestions
                    .map((task) => _TodayTaskTile(
                          task: task,
                          accentColor: Colors.orange,
                          onToggle: () => _toggleTask(ref, task),
                          onOpen: () => _openTask(context, task),
                          onTomorrow: () => _moveToTomorrow(ref, task),
                          onRemoveDate: () => _removeDate(ref, task),
                          primaryActionLabel: 'Hoje',
                          onPrimaryAction: () => _moveToToday(ref, task),
                        ))
                    .toList(),
              ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(selectedDate: now))),
        icon: const Icon(Icons.add),
        label: const Text('Tarefa hoje'),
      ),
    );
  }

  static void _openTask(BuildContext context, Task task) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: task)));
  }

  static void _toggleTask(WidgetRef ref, Task task) {
    final reopenedStatus = TaskSmartRules.isOverdue(task) ? 'atrasada' : 'pendente';
    final nextStatus = TaskSmartRules.isCompleted(task) ? reopenedStatus : 'concluida';
    ref.read(tasksProvider.notifier).updateTask(task.copyWith(status: nextStatus, updatedAt: DateTime.now().toIso8601String()));
  }

  static void _moveToToday(WidgetRef ref, Task task) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    ref.read(tasksProvider.notifier).updateTask(task.copyWith(date: today, status: 'pendente', updatedAt: DateTime.now().toIso8601String()));
  }

  static void _moveToTomorrow(WidgetRef ref, Task task) {
    final tomorrow = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 1)));
    ref.read(tasksProvider.notifier).updateTask(task.copyWith(date: tomorrow, status: 'pendente', updatedAt: DateTime.now().toIso8601String()));
  }

  static void _removeDate(WidgetRef ref, Task task) {
    ref.read(tasksProvider.notifier).updateTask(
          task.copyWith(
            clearDate: true,
            clearTime: true,
            reminderEnabled: false,
            status: 'pendente',
            updatedAt: DateTime.now().toIso8601String(),
          ),
        );
  }
}

class _TodayHeader extends StatelessWidget {
  final TaskDayProgress progress;
  final DateTime now;

  const _TodayHeader({required this.progress, required this.now});

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('EEEE, dd/MM', 'pt_BR').format(now);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.today)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(progress.allDone ? 'Dia fechado' : 'Plano de hoje', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(label, style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                Text('${progress.percent}%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(value: progress.ratio),
            const SizedBox(height: 10),
            Text(
              progress.total == 0
                  ? 'Nenhuma tarefa exatamente marcada para hoje.'
                  : '${progress.completed}/${progress.total} tarefas de hoje concluídas.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodaySection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Widget> children;

  const _TodaySection({required this.title, required this.subtitle, required this.icon, required this.color, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              Text('${children.length}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _TodayTaskTile extends StatelessWidget {
  final Task task;
  final Color accentColor;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onTomorrow;
  final VoidCallback onRemoveDate;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  const _TodayTaskTile({
    required this.task,
    required this.accentColor,
    required this.onToggle,
    required this.onOpen,
    required this.onTomorrow,
    required this.onRemoveDate,
    this.primaryActionLabel,
    this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final done = TaskSmartRules.isCompleted(task);
    final overdue = TaskSmartRules.isOverdue(task);
    final scheduled = TaskSmartRules.scheduledDateTime(task);
    final dateText = scheduled == null
        ? 'Sem data'
        : '${scheduled.day.toString().padLeft(2, '0')}/${scheduled.month.toString().padLeft(2, '0')}${TaskSmartRules.hasTime(task) ? ' ${task.time}' : ''}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: IconButton(
            onPressed: onToggle,
            icon: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? Colors.green : accentColor),
          ),
          title: Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(decoration: done ? TextDecoration.lineThrough : null, fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _TodayBadge(icon: Icons.event, label: dateText, color: overdue ? Colors.red : Colors.blueGrey),
                  _TodayBadge(icon: Icons.flag, label: task.priority, color: _priorityColor(task.priority)),
                  if (task.projectId != null) const _TodayBadge(icon: Icons.rocket_launch, label: 'Projeto', color: Colors.purple),
                  if (task.recurrenceType != 'none') const _TodayBadge(icon: Icons.repeat, label: 'Recorrente', color: Colors.indigo),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (primaryActionLabel != null && onPrimaryAction != null)
                    OutlinedButton.icon(
                      onPressed: onPrimaryAction,
                      icon: const Icon(Icons.today, size: 16),
                      label: Text(primaryActionLabel!),
                    ),
                  OutlinedButton.icon(
                    onPressed: onTomorrow,
                    icon: const Icon(Icons.event_available, size: 16),
                    label: const Text('Amanhã'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onRemoveDate,
                    icon: const Icon(Icons.event_busy, size: 16),
                    label: const Text('Sem data'),
                  ),
                ],
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onOpen,
        ),
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

class _TodayBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _TodayBadge({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
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

class _TodayEmptyState extends StatelessWidget {
  const _TodayEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.celebration_outlined, size: 54, color: Colors.green),
          SizedBox(height: 12),
          Text('Nada pendente para hoje.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('Crie uma tarefa para hoje ou aproveite esse respiro.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
