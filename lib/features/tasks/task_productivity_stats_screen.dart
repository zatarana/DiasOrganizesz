import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/task_model.dart';
import '../../domain/providers.dart';
import 'quick_add_task_button.dart';
import 'task_smart_rules.dart';

class TaskProductivityStatsScreen extends ConsumerWidget {
  const TaskProductivityStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider).where(TaskSmartRules.isParentTask).toList();
    final active = tasks.where(TaskSmartRules.isActive).length;
    final completed = tasks.where(TaskSmartRules.isCompleted).length;
    final overdue = tasks.where(TaskSmartRules.isOverdue).length;
    final noDate = tasks.where(TaskSmartRules.isNoDate).length;
    final today = tasks.where((task) => TaskSmartRules.isExactlyToday(task)).length;
    final nextSeven = tasks.where(TaskSmartRules.isNextSevenDays).length;
    final highPriority = tasks.where((task) => TaskSmartRules.isActive(task) && task.priority == 'alta').length;
    final total = tasks.where((task) => !TaskSmartRules.isCanceled(task)).length;
    final completionRate = total == 0 ? 0.0 : completed / total;
    final todayProgress = TaskSmartRules.dayProgress(tasks);
    final completedThisWeek = _completedSince(tasks, DateTime.now().subtract(const Duration(days: 7)));
    final completedThisMonth = _completedSince(tasks, DateTime(DateTime.now().year, DateTime.now().month, 1));
    final priorityCounts = _priorityCounts(tasks);
    final statusCounts = _statusCounts(tasks);

    return Scaffold(
      appBar: AppBar(title: const Text('Estatísticas de tarefas'), actions: const [QuickAddTaskIconButton()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _StatsHeader(completionRate: completionRate, total: total, completed: completed),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.18,
            children: [
              _MetricCard(icon: Icons.pending_actions, title: 'Ativas', value: '$active', color: Colors.blue),
              _MetricCard(icon: Icons.check_circle, title: 'Concluídas', value: '$completed', color: Colors.green),
              _MetricCard(icon: Icons.warning_amber, title: 'Atrasadas', value: '$overdue', color: Colors.red),
              _MetricCard(icon: Icons.event_busy, title: 'Sem data', value: '$noDate', color: Colors.orange),
              _MetricCard(icon: Icons.today, title: 'Hoje', value: '$today', color: Colors.indigo),
              _MetricCard(icon: Icons.date_range, title: 'Próximos 7 dias', value: '$nextSeven', color: Colors.purple),
              _MetricCard(icon: Icons.flag, title: 'Alta prioridade', value: '$highPriority', color: Colors.deepOrange),
              _MetricCard(icon: Icons.history, title: 'Semana', value: '$completedThisWeek', color: Colors.teal),
            ],
          ),
          const SizedBox(height: 16),
          _ProgressPanel(
            title: 'Progresso de hoje',
            subtitle: todayProgress.total == 0 ? 'Nenhuma tarefa exatamente marcada para hoje.' : '${todayProgress.completed}/${todayProgress.total} tarefas concluídas hoje.',
            value: todayProgress.ratio,
            percent: todayProgress.percent,
            color: Colors.blue,
          ),
          const SizedBox(height: 12),
          _ProgressPanel(
            title: 'Taxa geral de conclusão',
            subtitle: total == 0 ? 'Ainda não há tarefas suficientes para calcular.' : '$completed de $total tarefas não canceladas concluídas.',
            value: completionRate,
            percent: (completionRate * 100).round(),
            color: Colors.green,
          ),
          const SizedBox(height: 16),
          _DistributionPanel(title: 'Distribuição por prioridade', items: priorityCounts, colors: const {
            'alta': Colors.red,
            'media': Colors.orange,
            'baixa': Colors.blue,
            'sem prioridade': Colors.grey,
          }),
          const SizedBox(height: 16),
          _DistributionPanel(title: 'Distribuição por status', items: statusCounts, colors: const {
            'pendente': Colors.blue,
            'atrasada': Colors.red,
            'concluida': Colors.green,
            'canceled': Colors.grey,
          }),
          const SizedBox(height: 16),
          _InsightPanel(
            completedThisWeek: completedThisWeek,
            completedThisMonth: completedThisMonth,
            overdue: overdue,
            noDate: noDate,
            highPriority: highPriority,
          ),
        ],
      ),
      floatingActionButton: const QuickAddTaskButton(label: 'Capturar'),
    );
  }

  int _completedSince(List<Task> tasks, DateTime since) {
    return tasks.where((task) {
      if (!TaskSmartRules.isCompleted(task)) return false;
      final updated = DateTime.tryParse(task.updatedAt);
      if (updated == null) return false;
      return !updated.isBefore(since);
    }).length;
  }

  Map<String, int> _priorityCounts(List<Task> tasks) {
    final result = <String, int>{'alta': 0, 'media': 0, 'baixa': 0, 'sem prioridade': 0};
    for (final task in tasks.where((task) => !TaskSmartRules.isCanceled(task))) {
      if (task.priority == 'alta' || task.priority == 'media' || task.priority == 'baixa') {
        result[task.priority] = (result[task.priority] ?? 0) + 1;
      } else {
        result['sem prioridade'] = (result['sem prioridade'] ?? 0) + 1;
      }
    }
    return result;
  }

  Map<String, int> _statusCounts(List<Task> tasks) {
    final result = <String, int>{'pendente': 0, 'atrasada': 0, 'concluida': 0, 'canceled': 0};
    for (final task in tasks) {
      result[task.status] = (result[task.status] ?? 0) + 1;
    }
    return result;
  }
}

