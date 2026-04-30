import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

import '../../data/models/task_model.dart';
import '../../domain/providers.dart';
import '../calendar/calendar_screen.dart';
import '../projects/projects_screen.dart';
import '../statistics/stats_screen.dart';
import 'create_task_screen.dart';
import 'inbox_tasks_screen.dart';
import 'quick_add_task_button.dart';
import 'task_categories_overview_screen.dart';
import 'task_kanban_screen.dart';
import 'task_list_screen.dart';
import 'task_priority_matrix_screen.dart';
import 'task_productivity_stats_screen.dart';
import 'task_search_screen.dart';
import 'task_settings_screen.dart';
import 'task_smart_list_screen.dart';
import 'task_smart_rules.dart';
import 'task_timeline_screen.dart';
import 'today_tasks_screen.dart';

class TasksEntryScreen extends ConsumerStatefulWidget {
  const TasksEntryScreen({super.key});

  @override
  ConsumerState<TasksEntryScreen> createState() => _TasksEntryScreenState();
}

class _TasksEntryScreenState extends ConsumerState<TasksEntryScreen> {
  String _quickFilter = 'dashboard';
  final Set<int> _selectedTaskIds = <int>{};

  bool get _selectionMode => _selectedTaskIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final categories = ref.watch(categoriesProvider);
    final projects = ref.watch(projectsProvider);
    final progress = TaskSmartRules.dayProgress(tasks);

