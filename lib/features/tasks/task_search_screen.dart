import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/task_model.dart';
import '../../domain/providers.dart';
import 'create_task_screen.dart';
import 'quick_add_task_button.dart';
import 'task_smart_rules.dart';

class TaskSearchScreen extends ConsumerStatefulWidget {
  const TaskSearchScreen({super.key});

  @override
  ConsumerState<TaskSearchScreen> createState() => _TaskSearchScreenState();
}

class _TaskSearchScreenState extends ConsumerState<TaskSearchScreen> {
  final _queryController = TextEditingController();
  String _status = 'all';
  String _priority = 'all';
  String _scope = 'parents';

  @override
  void initState() {
    super.initState();
    _queryController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<Task> _filtered(List<Task> tasks) {
    final query = _queryController.text.trim().toLowerCase();
    final result = tasks.where((task) {
      if (TaskSmartRules.isCanceled(task)) return false;
      if (_scope == 'parents' && !TaskSmartRules.isParentTask(task)) return false;
      if (_scope == 'subtasks' && !TaskSmartRules.isSubtask(task)) return false;
      if (_scope == 'dated' && !TaskSmartRules.hasDate(task)) return false;
      if (_scope == 'nodate' && TaskSmartRules.hasDate(task)) return false;
      if (_status != 'all' && task.status != _status) return false;
      if (_priority != 'all' && task.priority != _priority) return false;
      if (query.isEmpty) return true;
      return '${task.title} ${task.description ?? ''}'.toLowerCase().contains(query);
    }).toList();
    result.sort(TaskSmartRules.compareByScheduleAndPriority);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _filtered(ref.watch(tasksProvider));
    final active = tasks.where(TaskSmartRules.isActive).length;
    final completed = tasks.where(TaskSmartRules.isCompleted).length;
    final overdue = tasks.where((task) => TaskSmartRules.isOverdue(task)).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar tarefas'), actions: const [QuickAddTaskIconButton()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _Header(total: tasks.length, active: active, completed: completed, overdue: overdue),
          const SizedBox(height: 16),
          TextField(
            controller: _queryController,
            decoration: InputDecoration(
              labelText: 'Buscar por título ou descrição',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _queryController.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: _queryController.clear),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _Filters(
            status: _status,
            priority: _priority,
            scope: _scope,
            onStatus: (value) => setState(() => _status = value),
            onPriority: (value) => setState(() => _priority = value),
            onScope: (value) => setState(() => _scope = value),
          ),
          const SizedBox(height: 16),
          if (tasks.isEmpty) const _EmptyState() else ...tasks.map((task) => _TaskTile(task: task)),
        ],
      ),
      floatingActionButton: const QuickAddTaskButton(label: 'Capturar'),
    );
  }
}

class _Header extends StatelessWidget {
  final int total;
  final int active;
  final int completed;
  final int overdue;

  const _Header({required this.total, required this.active, required this.completed, required this.overdue});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          const CircleAvatar(child: Icon(Icons.manage_search)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Busca e filtros', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('$total resultados • $active ativas • $completed concluídas • $overdue atrasadas', style: const TextStyle(color: Colors.grey)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Filters extends StatelessWidget {
  final String status;
  final String priority;
  final String scope;
  final ValueChanged<String> onStatus;
  final ValueChanged<String> onPriority;
  final ValueChanged<String> onScope;

  const _Filters({required this.status, required this.priority, required this.scope, required this.onStatus, required this.onPriority, required this.onScope});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Filtros', style: TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _Chip(label: 'Todas', selected: status == 'all', onTap: () => onStatus('all')),
        _Chip(label: 'Pendentes', selected: status == 'pendente', onTap: () => onStatus('pendente')),
        _Chip(label: 'Atrasadas', selected: status == 'atrasada', onTap: () => onStatus('atrasada')),
        _Chip(label: 'Concluídas', selected: status == 'concluida', onTap: () => onStatus('concluida')),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _Chip(label: 'Prioridade: todas', selected: priority == 'all', onTap: () => onPriority('all')),
        _Chip(label: 'Alta', selected: priority == 'alta', onTap: () => onPriority('alta')),
        _Chip(label: 'Média', selected: priority == 'media', onTap: () => onPriority('media')),
        _Chip(label: 'Baixa', selected: priority == 'baixa', onTap: () => onPriority('baixa')),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _Chip(label: 'Tarefas pai', selected: scope == 'parents', onTap: () => onScope('parents')),
        _Chip(label: 'Subtarefas', selected: scope == 'subtasks', onTap: () => onScope('subtasks')),
        _Chip(label: 'Com data', selected: scope == 'dated', onTap: () => onScope('dated')),
        _Chip(label: 'Sem data', selected: scope == 'nodate', onTap: () => onScope('nodate')),
        _Chip(label: 'Tudo', selected: scope == 'all', onTap: () => onScope('all')),
      ]),
    ]);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap());
}

class _TaskTile extends ConsumerWidget {
  final Task task;
  const _TaskTile({required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final done = TaskSmartRules.isCompleted(task);
    final overdue = TaskSmartRules.isOverdue(task);
    final scheduled = TaskSmartRules.scheduledDateTime(task);
    final dateLabel = scheduled == null ? 'Sem data' : '${scheduled.day.toString().padLeft(2, '0')}/${scheduled.month.toString().padLeft(2, '0')}${TaskSmartRules.hasTime(task) ? ' ${task.time}' : ''}';

    return Card(
      child: ListTile(
        leading: IconButton(
          icon: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? Colors.green : overdue ? Colors.red : Colors.grey),
          onPressed: () {
            final nextStatus = done ? (overdue ? 'atrasada' : 'pendente') : 'concluida';
            ref.read(tasksProvider.notifier).updateTask(task.copyWith(status: nextStatus, updatedAt: DateTime.now().toIso8601String()));
          },
        ),
        title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(decoration: done ? TextDecoration.lineThrough : null)),
        subtitle: Text('$dateLabel • ${task.priority} • ${task.status}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: task))),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(children: [
        Icon(Icons.search_off, size: 54, color: Colors.grey),
        SizedBox(height: 12),
        Text('Nenhuma tarefa encontrada.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SizedBox(height: 6),
        Text('Ajuste os filtros ou busque por outro termo.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
      ]),
    );
  }
}
