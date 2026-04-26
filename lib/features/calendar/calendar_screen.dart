import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../domain/providers.dart';
import '../../data/models/task_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/project_model.dart';
import '../../data/models/project_step_model.dart';
import '../../data/models/debt_model.dart';
import '../tasks/create_task_screen.dart';
import '../finance/create_transaction_screen.dart';
import '../debts/debt_details_screen.dart';
import '../projects/project_details_screen.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

enum CalendarEventType { task, expense, income, debtInstallment, projectDeadline, projectStepDeadline }

class CalendarEventItem {
  final CalendarEventType type;
  final String title;
  final DateTime date;
  final dynamic data;
  final int? projectId;

  CalendarEventItem({
    required this.type,
    required this.title,
    required this.date,
    required this.data,
    this.projectId,
  });
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final transactions = ref.watch(transactionsProvider);
    final projects = ref.watch(projectsProvider);
    final debts = ref.watch(debtsProvider);
    final allStepsAsync = ref.watch(allProjectStepsProvider);

    final allSteps = allStepsAsync.value ?? <ProjectStep>[];
    final events = _buildEvents(tasks, transactions, projects, allSteps);

    final selectedEvents = events.where((e) => _isSameDate(e.date, _selectedDay)).toList();

    final taskItems = selectedEvents.where((e) => e.type == CalendarEventType.task).toList();
    final financeItems = selectedEvents.where((e) => e.type == CalendarEventType.expense || e.type == CalendarEventType.income).toList();
    final debtItems = selectedEvents.where((e) => e.type == CalendarEventType.debtInstallment).toList();
    final projectItems = selectedEvents.where((e) => e.type == CalendarEventType.projectDeadline || e.type == CalendarEventType.projectStepDeadline).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Calendário')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTaskScreen())),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            eventLoader: (day) => events.where((e) => isSameDay(e.date, day)).toList(),
            calendarStyle: const CalendarStyle(
              todayDecoration: BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle),
              selectedDecoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, dayEvents) {
                if (dayEvents.isEmpty) return const SizedBox.shrink();
                final items = dayEvents.cast<CalendarEventItem>();
                final colors = items.map((e) => _colorForType(e.type, projects, e.projectId)).toSet().toList();
                return Positioned(
                  bottom: 1,
                  child: Row(
                    children: colors.take(4).map((c) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                    )).toList(),
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: selectedEvents.isEmpty
                ? const Center(child: Text('Nenhum evento para esta data.'))
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    children: [
                      _buildSection('Tarefas', taskItems, projects, debts),
                      _buildSection('Finanças', financeItems, projects, debts),
                      _buildSection('Dívidas', debtItems, projects, debts),
                      _buildSection('Projetos', projectItems, projects, debts),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  List<CalendarEventItem> _buildEvents(
    List<Task> tasks,
    List<FinancialTransaction> transactions,
    List<Project> projects,
    List<ProjectStep> steps,
  ) {
    final events = <CalendarEventItem>[];

    for (final t in tasks) {
      if (t.date == null) continue;
      final dt = DateTime.tryParse(t.date!);
      if (dt == null) continue;
      events.add(CalendarEventItem(type: CalendarEventType.task, title: t.title, date: dt, data: t));
    }

    for (final tr in transactions) {
      if (tr.status == 'canceled') continue;
      if (tr.type == 'expense') {
        final due = tr.dueDate == null ? null : DateTime.tryParse(tr.dueDate!);
        if (due != null) {
          events.add(CalendarEventItem(
            type: tr.debtId != null ? CalendarEventType.debtInstallment : CalendarEventType.expense,
            title: tr.title,
            date: due,
            data: tr,
          ));
        }
      }
      if (tr.type == 'income' && (tr.status == 'pending' || tr.status == 'overdue')) {
        final dt = DateTime.tryParse(tr.dueDate ?? tr.transactionDate);
        if (dt != null) {
          events.add(CalendarEventItem(type: CalendarEventType.income, title: tr.title, date: dt, data: tr));
        }
      }
    }

    for (final p in projects) {
      if (p.endDate == null) continue;
      final dt = DateTime.tryParse(p.endDate!);
      if (dt == null) continue;
      events.add(CalendarEventItem(type: CalendarEventType.projectDeadline, title: p.name, date: dt, data: p, projectId: p.id));
    }

    for (final s in steps) {
      if (s.dueDate == null || s.status == 'canceled') continue;
      final dt = DateTime.tryParse(s.dueDate!);
      if (dt == null) continue;
      events.add(CalendarEventItem(
        type: CalendarEventType.projectStepDeadline,
        title: s.title,
        date: dt,
        data: s,
        projectId: s.projectId,
      ));
    }

    return events;
  }

  Widget _buildSection(String title, List<CalendarEventItem> items, List<Project> projects, List<Debt> debts) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            ...items.map((e) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.circle, size: 12, color: _colorForType(e.type, projects, e.projectId)),
                  title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_labelForType(e.type)),
                  onTap: () => _openEventDetails(e, debts, projects),
                )),
          ],
        ),
      ),
    );
  }

  void _openEventDetails(CalendarEventItem e, List<Debt> debts, List<Project> projects) {
    if (e.type == CalendarEventType.task) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: e.data as Task)));
      return;
    }

    if (e.type == CalendarEventType.expense || e.type == CalendarEventType.income) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTransactionScreen(transaction: e.data as FinancialTransaction)));
      return;
    }

    if (e.type == CalendarEventType.debtInstallment) {
      final tr = e.data as FinancialTransaction;
      final idx = debts.indexWhere((d) => d.id == tr.debtId);
      if (idx != -1) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => DebtDetailsScreen(debt: debts[idx])));
      }
      return;
    }

    if (e.type == CalendarEventType.projectDeadline) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailsScreen(project: e.data as Project)));
      return;
    }

    if (e.type == CalendarEventType.projectStepDeadline) {
      final idx = projects.indexWhere((p) => p.id == e.projectId);
      if (idx != -1) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailsScreen(project: projects[idx])));
      }
    }
  }

  Color _colorForType(CalendarEventType type, List<Project> projects, int? projectId) {
    switch (type) {
      case CalendarEventType.task:
        return Colors.blue;
      case CalendarEventType.expense:
        return Colors.red;
      case CalendarEventType.income:
        return Colors.green;
      case CalendarEventType.debtInstallment:
        return Colors.orange;
      case CalendarEventType.projectDeadline:
        return Colors.purple;
      case CalendarEventType.projectStepDeadline:
        if (projectId == null) return Colors.indigo;
        final idx = projects.indexWhere((p) => p.id == projectId);
        if (idx == -1) return Colors.indigo;
        return Color(int.parse(projects[idx].color));
    }
  }

  String _labelForType(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.task:
        return 'Tarefa';
      case CalendarEventType.expense:
        return 'Despesa';
      case CalendarEventType.income:
        return 'Receita prevista';
      case CalendarEventType.debtInstallment:
        return 'Parcela de dívida';
      case CalendarEventType.projectDeadline:
        return 'Prazo do projeto';
      case CalendarEventType.projectStepDeadline:
        return 'Prazo da etapa';
    }
  }

  bool _isSameDate(DateTime date, DateTime? selected) {
    if (selected == null) return false;
    return date.year == selected.year && date.month == selected.month && date.day == selected.day;
  }
}