    final todayTasks = TaskSmartRules.todayTasks(tasks);
    final inboxTasks = TaskSmartRules.inboxTasks(tasks, sortKey: 'created_desc');
    final overdueTasks = tasks.where((task) => TaskSmartRules.isOverdue(task) && TaskSmartRules.isParentTask(task)).toList()..sort(TaskSmartRules.compareByPriorityAndSchedule);
    final nextSevenTasks = tasks.where((task) => TaskSmartRules.isNextSevenDays(task) && TaskSmartRules.isParentTask(task)).toList()..sort(TaskSmartRules.compareByScheduleAndPriority);
    final noDateTasks = tasks.where((task) => TaskSmartRules.isNoDate(task) && TaskSmartRules.isParentTask(task)).toList()..sort(TaskSmartRules.compareByCreatedDesc);
    final highPriorityTasks = tasks.where((task) => TaskSmartRules.isActive(task) && TaskSmartRules.isParentTask(task) && task.priority == 'alta').toList()..sort(TaskSmartRules.compareByPriorityAndSchedule);
    final completedTasks = tasks.where((task) => TaskSmartRules.isCompleted(task) && TaskSmartRules.isParentTask(task)).toList()..sort(TaskSmartRules.compareByCreatedDesc);
    final activeTasks = TaskSmartRules.parentTasks(tasks, includeCompleted: false);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 214,
            title: Text(_selectionMode ? '${_selectedTaskIds.length} selecionada(s)' : 'Produtividade'),
            actions: _selectionMode
                ? [
                    IconButton(tooltip: 'Concluir selecionadas', icon: const Icon(Icons.check_circle_outline), onPressed: _completeSelectedTasks),
                    IconButton(tooltip: 'Limpar seleção', icon: const Icon(Icons.close), onPressed: () => setState(_selectedTaskIds.clear)),
                  ]
                : [
                    IconButton(tooltip: 'Buscar tarefas', icon: const Icon(Icons.search), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskSearchScreen()))),
                    IconButton(tooltip: 'Configurações de tarefas', icon: const Icon(Icons.tune), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskSettingsScreen()))),
                  ],
            flexibleSpace: FlexibleSpaceBar(
              background: _ProductivityHeader(progress: progress, activeCount: activeTasks.length, overdueCount: overdueTasks.length, inboxCount: inboxTasks.length),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: _QuickFilterBar(
                selected: _quickFilter,
                onSelected: (value) => setState(() => _quickFilter = value),
                counts: {
                  'dashboard': activeTasks.length,
                  'today': todayTasks.length,
                  'inbox': inboxTasks.length,
                  'overdue': overdueTasks.length,
                  'next7': nextSevenTasks.length,
                },
              ),
            ),
          ),
          if (_quickFilter != 'dashboard')
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                child: _TaskPreviewSection(
                  title: _filterTitle(_quickFilter),
                  subtitle: _filterSubtitle(_quickFilter),
                  icon: _filterIcon(_quickFilter),
                  color: _filterColor(_quickFilter),
                  tasks: _filteredTasks(_quickFilter, todayTasks, inboxTasks, overdueTasks, nextSevenTasks),
                  emptyTitle: 'Nada por aqui',
                  emptySubtitle: 'Quando houver tarefas nesta visão, elas aparecem aqui.',
                  maxItems: 20,
                  onOpenTask: _openTask,
                  onToggleSelected: _toggleSelected,
                  onCompleteTask: _completeTask,
                  onPostponeTask: _postponeTask,
                  onDeleteTask: _confirmDeleteTask,
                  selectedIds: _selectedTaskIds,
                  selectionMode: _selectionMode,
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _OverdueAlertCard(
                  overdueCount: overdueTasks.length,
                  onReview: () => _openSmartList(TaskSmartListType.overdue),
                  onPostponeAll: overdueTasks.isEmpty ? null : () => _postponeTasksToToday(overdueTasks),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _TaskPreviewSection(
                  title: 'Foco de hoje',
                  subtitle: 'As tarefas que merecem sua atenção agora.',
                  icon: Icons.today,
                  color: Colors.blue,
                  tasks: todayTasks,
                  emptyTitle: 'Hoje está livre',
                  emptySubtitle: 'Capture algo novo ou organize o Inbox para montar seu dia.',
                  viewAllLabel: todayTasks.length > 5 ? 'Ver todas' : null,
                  onViewAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TodayTasksScreen())),
                  onOpenTask: _openTask,
                  onToggleSelected: _toggleSelected,
                  onCompleteTask: _completeTask,
                  onPostponeTask: _postponeTask,
                  onDeleteTask: _confirmDeleteTask,
                  selectedIds: _selectedTaskIds,
                  selectionMode: _selectionMode,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _TaskPreviewSection(
                  title: 'Inbox',
                  subtitle: 'Capturas sem data ou projeto para organizar depois.',
                  icon: Icons.inbox,
                  color: Colors.teal,
                  tasks: inboxTasks,
                  emptyTitle: 'Inbox limpo',
                  emptySubtitle: 'Tudo que foi capturado rapidamente já foi organizado.',
                  viewAllLabel: inboxTasks.length > 5 ? 'Ver Inbox' : null,
                  onViewAll: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxTasksScreen())),
                  onOpenTask: _openTask,
                  onToggleSelected: _toggleSelected,
                  onCompleteTask: _completeTask,
                  onPostponeTask: _postponeTask,
                  onDeleteTask: _confirmDeleteTask,
                  selectedIds: _selectedTaskIds,
                  selectionMode: _selectionMode,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _TaskPreviewSection(
                  title: 'Próximos 7 dias',
                  subtitle: 'O que já está no radar da semana.',
                  icon: Icons.date_range,
                  color: Colors.indigo,
                  tasks: nextSevenTasks,
                  emptyTitle: 'Semana sem tarefas programadas',
                  emptySubtitle: 'Tarefas com data nos próximos dias aparecerão aqui.',
                  viewAllLabel: nextSevenTasks.length > 5 ? 'Ver próximos 7 dias' : null,
                  onViewAll: () => _openSmartList(TaskSmartListType.nextSevenDays),
                  onOpenTask: _openTask,
                  onToggleSelected: _toggleSelected,
                  onCompleteTask: _completeTask,
                  onPostponeTask: _postponeTask,
                  onDeleteTask: _confirmDeleteTask,
                  selectedIds: _selectedTaskIds,
                  selectionMode: _selectionMode,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: _CompactSmartLists(
                  noDateCount: noDateTasks.length,
                  highPriorityCount: highPriorityTasks.length,
                  completedCount: completedTasks.length,
                  onNoDate: () => _openSmartList(TaskSmartListType.noDate),
                  onHighPriority: () => _openSmartList(TaskSmartListType.highPriority),
                  onCompleted: () => _openSmartList(TaskSmartListType.completed),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
                child: _ConnectedModules(
                  categoryCount: categories.length,
                  projectCount: projects.where((project) => project.status != 'completed' && project.status != 'canceled').length,
                  activeCount: activeTasks.length,
                  onClassicList: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskListScreen())),
                  onCalendar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
                  onProjects: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen())),
                  onCategories: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskCategoriesOverviewScreen())),
                  onKanban: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskKanbanScreen())),
                  onMatrix: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskPriorityMatrixScreen())),
                  onTimeline: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskTimelineScreen())),
                  onStats: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskProductivityStatsScreen())),
                  onGeneralStats: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen())),
                ),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: const SmartTaskActionButton(label: 'Capturar tarefa'),
    );
  }

  List<Task> _filteredTasks(String filter, List<Task> today, List<Task> inbox, List<Task> overdue, List<Task> nextSeven) {
    return switch (filter) {
      'today' => today,
      'inbox' => inbox,
      'overdue' => overdue,
      'next7' => nextSeven,
      _ => today,
    };
  }

  String _filterTitle(String filter) => switch (filter) { 'today' => 'Hoje', 'inbox' => 'Inbox', 'overdue' => 'Atrasadas', 'next7' => 'Próximos 7 dias', _ => 'Tarefas' };
  String _filterSubtitle(String filter) => switch (filter) {
        'today' => 'Tarefas de hoje e pendências vencidas.',
        'inbox' => 'Capturas rápidas ainda sem organização.',
        'overdue' => 'Itens vencidos que precisam de decisão.',
        'next7' => 'Compromissos programados para a semana.',
        _ => 'Visão rápida de tarefas.',
      };
  IconData _filterIcon(String filter) => switch (filter) { 'today' => Icons.today, 'inbox' => Icons.inbox, 'overdue' => Icons.warning_amber, 'next7' => Icons.date_range, _ => Icons.dashboard_customize };
  Color _filterColor(String filter) => switch (filter) { 'today' => Colors.blue, 'inbox' => Colors.teal, 'overdue' => Colors.red, 'next7' => Colors.indigo, _ => Colors.blueGrey };

  void _openSmartList(TaskSmartListType type) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TaskSmartListScreen(type: type)));
  }

  void _openTask(Task task) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: task)));
  }

  void _toggleSelected(Task task) {
    if (task.id == null) return;
    setState(() {
      if (_selectedTaskIds.contains(task.id)) {
        _selectedTaskIds.remove(task.id);
      } else {
        _selectedTaskIds.add(task.id!);
      }
    });
  }

  Future<void> _completeSelectedTasks() async {
    final ids = _selectedTaskIds.toSet();
    final selected = ref.read(tasksProvider).where((task) => task.id != null && ids.contains(task.id)).toList();
    setState(_selectedTaskIds.clear);
    for (final task in selected) {
      await _completeTask(task);
    }
  }

  Future<void> _completeTask(Task task) async {
    final status = task.status == 'concluida' ? _statusWhenReopened(task) : 'concluida';
    await ref.read(tasksProvider.notifier).updateTask(task.copyWith(status: status, updatedAt: DateTime.now().toIso8601String()));
  }

  Future<void> _postponeTask(Task task) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final dateText = DateFormat('yyyy-MM-dd').format(tomorrow);
    await ref.read(tasksProvider.notifier).updateTask(task.copyWith(date: dateText, status: 'pendente', updatedAt: DateTime.now().toIso8601String()));
  }

  Future<void> _postponeTasksToToday(List<Task> tasks) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    for (final task in tasks) {
      await ref.read(tasksProvider.notifier).updateTask(task.copyWith(date: today, status: 'pendente', updatedAt: DateTime.now().toIso8601String()));
    }
  }

  Future<void> _confirmDeleteTask(Task task) async {
    if (task.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir tarefa?'),
        content: Text('Deseja excluir "${task.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton.tonalIcon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.delete_outline), label: const Text('Excluir')),
        ],
      ),
    );
    if (confirmed == true) await ref.read(tasksProvider.notifier).removeTask(task.id!);
  }

  String _statusWhenReopened(Task task) => TaskSmartRules.isOverdue(task) ? 'atrasada' : 'pendente';
}

