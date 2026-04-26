import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/providers.dart';
import '../calendar/calendar_screen.dart';
import '../categories/categories_screen.dart';
import '../debts/debts_screen.dart';
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
      body: _pages[_currentIndex],
      floatingActionButton: showFab
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
                );
              },
              child: const Icon(Icons.add),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
        children: [
          const ListTile(
            title: Text('Acesso rápido', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          _MoreTile(
            icon: Icons.money_off,
            title: 'Dívidas',
            subtitle: 'Acesse rapidamente suas dívidas e parcelas',
            page: const DebtsScreen(),
          ),
          const Divider(),
          const ListTile(
            title: Text('Outros recursos', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          _MoreTile(icon: Icons.calendar_month, title: 'Calendário', page: const CalendarScreen()),
          _MoreTile(icon: Icons.category, title: 'Categorias', page: const CategoriesScreen()),
          _MoreTile(icon: Icons.pie_chart, title: 'Estatísticas', page: const StatsScreen()),
          _MoreTile(icon: Icons.settings, title: 'Configurações', page: const SettingsScreen()),
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

class TaskDashboard extends ConsumerWidget {
  const TaskDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final transactions = ref.watch(transactionsProvider);
    final projects = ref.watch(projectsProvider);
    final debts = ref.watch(debtsProvider);
    final appSettings = ref.watch(appSettingsProvider);

    final currency = appSettings[AppSettingKeys.defaultCurrency] ?? 'BRL';
    final hideValues = (appSettings[AppSettingKeys.privacyHideHomeValues] ?? 'false') == 'true' ||
        (appSettings[AppSettingKeys.financeDiscreteMode] ?? 'false') == 'true' ||
        (appSettings[AppSettingKeys.homeShowFinancialValues] ?? 'true') != 'true';

    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final todayTasks = tasks.where((task) => task.date == today).toList();
    final pendingTasks = tasks.where((task) => task.status == 'pendente').length;
    final overdueTasks = tasks.where((task) => task.status == 'atrasada').length;

    final monthTransactions = transactions.where((transaction) {
      final date = DateTime.tryParse(transaction.transactionDate);
      return date != null && date.year == now.year && date.month == now.month && transaction.status != 'canceled';
    }).toList();

    final income = monthTransactions.where((t) => t.type == 'income').fold<double>(0, (sum, t) => sum + t.amount);
    final expenses = monthTransactions.where((t) => t.type == 'expense').fold<double>(0, (sum, t) => sum + t.amount);
    final balance = income - expenses;
    final openDebts = debts.where((debt) => debt.status != 'paid' && debt.status != 'canceled').length;
    final activeProjects = projects.where((project) => project.status == 'active').length;

    String money(num value) {
      if (hideValues) return currency == 'USD' ? '\$ ******' : 'R\$ ******';
      final prefix = currency == 'USD' ? '\$' : 'R\$';
      return '$prefix ${value.toDouble().toStringAsFixed(2)}';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('DiasOrganize', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      drawer: const AppDrawer(),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
            children: [
              _DashboardSummaryCard(
                title: 'Financeiro do mês',
                icon: Icons.account_balance_wallet,
                color: Colors.blue,
                lines: ['Receitas: ${money(income)}', 'Despesas: ${money(expenses)}', 'Saldo: ${money(balance)}'],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen())),
              ),
              _DashboardSummaryCard(
                title: 'Tarefas',
                icon: Icons.checklist,
                color: Colors.green,
                lines: ['Hoje: ${todayTasks.length}', 'Pendentes: $pendingTasks', 'Atrasadas: $overdueTasks'],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskListScreen())),
              ),
              _DashboardSummaryCard(
                title: 'Dívidas',
                icon: Icons.money_off,
                color: Colors.deepOrange,
                lines: ['Em aberto: $openDebts', 'Parcelas: ${transactions.where((t) => t.debtId != null).length}'],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtsScreen())),
              ),
              _DashboardSummaryCard(
                title: 'Projetos',
                icon: Icons.rocket_launch,
                color: Colors.purple,
                lines: ['Ativos: $activeProjects', 'Total: ${projects.length}'],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen())),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tarefas de hoje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('${todayTasks.length}'),
            ],
          ),
          const SizedBox(height: 8),
          if (todayTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Nenhuma tarefa para hoje! 🎉')),
            )
          else
            ...todayTasks.map((task) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(
                      task.title,
                      style: TextStyle(decoration: task.status == 'concluida' ? TextDecoration.lineThrough : null),
                    ),
                    subtitle: Text('${task.priority.toUpperCase()} - ${task.status}'),
                    trailing: Icon(
                      task.status == 'concluida' ? Icons.check_circle : Icons.circle_outlined,
                      color: task.status == 'concluida' ? Colors.green : Colors.grey,
                    ),
                    onTap: () {
                      ref.read(tasksProvider.notifier).updateTask(
                            task.copyWith(
                              status: task.status == 'concluida' ? 'pendente' : 'concluida',
                              updatedAt: DateTime.now().toIso8601String(),
                            ),
                          );
                    },
                  ),
                )),
        ],
      ),
    );
  }
}

class _DashboardSummaryCard extends StatelessWidget {
  final String title;
  final List<String> lines;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _DashboardSummaryCard({
    required this.title,
    required this.lines,
    required this.icon,
    required this.color,
    required this.onTap,
  });

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
              Row(
                children: [
                  Icon(icon, color: color, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13), overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ...lines.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
