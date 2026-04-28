import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'today_tasks_screen.dart';

class TasksEntryScreen extends ConsumerWidget {
  const TasksEntryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final progress = TaskSmartRules.dayProgress(tasks);
    final todayCount = TaskSmartRules.todayTasks(tasks).length;
    final inboxCount = TaskSmartRules.inboxTasks(tasks).length;
    final overdueCount = tasks.where((task) => TaskSmartRules.isOverdue(task) && TaskSmartRules.isParentTask(task)).length;
    final noDateCount = tasks.where((task) => TaskSmartRules.isNoDate(task) && TaskSmartRules.isParentTask(task)).length;
    final nextSevenCount = tasks.where((task) => TaskSmartRules.isNextSevenDays(task) && TaskSmartRules.isParentTask(task)).length;
    final highPriorityCount = tasks.where((task) => TaskSmartRules.isActive(task) && TaskSmartRules.isParentTask(task) && task.priority == 'alta').length;
    final activeCount = TaskSmartRules.parentTasks(tasks, includeCompleted: false).length;
    final completedCount = tasks.where((task) => TaskSmartRules.isCompleted(task) && TaskSmartRules.isParentTask(task)).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tarefas'),
        actions: [
          IconButton(
            tooltip: 'Configurações de tarefas',
            icon: const Icon(Icons.tune),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskSettingsScreen())),
          ),
          IconButton(
            tooltip: 'Criação completa',
            icon: const Icon(Icons.edit_note),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTaskScreen())),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TaskEntryHeader(progress: progress),
          const SizedBox(height: 16),
          _EntrySection(
            title: 'Uso diário',
            subtitle: 'Comece pelo que precisa de atenção agora.',
            children: [
              _EntryCard(
                icon: Icons.today,
                title: 'Hoje',
                subtitle: 'Tarefas do dia, atrasadas e sugestões imediatas.',
                count: todayCount,
                color: Colors.blue,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TodayTasksScreen())),
              ),
              _EntryCard(
                icon: Icons.inbox,
                title: 'Inbox',
                subtitle: 'Captura rápida sem data ou projeto para organizar depois.',
                count: inboxCount,
                color: Colors.teal,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InboxTasksScreen())),
              ),
              _EntryCard(
                icon: Icons.warning_amber,
                title: 'Atrasadas',
                subtitle: 'Pendências vencidas que precisam ser revistas.',
                count: overdueCount,
                color: Colors.red,
                onTap: () => _openSmartList(context, TaskSmartListType.overdue),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _EntrySection(
            title: 'Planejamento',
            subtitle: 'Organize o que vem pela frente sem perder o contexto.',
            children: [
              _EntryCard(
                icon: Icons.date_range,
                title: 'Próximos 7 dias',
                subtitle: 'Tarefas programadas para a próxima semana.',
                count: nextSevenCount,
                color: Colors.indigo,
                onTap: () => _openSmartList(context, TaskSmartListType.nextSevenDays),
              ),
              _EntryCard(
                icon: Icons.event_busy,
                title: 'Sem data',
                subtitle: 'Tarefas ativas ainda sem agendamento.',
                count: noDateCount,
                color: Colors.orange,
                onTap: () => _openSmartList(context, TaskSmartListType.noDate),
              ),
              _EntryCard(
                icon: Icons.flag,
                title: 'Alta prioridade',
                subtitle: 'Tudo que foi marcado como prioridade alta.',
                count: highPriorityCount,
                color: Colors.deepOrange,
                onTap: () => _openSmartList(context, TaskSmartListType.highPriority),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _EntrySection(
            title: 'Visões avançadas',
            subtitle: 'Busque, reorganize e visualize tarefas em formatos diferentes.',
            children: [
              _EntryCard(
                icon: Icons.manage_search,
                title: 'Buscar e filtrar',
                subtitle: 'Pesquisa por texto, status, prioridade e escopo.',
                color: Colors.cyan,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskSearchScreen())),
              ),
              _EntryCard(
                icon: Icons.category,
                title: 'Listas e categorias',
                subtitle: 'Categorias atuais como listas visuais de tarefas.',
                color: Colors.amber,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskCategoriesOverviewScreen())),
              ),
              _EntryCard(
                icon: Icons.view_kanban,
                title: 'Kanban',
                subtitle: 'Colunas de atrasadas, pendentes e concluídas.',
                color: Colors.deepPurple,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskKanbanScreen())),
              ),
              _EntryCard(
                icon: Icons.grid_view,
                title: 'Matriz de prioridade',
                subtitle: 'Cruza prioridade e data para decisão rápida.',
                color: Colors.brown,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskPriorityMatrixScreen())),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _EntrySection(
            title: 'Visões e módulos conectados',
            subtitle: 'Mantenha tarefas conectadas ao restante do app.',
            children: [
              _EntryCard(
                icon: Icons.list_alt,
                title: 'Lista clássica',
                subtitle: 'Tela atual preservada com busca, filtros e subtarefas.',
                count: activeCount,
                color: Colors.blueGrey,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskListScreen())),
              ),
              _EntryCard(
                icon: Icons.check_circle_outline,
                title: 'Concluídas',
                subtitle: 'Histórico básico de tarefas concluídas.',
                count: completedCount,
                color: Colors.green,
                onTap: () => _openSmartList(context, TaskSmartListType.completed),
              ),
              _EntryCard(
                icon: Icons.calendar_month,
                title: 'Calendário',
                subtitle: 'Veja tarefas distribuídas por data.',
                color: Colors.purple,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
              ),
              _EntryCard(
                icon: Icons.rocket_launch,
                title: 'Projetos',
                subtitle: 'Tarefas vinculadas continuam compondo progresso dos projetos.',
                color: Colors.deepPurple,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen())),
              ),
              _EntryCard(
                icon: Icons.query_stats,
                title: 'Produtividade',
                subtitle: 'Estatísticas específicas de tarefas e conclusão.',
                color: Colors.brown,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskProductivityStatsScreen())),
              ),
              _EntryCard(
                icon: Icons.settings,
                title: 'Configurações de tarefas',
                subtitle: 'Preferências da Central, cards, Quick Add e listas.',
                color: Colors.blueGrey,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskSettingsScreen())),
              ),
              _EntryCard(
                icon: Icons.analytics,
                title: 'Estatísticas gerais',
                subtitle: 'Painel estatístico geral do aplicativo.',
                color: Colors.grey,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen())),
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
      floatingActionButton: const QuickAddTaskButton(label: 'Quick Add'),
    );
  }

  void _openSmartList(BuildContext context, TaskSmartListType type) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TaskSmartListScreen(type: type)));
  }
}

class _TaskEntryHeader extends StatelessWidget {
  final TaskDayProgress progress;

  const _TaskEntryHeader({required this.progress});

  @override
  Widget build(BuildContext context) {
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
                const CircleAvatar(child: Icon(Icons.task_alt)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    progress.allDone ? 'Tudo concluído por hoje' : 'Central de produtividade',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Text('${progress.percent}%', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress.ratio),
            const SizedBox(height: 10),
            Text(
              progress.total == 0
                  ? 'Nenhuma tarefa exatamente para hoje. Use Inbox ou Próximos 7 dias para planejar.'
                  : '${progress.completed}/${progress.total} tarefas de hoje concluídas.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntrySection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _EntrySection({required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final int? count;
  final Color color;
  final VoidCallback onTap;

  const _EntryCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap, this.count});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
                child: Text('$count', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