class _ProductivityHeader extends StatelessWidget {
  final TaskDayProgress progress;
  final int activeCount;
  final int overdueCount;
  final int inboxCount;

  const _ProductivityHeader({required this.progress, required this.activeCount, required this.overdueCount, required this.inboxCount});

  @override
  Widget build(BuildContext context) {
    final color = progress.allDone ? Colors.green : Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 82, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.80), Theme.of(context).colorScheme.surface],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(backgroundColor: color.withValues(alpha: 0.14), child: Icon(Icons.task_alt, color: color)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  progress.allDone ? 'Tudo concluído por hoje' : 'Central de produtividade',
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                ),
              ),
              Text('${progress.percent}%', style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w900)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: progress.ratio, minHeight: 9, color: color, backgroundColor: color.withValues(alpha: 0.13))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _HeaderMetric(label: 'Ativas', value: '$activeCount', icon: Icons.radio_button_unchecked)),
              Expanded(child: _HeaderMetric(label: 'Inbox', value: '$inboxCount', icon: Icons.inbox_outlined)),
              Expanded(child: _HeaderMetric(label: 'Atrasadas', value: '$overdueCount', icon: Icons.warning_amber_outlined, danger: overdueCount > 0)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool danger;

  const _HeaderMetric({required this.label, required this.value, required this.icon, this.danger = false});

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.red : Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.72), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withValues(alpha: 0.16))),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700, fontSize: 12))),
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _QuickFilterBar extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;
  final Map<String, int> counts;

  const _QuickFilterBar({required this.selected, required this.onSelected, required this.counts});

  @override
  Widget build(BuildContext context) {
    final filters = [
      ('dashboard', 'Dashboard', Icons.dashboard_customize),
      ('today', 'Hoje', Icons.today),
      ('inbox', 'Inbox', Icons.inbox),
      ('overdue', 'Atrasadas', Icons.warning_amber),
      ('next7', '7 dias', Icons.date_range),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((item) {
          final count = counts[item.$1] ?? 0;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(item.$3, size: 18),
              label: Text('${item.$2} ${count > 0 ? count : ''}'.trim()),
              selected: selected == item.$1,
              onSelected: (_) => onSelected(item.$1),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _OverdueAlertCard extends StatelessWidget {
  final int overdueCount;
  final VoidCallback onReview;
  final VoidCallback? onPostponeAll;

  const _OverdueAlertCard({required this.overdueCount, required this.onReview, required this.onPostponeAll});

  @override
  Widget build(BuildContext context) {
    final hasOverdue = overdueCount > 0;
    final color = hasOverdue ? Colors.red : Colors.green;
    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: color.withValues(alpha: 0.18))),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withValues(alpha: 0.14), child: Icon(hasOverdue ? Icons.warning_amber : Icons.check_circle_outline, color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(hasOverdue ? '$overdueCount tarefa(s) atrasada(s)' : 'Nada atrasado', style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 4),
                Text(hasOverdue ? 'Revise agora ou adie tudo para hoje.' : 'Seu fluxo está em dia.', style: TextStyle(color: Colors.grey.shade700)),
              ]),
            ),
            if (hasOverdue) ...[
              IconButton(tooltip: 'Adiar para hoje', onPressed: onPostponeAll, icon: const Icon(Icons.today)),
              TextButton(onPressed: onReview, child: const Text('Revisar')),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaskPreviewSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final List<Task> tasks;
  final String emptyTitle;
  final String emptySubtitle;
  final int maxItems;
  final String? viewAllLabel;
  final VoidCallback? onViewAll;
  final ValueChanged<Task> onOpenTask;
  final ValueChanged<Task> onToggleSelected;
  final ValueChanged<Task> onCompleteTask;
  final ValueChanged<Task> onPostponeTask;
  final ValueChanged<Task> onDeleteTask;
  final Set<int> selectedIds;
  final bool selectionMode;

  const _TaskPreviewSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.tasks,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onOpenTask,
    required this.onToggleSelected,
    required this.onCompleteTask,
    required this.onPostponeTask,
    required this.onDeleteTask,
    required this.selectedIds,
    required this.selectionMode,
    this.maxItems = 5,
    this.viewAllLabel,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final visibleTasks = tasks.take(maxItems).toList();
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              ])),
              if (viewAllLabel != null && onViewAll != null) TextButton(onPressed: onViewAll, child: Text(viewAllLabel!)),
            ]),
            const SizedBox(height: 10),
            if (visibleTasks.isEmpty)
              _EmptyTaskSection(icon: icon, title: emptyTitle, subtitle: emptySubtitle)
            else
              ...visibleTasks.map((task) => _DashboardTaskTile(
                    task: task,
                    color: color,
                    selected: task.id != null && selectedIds.contains(task.id),
                    selectionMode: selectionMode,
                    onTap: () => selectionMode ? onToggleSelected(task) : onOpenTask(task),
                    onLongPress: () => onToggleSelected(task),
                    onComplete: () => onCompleteTask(task),
                    onPostpone: () => onPostponeTask(task),
                    onDelete: () => onDeleteTask(task),
                  )),
          ],
        ),
      ),
    );
  }
}

