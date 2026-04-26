import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
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

  CalendarEventItem({required this.type, required this.title, required this.date, required this.data, this.projectId});
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
    final selectedEvents = events.where((e) => _isSameDate(e.date, _selectedDay)).toList()..sort((a, b) => a.date.compareTo(b.date));

    final taskItems = selectedEvents.where((e) => e.type == CalendarEventType.task).toList();
    final financeItems = selectedEvents.where((e) => e.type == CalendarEventType.expense || e.type == CalendarEventType.income).toList();
    final debtItems = selectedEvents.where((e) => e.type == CalendarEventType.debtInstallment).toList();
    final projectItems = selectedEvents.where((e) => e.type == CalendarEventType.projectDeadline || e.type == CalendarEventType.projectStepDeadline).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Calendário')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CreateTaskScreen(selectedDate: _selectedDay ?? DateTime.now())),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Tarefa'),
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
                    children: colors
                        .take(4)
                        .map((c) => Container(
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                            ))
                        .toList(),
                  ),
                );
              },
            ),
          ),
          const Divider(),
          if (allStepsAsync.hasError)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Não foi possível carregar etapas de projetos no calendário.', style: TextStyle(color: Colors.orange.shade800, fontSize: 12))),
                ],
              ),
            ),
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

  List<CalendarEventItem> _buildEvents(List<Task> tasks, List<FinancialTransaction> transactions, List<Project> projects, List<ProjectStep> steps) {
    final events = <CalendarEventItem>[];
    final activeProjectIds = projects.where((p) => p.status != 'completed' && p.status != 'canceled').map((p) => p.id).whereType<int>().toSet();

    for (final task in tasks) {
      if (task.date == null || task.status == 'canceled') continue;
      final date = DateTime.tryParse(task.date!);
      if (date == null) continue;
      events.add(CalendarEventItem(type: CalendarEventType.task, title: task.title, date: date, data: task, projectId: task.projectId));
    }

    for (final transaction in transactions) {
      if (transaction.status == 'canceled') continue;
      final expectedDate = DateTime.tryParse(transaction.dueDate ?? transaction.transactionDate);
      if (expectedDate != null) {
        events.add(CalendarEventItem(
          type: transaction.debtId != null ? CalendarEventType.debtInstallment : (transaction.type == 'income' ? CalendarEventType.income : CalendarEventType.expense),
          title: transaction.title,
          date: expectedDate,
          data: transaction,
        ));
      }

      if (transaction.status == 'paid' && transaction.paidDate != null) {
        final paidDate = DateTime.tryParse(transaction.paidDate!);
        if (paidDate != null && (expectedDate == null || !_isSameDate(paidDate, expectedDate))) {
          events.add(CalendarEventItem(
            type: transaction.debtId != null ? CalendarEventType.debtInstallment : (transaction.type == 'income' ? CalendarEventType.income : CalendarEventType.expense),
            title: '${transaction.title} (pago)',
            date: paidDate,
            data: transaction,
          ));
        }
      }
    }

    for (final project in projects) {
      if (project.endDate == null || project.status == 'completed' || project.status == 'canceled') continue;
      final date = DateTime.tryParse(project.endDate!);
      if (date == null) continue;
      events.add(CalendarEventItem(type: CalendarEventType.projectDeadline, title: project.name, date: date, data: project, projectId: project.id));
    }

    for (final step in steps) {
      if (step.dueDate == null || step.status == 'canceled' || step.status == 'completed') continue;
      if (!activeProjectIds.contains(step.projectId)) continue;
      final date = DateTime.tryParse(step.dueDate!);
      if (date == null) continue;
      events.add(CalendarEventItem(type: CalendarEventType.projectStepDeadline, title: step.title, date: date, data: step, projectId: step.projectId));
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
            ...items.map((event) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.circle, size: 12, color: _colorForType(event.type, projects, event.projectId)),
                  title: Text(event.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(_subtitleForEvent(event, debts)),
                  onTap: () => _openEventDetails(event, debts, projects),
                )),
          ],
        ),
      ),
    );
  }

  String _subtitleForEvent(CalendarEventItem event, List<Debt> debts) {
    final base = _labelForType(event.type);
    if (event.data is FinancialTransaction) {
      final transaction = event.data as FinancialTransaction;
      final debtMissing = transaction.debtId != null && !debts.any((debt) => debt.id == transaction.debtId);
      final debtNote = debtMissing ? ' • dívida removida' : '';
      return '$base • R\$ ${transaction.amount.toStringAsFixed(2)} • ${_statusLabel(transaction.status)}$debtNote';
    }
    if (event.data is Task) {
      final task = event.data as Task;
      return '$base • ${_statusLabel(task.status)} • ${task.time ?? 'sem horário'}';
    }
    if (event.data is ProjectStep) {
      final step = event.data as ProjectStep;
      return '$base • ${_statusLabel(step.status)}';
    }
    if (event.data is Project) {
      final project = event.data as Project;
      return '$base • ${_statusLabel(project.status)}';
    }
    return base;
  }

  void _openEventDetails(CalendarEventItem event, List<Debt> debts, List<Project> projects) {
    if (event.type == CalendarEventType.task) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: event.data as Task)));
      return;
    }

    if (event.type == CalendarEventType.expense || event.type == CalendarEventType.income) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTransactionScreen(transaction: event.data as FinancialTransaction)));
      return;
    }

    if (event.type == CalendarEventType.debtInstallment) {
      final transaction = event.data as FinancialTransaction;
      final index = debts.indexWhere((debt) => debt.id == transaction.debtId);
      if (index != -1) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => DebtDetailsScreen(debt: debts[index])));
      } else {
        Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTransactionScreen(transaction: transaction)));
      }
      return;
    }

    if (event.type == CalendarEventType.projectDeadline) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailsScreen(project: event.data as Project)));
      return;
    }

    if (event.type == CalendarEventType.projectStepDeadline) {
      final index = projects.indexWhere((project) => project.id == event.projectId && project.status != 'canceled');
      if (index != -1) Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailsScreen(project: projects[index])));
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
        final index = projects.indexWhere((project) => project.id == projectId);
        if (index == -1) return Colors.indigo;
        return Color(int.tryParse(projects[index].color) ?? 0xFF3F51B5);
    }
  }

  String _labelForType(CalendarEventType type) {
    switch (type) {
      case CalendarEventType.task:
        return 'Tarefa';
      case CalendarEventType.expense:
        return 'Despesa';
      case CalendarEventType.income:
        return 'Receita';
      case CalendarEventType.debtInstallment:
        return 'Parcela de dívida';
      case CalendarEventType.projectDeadline:
        return 'Prazo do projeto';
      case CalendarEventType.projectStepDeadline:
        return 'Prazo da etapa';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'pago';
      case 'pending':
      case 'pendente':
        return 'pendente';
      case 'overdue':
      case 'atrasada':
        return 'atrasado';
      case 'completed':
      case 'concluida':
        return 'concluído';
      case 'active':
        return 'ativo';
      case 'paused':
        return 'pausado';
      case 'canceled':
        return 'cancelado';
      default:
        return status;
    }
  }

  bool _isSameDate(DateTime date, DateTime? selected) {
    if (selected == null) return false;
    return date.year == selected.year && date.month == selected.month && date.day == selected.day;
  }
}