class _StatsHeader extends StatelessWidget {
  final double completionRate;
  final int total;
  final int completed;

  const _StatsHeader({required this.completionRate, required this.total, required this.completed});

  @override
  Widget build(BuildContext context) {
    final percent = (completionRate * 100).round();
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const CircleAvatar(child: Icon(Icons.query_stats)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Produtividade em tarefas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(total == 0 ? 'Sem dados suficientes ainda.' : '$completed/$total concluídas no histórico atual.', style: const TextStyle(color: Colors.grey)),
              ]),
            ),
            Text('$percent%', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _MetricCard({required this.icon, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
        ]),
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final int percent;
  final Color color;

  const _ProgressPanel({required this.title, required this.subtitle, required this.value, required this.percent, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
            Text('$percent%', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: value.clamp(0, 1), color: color),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: Colors.grey)),
        ]),
      ),
    );
  }
}

class _DistributionPanel extends StatelessWidget {
  final String title;
  final Map<String, int> items;
  final Map<String, Color> colors;

  const _DistributionPanel({required this.title, required this.items, required this.colors});

  @override
  Widget build(BuildContext context) {
    final total = items.values.fold<int>(0, (sum, value) => sum + value);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...items.entries.map((entry) {
            final ratio = total == 0 ? 0.0 : entry.value / total;
            final color = colors[entry.key] ?? Colors.grey;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(entry.key)),
                  Text('${entry.value}', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: ratio, color: color),
              ]),
            );
          }),
        ]),
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  final int completedThisWeek;
  final int completedThisMonth;
  final int overdue;
  final int noDate;
  final int highPriority;

  const _InsightPanel({required this.completedThisWeek, required this.completedThisMonth, required this.overdue, required this.noDate, required this.highPriority});

  @override
  Widget build(BuildContext context) {
    final insights = <String>[
      'Concluídas nos últimos 7 dias: $completedThisWeek.',
      'Concluídas neste mês: $completedThisMonth.',
      if (overdue > 0) 'Há $overdue tarefa(s) atrasada(s) pedindo revisão.',
      if (noDate > 0) 'Há $noDate tarefa(s) sem data para organizar.',
      if (highPriority > 0) 'Há $highPriority tarefa(s) de alta prioridade ainda ativa(s).',
      if (overdue == 0 && highPriority == 0) 'Sem atrasos críticos ou alta prioridade ativa no momento.',
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Leitura rápida', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...insights.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check_circle_outline, size: 16, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(child: Text(item)),
                ]),
              )),
        ]),
      ),
    );
  }
}