class _DashboardTaskTile extends StatelessWidget {
  final Task task;
  final Color color;
  final bool selected;
  final bool selectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onComplete;
  final VoidCallback onPostpone;
  final VoidCallback onDelete;

  const _DashboardTaskTile({required this.task, required this.color, required this.selected, required this.selectionMode, required this.onTap, required this.onLongPress, required this.onComplete, required this.onPostpone, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isDone = task.status == 'concluida';
    final isOverdue = TaskSmartRules.isOverdue(task);
    final tileColor = selected ? color.withValues(alpha: 0.12) : Colors.transparent;
    final subtitle = [_taskDateLabel(task), _priorityLabel(task.priority), if (task.tags?.trim().isNotEmpty == true) task.tags!].join(' • ');

    final tile = Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(color: tileColor, borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        leading: selectionMode
            ? Icon(selected ? Icons.check_circle : Icons.radio_button_unchecked, color: selected ? color : Colors.grey)
            : Checkbox(value: isDone, visualDensity: VisualDensity.compact, onChanged: (_) => onComplete()),
        title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, decoration: isDone ? TextDecoration.lineThrough : null, color: isOverdue ? Colors.red : null)),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Icon(_priorityIcon(task.priority), size: 18, color: _priorityColor(task.priority)),
        onTap: onTap,
        onLongPress: onLongPress,
      ),
    );

    if (selectionMode) return tile;
    return Slidable(
      key: ValueKey('task_dashboard_${task.id ?? task.createdAt}'),
      startActionPane: ActionPane(motion: const DrawerMotion(), extentRatio: 0.32, children: [
        SlidableAction(onPressed: (_) => onComplete(), icon: Icons.check, label: isDone ? 'Reabrir' : 'Concluir', backgroundColor: Colors.green, foregroundColor: Colors.white, borderRadius: BorderRadius.circular(14)),
      ]),
      endActionPane: ActionPane(motion: const DrawerMotion(), extentRatio: 0.58, children: [
        SlidableAction(onPressed: (_) => onPostpone(), icon: Icons.next_plan, label: 'Adiar', backgroundColor: Colors.blue, foregroundColor: Colors.white, borderRadius: BorderRadius.circular(14)),
        SlidableAction(onPressed: (_) => onDelete(), icon: Icons.delete_outline, label: 'Excluir', backgroundColor: Colors.red, foregroundColor: Colors.white, borderRadius: BorderRadius.circular(14)),
      ]),
      child: tile,
    );
  }
}

