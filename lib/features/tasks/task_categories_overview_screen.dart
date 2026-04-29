import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/task_model.dart';
import '../../domain/providers.dart';
import 'create_task_screen.dart';
import 'quick_add_task_button.dart';
import 'quick_add_task_sheet.dart';
import 'task_settings_screen.dart';
import 'task_smart_rules.dart';

class TaskCategoriesOverviewScreen extends ConsumerWidget {
  const TaskCategoriesOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);
    final settings = ref.watch(taskSettingsProvider);
    final sortKey = settings[TaskSettingsKeys.defaultSort] ?? TaskSettingsDefaults.defaultSort;
    final tasks = ref.watch(tasksProvider);

    final uncategorized = tasks.where((task) {
      return TaskSmartRules.isParentTask(task) && TaskSmartRules.isActive(task) && task.categoryId == null;
    }).toList();
    TaskSmartRules.sortTasks(uncategorized, sortKey: sortKey);

    return Scaffold(
      appBar: AppBar(title: const Text('Listas e categorias')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _CategoryOverviewHeader(sortLabel: _sortLabel(sortKey)),
          const SizedBox(height: 16),
          if (categories.isEmpty && uncategorized.isEmpty)
            const _CategoryEmptyState()
          else ...[
            ...categories.map((category) {
              final categoryTasks = tasks.where((task) {
                return TaskSmartRules.isParentTask(task) && task.categoryId == category.id && !TaskSmartRules.isCanceled(task);
              }).toList();
              final active = categoryTasks.where(TaskSmartRules.isActive).length;
              final completed = categoryTasks.where(TaskSmartRules.isCompleted).length;
              final overdue = categoryTasks.where((task) => TaskSmartRules.isOverdue(task)).length;
              return _CategoryCard(
                title: category.name,
                active: active,
                completed: completed,
                overdue: overdue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TaskCategoryDetailScreen(categoryId: category.id, categoryName: category.name)),
                ),
              );
            }),
            if (uncategorized.isNotEmpty)
              _CategoryCard(
                title: 'Sem categoria',
                active: uncategorized.length,
                completed: 0,
                overdue: uncategorized.where((task) => TaskSmartRules.isOverdue(task)).length,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TaskCategoryDetailScreen(categoryId: null, categoryName: 'Sem categoria')),
                ),
              ),
          ],
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

class TaskCategoryDetailScreen extends ConsumerWidget {
  final int? categoryId;
  final String categoryName;

  const TaskCategoryDetailScreen({super.key, required this.categoryId, required this.categoryName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(taskSettingsProvider);
    final sortKey = settings[TaskSettingsKeys.defaultSort] ?? TaskSettingsDefaults.defaultSort;
    final tasks = ref.watch(tasksProvider).where((task) {
      return TaskSmartRules.isParentTask(task) && !TaskSmartRules.isCanceled(task) && task.categoryId == categoryId;
    }).toList();
    TaskSmartRules.sortTasks(tasks, sortKey: sortKey);

    final active = tasks.where(TaskSmartRules.isActive).toList();
    final completed = tasks.where(TaskSmartRules.isCompleted).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(categoryName),
        actions: [
          QuickAddTaskIconButton(contextData: QuickAddTaskContext(categoryId: categoryId), tooltip: 'Capturar nesta categoria'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _CategoryDetailHeader(categoryName: categoryName, active: active.length, completed: completed.length, sortLabel: TaskCategoriesOverviewScreen._sortLabel(sortKey)),
          const SizedBox(height: 16),
          if (tasks.isEmpty)
            const _CategoryEmptyState()
          else ...[
            if (active.isNotEmpty) _TaskGroup(title: 'Ativas', tasks: active),
            if (completed.isNotEmpty) _TaskGroup(title: 'Concluídas', tasks: completed),
          ],
        ],
      ),
      floatingActionButton: QuickAddTaskButton(label: 'Capturar', contextData: QuickAddTaskContext(categoryId: categoryId)),
    );
  }
}

class _TaskGroup extends ConsumerWidget {
  final String title;
  final List<Task> tasks;

  const _TaskGroup({required this.title, required this.tasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$title (${tasks.length})', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...tasks.map((task) => _TaskTile(task: task)),
        ],
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  final Task task;

  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = TaskSmartRules.isCompleted(task);
    final overdue = TaskSmartRules.isOverdue(task);
    final scheduled = TaskSmartRules.scheduledDateTime(task);
    final dateLabel = scheduled == null ? 'Sem data' : '${scheduled.day.toString().padLeft(2, '0')}/${scheduled.month.toString().padLeft(2, '0')}';

    return Card(
      child: ListTile(
        leading: IconButton(
          icon: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? Colors.green : overdue ? Colors.red : Colors.grey),
          onPressed: () {
            final nextStatus = done ? 'pendente' : 'concluida';
            ref.read(tasksProvider.notifier).updateTask(task.copyWith(status: nextStatus, updatedAt: DateTime.now().toIso8601String()));
          },
        ),
        title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(decoration: done ? TextDecoration.lineThrough : null)),
        subtitle: Text('$dateLabel • ${task.priority}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: task))),
      ),
    );
  }
}

class _CategoryOverviewHeader extends StatelessWidget {
  final String sortLabel;

  const _CategoryOverviewHeader({required this.sortLabel});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.category)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Listas por categoria', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Text('Use categorias como listas visuais sem quebrar o modelo atual.', style: TextStyle(color: Colors.grey)),
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

class _CategoryDetailHeader extends StatelessWidget {
  final String categoryName;
  final int active;
  final int completed;
  final String sortLabel;

  const _CategoryDetailHeader({required this.categoryName, required this.active, required this.completed, required this.sortLabel});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.list_alt)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(categoryName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('$active ativas • $completed concluídas', style: const TextStyle(color: Colors.grey)),
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

class _CategoryCard extends StatelessWidget {
  final String title;
  final int active;
  final int completed;
  final int overdue;
  final VoidCallback onTap;

  const _CategoryCard({required this.title, required this.active, required this.completed, required this.overdue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = overdue > 0 ? Colors.red : Colors.blueGrey;
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(Icons.folder_open, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$active ativas • $completed concluídas • $overdue atrasadas'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _CategoryEmptyState extends StatelessWidget {
  const _CategoryEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.folder_off_outlined, size: 54, color: Colors.grey),
          SizedBox(height: 12),
          Text('Nada por aqui ainda.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('Crie tarefas ou categorias para montar suas listas.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
