import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/finance_planning_store.dart';
import '../../domain/providers.dart';
import '../../data/models/task_model.dart';
import '../calendar/calendar_screen.dart';
import '../categories/categories_screen.dart';
import '../finance/finance_screen.dart';
import '../projects/projects_screen.dart';
import '../settings/settings_screen.dart';
import '../statistics/stats_screen.dart';
import '../tasks/create_task_screen.dart';
import '../tasks/task_list_screen.dart';
import 'app_drawer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages = [
    const TaskDashboard(),
    const TaskListScreen(),
    const FinanceScreen(),
    const ProjectsScreen(),
    const MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final showFab = _currentIndex == 0 || _currentIndex == 1;

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      floatingActionButton: showFab
          ? FloatingActionButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTaskScreen())),
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Tarefas'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Finanças'),
          BottomNavigationBarItem(icon: Icon(Icons.rocket_launch), label: 'Projetos'),
          BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Mais'),
        ],
      ),
    );
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mais módulos')),
      body: ListView(
        children: const [
          ListTile(title: Text('Outros recursos', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
          _MoreTile(icon: Icons.calendar_month, title: 'Calendário', page: CalendarScreen()),
          _MoreTile(icon: Icons.category, title: 'Categorias', page: CategoriesScreen()),
          _MoreTile(icon: Icons.pie_chart, title: 'Estatísticas', page: StatsScreen()),
          _MoreTile(icon: Icons.settings, title: 'Configurações', page: SettingsScreen()),
        ],
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget page;

  const _MoreTile({required this.icon, required this.title, this.subtitle, required this.page});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
    );
  }
}

class TaskDashboard extends ConsumerStatefulWidget {
  const TaskDashboard({super.key});

  @override
  ConsumerState<TaskDashboard> createState() => _TaskDashboardState();
}

class _TaskDashboardState extends ConsumerState<TaskDashboard> {
  bool _valuesRevealed = false;

  Future<double> _loadRealAccountBalance() async {
    final db = await ref.read(dbProvider).database;
    return FinancePlanningStore.getActiveAccountsBalance(db);
  }

  bool _isTaskOverdue(Task task) {
    if (task.date == null) return false;
    final date = DateTime.tryParse(task.date!);
    if (date == null) return false;

    if (task.time != null) {
      final parts = task.time!.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 23;
        final minute = int.tryParse(parts[1]) ?? 59;
        return DateTime(date.year, date.month, date.day, hour, minute).isBefore(DateTime.now());
      }
    }