class _EmptyTaskSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyTaskSection({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Icon(icon, size: 36, color: Colors.grey.shade600),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
      ]),
    );
  }
}\n
class _CompactSmartLists extends StatelessWidget {
  final int noDateCount;
  final int highPriorityCount;
  final int completedCount;
  final VoidCallback onNoDate;
  final VoidCallback onHighPriority;
  final VoidCallback onCompleted;

  const _CompactSmartLists({required this.noDateCount, required this.highPriorityCount, required this.completedCount, required this.onNoDate, required this.onHighPriority, required this.onCompleted});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Listas inteligentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _MiniActionCard(icon: Icons.event_busy, title: 'Sem data', count: noDateCount, color: Colors.orange, onTap: onNoDate)),
        const SizedBox(width: 8),
        Expanded(child: _MiniActionCard(icon: Icons.flag, title: 'Alta', count: highPriorityCount, color: Colors.deepOrange, onTap: onHighPriority)),
        const SizedBox(width: 8),
        Expanded(child: _MiniActionCard(icon: Icons.check_circle_outline, title: 'Feitas', count: completedCount, color: Colors.green, onTap: onCompleted)),
      ]),
    ]);
  }
}

class _ConnectedModules extends StatelessWidget {
  final int categoryCount;
  final int projectCount;
  final int activeCount;
  final VoidCallback onClassicList;
  final VoidCallback onCalendar;
  final VoidCallback onProjects;
  final VoidCallback onCategories;
  final VoidCallback onKanban;
  final VoidCallback onMatrix;
  final VoidCallback onTimeline;
  final VoidCallback onStats;
  final VoidCallback onGeneralStats;

