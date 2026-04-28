import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/category_model.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../domain/providers.dart';
import 'create_task_screen.dart';
import 'task_smart_rules.dart';

class InboxTasksScreen extends ConsumerStatefulWidget {
  const InboxTasksScreen({super.key});

  @override
  ConsumerState<InboxTasksScreen> createState() => _InboxTasksScreenState();
}

class _InboxTasksScreenState extends ConsumerState<InboxTasksScreen> {
  final _quickController = TextEditingController();

  @override
  void dispose() {
    _quickController.dispose();
    super.dispose();
  }

  Future<void> _quickAdd() async {
    final title = _quickController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Digite um título para capturar a tarefa.')));
      return;
    }

    final now = DateTime.now().toIso8601String();
    await ref.read(tasksProvider.notifier).addTask(
          Task(
            title: title,
            priority: 'media',
            status: 'pendente',
            reminderEnabled: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
    _quickController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarefa capturada no Inbox.')));
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final categories = ref.watch(categoriesProvider);
    final projects = ref.watch(projectsProvider).where((project) => project.status != 'canceled' && project.status != 'completed').toList();
    final inboxTasks = TaskSmartRules.inboxTasks(tasks);
    final noDateButOrganized = tasks.where((task) {
      return TaskSmartRules.isActive(task) &&
          TaskSmartRules.isParentTask(task) &&
          !TaskSmartRules.hasDate(task) &&
          !TaskSmartRules.isInbox(task);
    }).toList()
      ..sort(TaskSmartRules.compareByScheduleAndPriority);

    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _InboxHeader(count: inboxTasks.length, organizedWithoutDate: noDateButOrganized.length),
          const SizedBox(height: 16),
          _QuickCaptureCard(controller: _quickController, onSubmit: _quickAdd),
          const SizedBox(height: 16),
          if (inboxTasks.isEmpty && noDateButOrganized.isEmpty)
            const _InboxEmptyState()
          else ...[
            if (inboxTasks.isNotEmpty)
              _InboxSection(
                title: 'Capturadas',
                subtitle: 'Tarefas sem data, sem projeto e ainda sem organização forte.',
                color: Colors.teal,
                children: inboxTasks
                    .map(
                      (task) => _InboxTaskTile(
                        task: task,
                        categories: categories,
                        projects: projects,
                        onToggle: () => _toggleTask(task),
                        onOpen: () => _openTask(task),
                        onToday: () => _setDate(task, DateTime.now()),
                        onTomorrow: () => _setDate(task, DateTime.now().add(const Duration(days: 1))),
                        onOrganize: () => _showOrganizeSheet(task),
                      ),
                    )
                    .toList(),
              ),
            if (noDateButOrganized.isNotEmpty)
              _InboxSection(
                title: 'Organizadas sem data',
                subtitle: 'Já têm categoria/projeto, mas ainda precisam de agenda ou revisão.',
                color: Colors.orange,
                children: noDateButOrganized
                    .map(
                      (task) => _InboxTaskTile(
                        task: task,
                        categories: categories,
                        projects: projects,
                        onToggle: () => _toggleTask(task),
                        onOpen: () => _openTask(task),
                        onToday: () => _setDate(task, DateTime.now()),
                        onTomorrow: () => _setDate(task, DateTime.now().add(const Duration(days: 1))),
                        onOrganize: () => _showOrganizeSheet(task),
                      ),
                    )
                    .toList(),
              ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTaskScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Nova completa'),
      ),
    );
  }

  void _openTask(Task task) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: task)));
  }

  void _toggleTask(Task task) {
    final nextStatus = TaskSmartRules.isCompleted(task) ? 'pendente' : 'concluida';
    ref.read(tasksProvider.notifier).updateTask(task.copyWith(status: nextStatus, updatedAt: DateTime.now().toIso8601String()));
  }

  void _setDate(Task task, DateTime date) {
    final formatted = DateFormat('yyyy-MM-dd').format(date);
    ref.read(tasksProvider.notifier).updateTask(task.copyWith(date: formatted, status: 'pendente', updatedAt: DateTime.now().toIso8601String()));
  }

  Future<void> _showOrganizeSheet(Task task) async {
    final categories = ref.read(categoriesProvider);
    final projects = ref.read(projectsProvider).where((project) => project.status != 'canceled' && project.status != 'completed').toList();
    int? categoryId = task.categoryId;
    int? projectId = task.projectId;
    String priority = task.priority;
    DateTime? selectedDate = TaskSmartRules.dateOnly(task);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return Padding(
            padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Organizar tarefa', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Prioridade'),
                    items: const [
                      DropdownMenuItem(value: 'baixa', child: Text('Baixa')),
                      DropdownMenuItem(value: 'media', child: Text('Média')),
                      DropdownMenuItem(value: 'alta', child: Text('Alta')),
                    ],
                    onChanged: (value) => setLocal(() => priority = value ?? 'media'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    initialValue: categories.any((category) => category.id == categoryId) ? categoryId : null,
                    decoration: const InputDecoration(labelText: 'Categoria'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Sem categoria')),
                      ...categories.map((category) => DropdownMenuItem<int?>(value: category.id, child: Text(category.name))),
                    ],
                    onChanged: (value) => setLocal(() => categoryId = value),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    initialValue: projects.any((project) => project.id == projectId) ? projectId : null,
                    decoration: const InputDecoration(labelText: 'Projeto'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Sem projeto')),
                      ...projects.map((project) => DropdownMenuItem<int?>(value: project.id, child: Text(project.name))),
                    ],
                    onChanged: (value) => setLocal(() => projectId = value),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Sem data'),
                        selected: selectedDate == null,
                        onSelected: (_) => setLocal(() => selectedDate = null),
                      ),
                      ChoiceChip(
                        label: const Text('Hoje'),
                        selected: _sameDay(selectedDate, DateTime.now()),
                        onSelected: (_) => setLocal(() => selectedDate = DateTime.now()),
                      ),
                      ChoiceChip(
                        label: const Text('Amanhã'),
                        selected: _sameDay(selectedDate, DateTime.now().add(const Duration(days: 1))),
                        onSelected: (_) => setLocal(() => selectedDate = DateTime.now().add(const Duration(days: 1))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      final updated = task.copyWith(
                        categoryId: categoryId,
                        clearCategoryId: categoryId == null,
                        projectId: projectId,
                        clearProjectId: projectId == null,
                        clearProjectStepId: projectId == null,
                        priority: priority,
                        date: selectedDate == null ? null : DateFormat('yyyy-MM-dd').format(selectedDate!),
                        clearDate: selectedDate == null,
                        clearTime: selectedDate == null,
                        reminderEnabled: selectedDate == null ? false : task.reminderEnabled,
                        status: 'pendente',
                        updatedAt: DateTime.now().toIso8601String(),
                      );
                      await ref.read(tasksProvider.notifier).updateTask(updated);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Salvar organização'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _sameDay(DateTime? a, DateTime b) {
    if (a == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _InboxHeader extends StatelessWidget {
  final int count;
  final int organizedWithoutDate;

  const _InboxHeader({required this.count, required this.organizedWithoutDate});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.inbox)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Inbox de tarefas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('$count capturadas • $organizedWithoutDate organizadas sem data', style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickCaptureCard extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const _QuickCaptureCard({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                decoration: const InputDecoration(
                  labelText: 'Capturar rapidamente',
                  hintText: 'Ex: ligar para o dentista',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(onPressed: onSubmit, icon: const Icon(Icons.send)),
          ],
        ),
      ),
    );
  }
}

class _InboxSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final List<Widget> children;

  const _InboxSection({required this.title, required this.subtitle, required this.color, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.label_important_outline, color: color, size: 20),
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

class _InboxTaskTile extends StatelessWidget {
  final Task task;
  final List<TaskCategory> categories;
  final List<Project> projects;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onToday;
  final VoidCallback onTomorrow;
  final VoidCallback onOrganize;

  const _InboxTaskTile({
    required this.task,
    required this.categories,
    required this.projects,
    required this.onToggle,
    required this.onOpen,
    required this.onToday,
    required this.onTomorrow,
    required this.onOrganize,
  });

  @override
  Widget build(BuildContext context) {
    final categoryName = task.categoryId == null ? null : categories.firstWhereOrNull((category) => category.id == task.categoryId)?.name;
    final projectName = task.projectId == null ? null : projects.firstWhereOrNull((project) => project.id == task.projectId)?.name;

    return Card(
      child: ListTile(
        leading: IconButton(
          icon: const Icon(Icons.radio_button_unchecked),
          onPressed: onToggle,
        ),
        title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _InboxBadge(icon: Icons.flag, label: task.priority, color: _priorityColor(task.priority)),
                if (categoryName != null) _InboxBadge(icon: Icons.category, label: categoryName, color: Colors.blueGrey),
                if (projectName != null) _InboxBadge(icon: Icons.rocket_launch, label: projectName, color: Colors.purple),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                OutlinedButton.icon(onPressed: onToday, icon: const Icon(Icons.today, size: 16), label: const Text('Hoje')),
                OutlinedButton.icon(onPressed: onTomorrow, icon: const Icon(Icons.event_available, size: 16), label: const Text('Amanhã')),
                OutlinedButton.icon(onPressed: onOrganize, icon: const Icon(Icons.tune, size: 16), label: const Text('Organizar')),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onOpen,
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

class _InboxBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InboxBadge({required this.icon, required this.label, required this.color});

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

class _InboxEmptyState extends StatelessWidget {
  const _InboxEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 54, color: Colors.teal),
          SizedBox(height: 12),
          Text('Inbox limpo.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SizedBox(height: 6),
          Text('Capture ideias e tarefas soltas aqui antes de organizar.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