    return DateTime(date.year, date.month, date.day, 23, 59, 59).isBefore(DateTime.now());
  }

  String _statusWhenReopened(Task task) => _isTaskOverdue(task) ? 'atrasada' : 'pendente';

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final transactions = ref.watch(transactionsProvider);
    final projects = ref.watch(projectsProvider);
    final debts = ref.watch(debtsProvider);
    final appSettings = ref.watch(appSettingsProvider);

    final currency = appSettings[AppSettingKeys.defaultCurrency] ?? 'BRL';
    final homeShowsValues = (appSettings[AppSettingKeys.homeShowFinancialValues] ?? 'true') == 'true';
    final visualLockEnabled = (appSettings[AppSettingKeys.financeVisualLock] ?? 'false') == 'true';
    final privacyHideHomeValues = (appSettings[AppSettingKeys.privacyHideHomeValues] ?? 'false') == 'true';
    final financeDiscreteMode = (appSettings[AppSettingKeys.financeDiscreteMode] ?? 'false') == 'true';
    final canTemporarilyRevealValues = visualLockEnabled && homeShowsValues && !privacyHideHomeValues && !financeDiscreteMode;
    final hideValues = privacyHideHomeValues || financeDiscreteMode || !homeShowsValues || (visualLockEnabled && !_valuesRevealed);
    final showProjectsCard = (appSettings[AppSettingKeys.homeShowProjectsCard] ?? 'true') == 'true';

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final todayTasks = tasks.where((task) => task.date == today && task.status != 'canceled' && task.parentTaskId == null).toList();
    final pendingTasks = tasks.where((task) => task.status == 'pendente' && task.parentTaskId == null).length;
    final overdueTasks = tasks.where((task) => task.status == 'atrasada' && task.parentTaskId == null).length;

    DateTime? expectedDate(transaction) => DateTime.tryParse(transaction.dueDate ?? transaction.transactionDate);
    DateTime? paidDate(transaction) => transaction.paidDate == null ? null : DateTime.tryParse(transaction.paidDate!);
    bool sameMonth(DateTime? date) => date != null && date.year == now.year && date.month == now.month;

    double receitasPrevistas = 0;
    double despesasPrevistas = 0;
    double receitasPagas = 0;
    double despesasPagas = 0;
    int overdueDebtInstallments = 0;

    final todayOnly = DateTime(now.year, now.month, now.day);
    for (final transaction in transactions.where((t) => t.status != 'canceled')) {
      final expected = expectedDate(transaction);
      final paid = paidDate(transaction);
      final expectedInMonth = sameMonth(expected);
      final paidInMonth = transaction.status == 'paid' && (sameMonth(paid) || (paid == null && expectedInMonth));

      if (expectedInMonth) {
        if (transaction.type == 'income') {
          receitasPrevistas += transaction.amount;
        } else if (transaction.type == 'expense') {
          despesasPrevistas += transaction.amount;
          final due = expected == null ? null : DateTime(expected.year, expected.month, expected.day);
          if (transaction.debtId != null && transaction.status == 'overdue') overdueDebtInstallments++;
          if (transaction.debtId != null && transaction.status == 'pending' && due != null && due.isBefore(todayOnly)) overdueDebtInstallments++;
        }
      }

      if (paidInMonth) {
        if (transaction.type == 'income') {
          receitasPagas += transaction.amount;
        } else if (transaction.type == 'expense') {
          despesasPagas += transaction.amount;
        }
      }
    }

    final resultadoRealizadoMes = receitasPagas - despesasPagas;
    final saldoPrevisto = receitasPrevistas - despesasPrevistas;

    final activeDebts = debts.where((debt) => debt.status != 'paid' && debt.status != 'canceled').toList();
    final openDebts = activeDebts.length;
    double remainingDebts = 0;
    for (final debt in debts.where((debt) => debt.status != 'canceled')) {
      final abatido = transactions.where((t) => t.debtId == debt.id && t.status == 'paid').fold<double>(0, (sum, t) => sum + t.amount + (t.discountAmount ?? 0));
      remainingDebts += (debt.totalAmount - abatido).clamp(0, double.infinity).toDouble();
    }

    final validProjects = projects.where((project) => project.status != 'canceled').toList();
    final activeProjects = validProjects.where((project) => project.status == 'active').length;
    final overdueProjects = validProjects.where((project) {
      if (project.endDate == null || project.status == 'completed') return false;
      final end = DateTime.tryParse(project.endDate!);
      return end != null && end.isBefore(now);
    }).length;

    String money(num value) {
      if (hideValues) return currency == 'USD' ? '\$ ******' : 'R\$ ******';
      final prefix = currency == 'USD' ? '\$' : 'R\$';
      return '$prefix ${value.toDouble().toStringAsFixed(2)}';
    }

    return FutureBuilder<double>(
      future: _loadRealAccountBalance(),
      builder: (context, accountSnapshot) {
        final realAccountBalance = accountSnapshot.data ?? 0;
        final cards = <Widget>[
          _DashboardSummaryCard(title: 'Financeiro', icon: Icons.account_balance_wallet, color: Colors.blue, lines: ['Saldo real: ${money(realAccountBalance)}', 'Resultado mês: ${money(resultadoRealizadoMes)}', 'Previsto mês: ${money(saldoPrevisto)}'], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen()))),
          _DashboardSummaryCard(title: 'Tarefas', icon: Icons.checklist, color: Colors.green, lines: ['Hoje: ${todayTasks.length}', 'Pendentes: $pendingTasks', 'Atrasadas: $overdueTasks'], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskListScreen()))),
          _DashboardSummaryCard(title: 'Dívidas', icon: Icons.money_off, color: Colors.deepOrange, lines: ['Em aberto: $openDebts', 'Restante: ${money(remainingDebts)}', 'Parcelas atraso: $overdueDebtInstallments'], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen()))),
          if (showProjectsCard) _DashboardSummaryCard(title: 'Projetos', icon: Icons.rocket_launch, color: Colors.purple, lines: ['Ativos: $activeProjects', 'Atrasados: $overdueProjects', 'Total: ${validProjects.length}'], onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen()))),
        ];

        return Scaffold(
          appBar: AppBar(
            title: const Text('DiasOrganize', style: TextStyle(fontWeight: FontWeight.bold)),
            actions: [
              if (canTemporarilyRevealValues)
                IconButton(tooltip: _valuesRevealed ? 'Ocultar valores' : 'Revelar valores', icon: Icon(_valuesRevealed ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _valuesRevealed = !_valuesRevealed)),
            ],
          ),
          drawer: const AppDrawer(),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.15, children: cards),
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Tarefas de hoje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text('${todayTasks.length}')]),
              const SizedBox(height: 8),
              if (todayTasks.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('Nenhuma tarefa para hoje! 🎉')))
              else
                ...todayTasks.map((task) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(task.title, style: TextStyle(decoration: task.status == 'concluida' ? TextDecoration.lineThrough : null)),
                        subtitle: Text('${task.priority.toUpperCase()} - ${task.status}'),
                        trailing: Icon(task.status == 'concluida' ? Icons.check_circle : Icons.circle_outlined, color: task.status == 'concluida' ? Colors.green : Colors.grey),
                        onTap: () {
                          final updated = task.copyWith(status: task.status == 'concluida' ? _statusWhenReopened(task) : 'concluida', updatedAt: DateTime.now().toIso8601String());
                          ref.read(tasksProvider.notifier).updateTask(updated);
                        },
                      ),
                    )),
            ],
          ),
        );
      },
    );
  }
}

class _DashboardSummaryCard extends StatelessWidget {
  final String title;
  final List<String> lines;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardSummaryCard({required this.title, required this.lines, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 6), Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis))]),
              const SizedBox(height: 6),
              ...lines.map((line) => Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)))),
            ],
          ),
        ),
      ),
    );
  }
}