  const _ConnectedModules({required this.categoryCount, required this.projectCount, required this.activeCount, required this.onClassicList, required this.onCalendar, required this.onProjects, required this.onCategories, required this.onKanban, required this.onMatrix, required this.onTimeline, required this.onStats, required this.onGeneralStats});

  @override
  Widget build(BuildContext context) {
    final items = [
      _ModuleItem(Icons.list_alt, 'Lista clássica', '$activeCount ativa(s)', Colors.blueGrey, onClassicList),
      _ModuleItem(Icons.calendar_month, 'Calendário', 'Por data', Colors.purple, onCalendar),
      _ModuleItem(Icons.rocket_launch, 'Projetos', '$projectCount ativo(s)', Colors.deepPurple, onProjects),
      _ModuleItem(Icons.category, 'Categorias', '$categoryCount lista(s)', Colors.amber, onCategories),
      _ModuleItem(Icons.view_kanban, 'Kanban', 'Arraste cards', Colors.indigo, onKanban),
      _ModuleItem(Icons.grid_view, 'Matriz', 'Prioridade', Colors.brown, onMatrix),
      _ModuleItem(Icons.timeline, 'Timeline', 'Linha do tempo', Colors.blueGrey, onTimeline),
      _ModuleItem(Icons.query_stats, 'Produtividade', 'Métricas', Colors.teal, onStats),
      _ModuleItem(Icons.analytics, 'Estatísticas', 'Geral', Colors.grey, onGeneralStats),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Módulos conectados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8, childAspectRatio: 0.98),
        itemBuilder: (context, index) => _ModuleCard(item: items[index]),
      ),
    ]);
  }
}

class _MiniActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int count;
  final Color color;
  final VoidCallback onTap;

  const _MiniActionCard({required this.icon, required this.title, required this.count, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: color.withValues(alpha: 0.16))),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text('$count', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900)),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
            ]),
          ),
        ),
      );
}

class _ModuleCard extends StatelessWidget {
  final _ModuleItem item;

  const _ModuleCard({required this.item});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: item.color.withValues(alpha: 0.14))),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: item.onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(item.icon, color: item.color),
              const Spacer(),
              Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            ]),
          ),
        ),
      );
}

class _ModuleItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ModuleItem(this.icon, this.title, this.subtitle, this.color, this.onTap);
}

String _taskDateLabel(Task task) {
  final date = DateTime.tryParse(task.date ?? '');
  if (date == null) return 'Sem data';
  final formatted = DateFormat('dd/MM').format(date);
  return task.time == null ? formatted : '$formatted ${task.time}';
}

String _priorityLabel(String value) => switch (value) { 'alta' => 'Alta', 'baixa' => 'Baixa', _ => 'Média' };
IconData _priorityIcon(String value) => switch (value) { 'alta' => Icons.flag, 'baixa' => Icons.outlined_flag, _ => Icons.flag_outlined };
Color _priorityColor(String value) => switch (value) { 'alta' => Colors.red, 'baixa' => Colors.green, _ => Colors.orange };
