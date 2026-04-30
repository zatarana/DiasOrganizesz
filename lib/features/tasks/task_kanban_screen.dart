import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/task_model.dart';
import '../../domain/providers.dart';
import 'create_task_screen.dart';
import 'quick_add_task_button.dart';
import 'task_settings_screen.dart';
import 'task_smart_rules.dart';

enum _KanbanColumnType { overdue, pending, completed }

class TaskKanbanScreen extends ConsumerWidget {
  const TaskKanbanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(taskSettingsProvider);
    final sortKey = settings[TaskSettingsKeys.defaultSort] ?? TaskSettingsDefaults.defaultSort;
    final allTasks = ref.watch(tasksProvider).where((task) => TaskSmartRules.isParentTask(task) && !TaskSmartRules.isCanceled(task)).toList();
    final overdue = allTasks.where((task) => TaskSmartRules.isOverdue(task)).toList();
    TaskSmartRules.sortTasks(overdue, sortKey: sortKey);
    final pending = allTasks.where((task) => TaskSmartRules.isActive(task) && !TaskSmartRules.isOverdue(task)).toList();
    TaskSmartRules.sortTasks(pending, sortKey: sortKey);
    final completed = allTasks.where(TaskSmartRules.isCompleted).toList();
    TaskSmartRules.sortTasks(completed, sortKey: sortKey);

    return Scaffold(
      appBar: AppBar(title: const Text('Kanban de tarefas'), actions: const [QuickAddTaskIconButton()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _KanbanHeader(sortLabel: _sortLabel(sortKey)),
          const SizedBox(height: 16),
          _KanbanColumn(
            title: 'Atrasadas',
            subtitle: 'Arraste tarefas para cá para remarcar como vencidas.',
            icon: Icons.warning_amber,
            color: Colors.red,
            tasks: overdue,
            columnType: _KanbanColumnType.overdue,
          ),
          _KanbanColumn(
            title: 'Pendentes',
            subtitle: 'Arraste para cá para reabrir ou planejar como ativa.',
            icon: Icons.radio_button_unchecked,
            color: Colors.blue,
            tasks: pending,
            columnType: _KanbanColumnType.pending,
          ),
          _KanbanColumn(
            title: 'Concluídas',
            subtitle: 'Arraste para cá para concluir rapidamente.',
            icon: Icons.check_circle,
            color: Colors.green,
            tasks: completed,
            columnType: _KanbanColumnType.completed,
          ),
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

class _KanbanHeader extends StatelessWidget {
  final String sortLabel;

  const _KanbanHeader({required this.sortLabel});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.view_kanban)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Kanban operacional', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text('Arraste cards entre colunas ou crie tarefas rápidas no rodapé.', style: TextStyle(color: Colors.grey)),
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

class _KanbanColumn extends ConsumerWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Task> tasks;
  final _KanbanColumnType columnType;

  const _KanbanColumn({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tasks,
    required this.columnType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DragTarget<Task>(
      onWillAccept: (task) => task != null && !_isAlreadyInColumn(task, columnType),
      onAccept: (task) => _moveTaskToColumn(context, ref, task, columnType),
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: EdgeInsets.all(isHovering ? 4 : 0),
          decoration: BoxDecoration(
            color: isHovering ? color.withValues(alpha: 0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isHovering ? Border.all(color: color.withValues(alpha: 0.35), width: 1.5) : null,
          ),
          child: Padding(
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
                    if (isHovering)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
                        child: Text('Solte aqui para mover para $title', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
                      ),
                    if (tasks.isEmpty)
                      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Nenhuma tarefa nesta coluna.', style: TextStyle(color: Colors.grey)))
                    else
                      ...tasks.map((task) => _KanbanTaskCard(task: task, color: color, columnType: columnType)),
                    const SizedBox(height: 8),
                    _KanbanQuickAdd(columnType: columnType, color: color, title: title),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KanbanTaskCard extends ConsumerWidget {
  final Task task;
  final Color color;
  final _KanbanColumnType columnType;

  const _KanbanTaskCard({required this.task, required this.color, required this.columnType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduled = TaskSmartRules.scheduledDateTime(task);
    final dateLabel = scheduled == null
        ? 'Sem data'
        : '${scheduled.day.toString().padLeft(2, '0')}/${scheduled.month.toString().padLeft(2, '0')}${TaskSmartRules.hasTime(task) ? ' ${task.time}' : ''}';
    final actionLabel = columnType == _KanbanColumnType.completed ? 'Reabrir' : 'Concluir';
    final targetType = columnType == _KanbanColumnType.completed ? _KanbanColumnType.pending : _KanbanColumnType.completed;

    final card = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: color, width: 4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          leading: Icon(Icons.drag_indicator, color: Colors.grey.shade500),
          title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('$dateLabel • ${task.priority} • ${task.status}'),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'open') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: task)));
              }
              if (value == 'toggle') {
                _moveTaskToColumn(context, ref, task, targetType);
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

    return LongPressDraggable<Task>(
      data: task,
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Opacity(opacity: 0.92, child: card),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}

class _KanbanQuickAdd extends ConsumerStatefulWidget {
  final _KanbanColumnType columnType;
  final Color color;
  final String title;

  const _KanbanQuickAdd({required this.columnType, required this.color, required this.title});

  @override
  ConsumerState<_KanbanQuickAdd> createState() => _KanbanQuickAddState();
}

class _KanbanQuickAddState extends ConsumerState<_KanbanQuickAdd> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _addQuickTask() async {
    final title = _controller.text.trim();
    if (title.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final categories = ref.read(categoriesProvider);
      final categoryId = categories.isNotEmpty ? categories.first.id ?? 1 : 1;
      final now = DateTime.now();
      final baseTask = _taskForColumn(title: title, columnType: widget.columnType, categoryId: categoryId, now: now);
      await ref.read(tasksProvider.notifier).addTask(baseTask);
      _controller.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tarefa adicionada em ${widget.title}.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Adicionar card rápido em ${widget.title}',
                border: const OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addQuickTask(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Adicionar card',
            onPressed: _saving ? null : _addQuickTask,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

bool _isAlreadyInColumn(Task task, _KanbanColumnType columnType) {
  switch (columnType) {
    case _KanbanColumnType.overdue:
      return TaskSmartRules.isOverdue(task);
    case _KanbanColumnType.pending:
      return TaskSmartRules.isActive(task) && !TaskSmartRules.isOverdue(task);
    case _KanbanColumnType.completed:
      return TaskSmartRules.isCompleted(task);
  }
}

Future<void> _moveTaskToColumn(BuildContext context, WidgetRef ref, Task task, _KanbanColumnType columnType) async {
  final updated = _taskMovedToColumn(task, columnType);
  await ref.read(tasksProvider.notifier).updateTask(updated);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${task.title}" movida para ${_columnLabel(columnType)}.')));
  }
}

Task _taskMovedToColumn(Task task, _KanbanColumnType columnType) {
  final now = DateTime.now();
  final todayText = DateFormat('yyyy-MM-dd').format(now);
  final yesterdayText = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
  final updateTime = now.toIso8601String();

  switch (columnType) {
    case _KanbanColumnType.overdue:
      return task.copyWith(status: 'atrasada', date: yesterdayText, clearTime: true, updatedAt: updateTime);
    case _KanbanColumnType.pending:
      final scheduled = TaskSmartRules.scheduledDateTime(task);
      final shouldResetDate = scheduled == null || scheduled.isBefore(now);
      return task.copyWith(status: 'pendente', date: shouldResetDate ? todayText : task.date, updatedAt: updateTime);
    case _KanbanColumnType.completed:
      return task.copyWith(status: 'concluida', updatedAt: updateTime);
  }
}

Task _taskForColumn({required String title, required _KanbanColumnType columnType, required int categoryId, required DateTime now}) {
  final todayText = DateFormat('yyyy-MM-dd').format(now);
  final yesterdayText = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
  final createdAt = now.toIso8601String();

  switch (columnType) {
    case _KanbanColumnType.overdue:
      return Task(title: title, categoryId: categoryId, priority: 'media', date: yesterdayText, time: null, status: 'atrasada', reminderEnabled: false, createdAt: createdAt, updatedAt: createdAt);
    case _KanbanColumnType.pending:
      return Task(title: title, categoryId: categoryId, priority: 'media', date: todayText, time: null, status: 'pendente', reminderEnabled: false, createdAt: createdAt, updatedAt: createdAt);
    case _KanbanColumnType.completed:
      return Task(title: title, categoryId: categoryId, priority: 'media', date: todayText, time: null, status: 'concluida', reminderEnabled: false, createdAt: createdAt, updatedAt: createdAt);
  }
}

String _columnLabel(_KanbanColumnType columnType) {
  switch (columnType) {
    case _KanbanColumnType.overdue:
      return 'Atrasadas';
    case _KanbanColumnType.pending:
      return 'Pendentes';
    case _KanbanColumnType.completed:
      return 'Concluídas';
  }
}
