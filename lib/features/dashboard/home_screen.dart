import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money_formatter.dart';
import '../../data/database/finance_planning_store.dart';
import '../../data/models/financial_goal_model.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/providers.dart';
import '../calendar/calendar_screen.dart';
import '../categories/categories_screen.dart';
import '../debts/create_debt_screen.dart';
import '../finance/create_transaction_screen.dart';
import '../finance/finance_entry_screen.dart';
import '../finance/financial_goals_screen.dart';
import '../finance/widgets/quick_transaction_bottom_sheet.dart';
import '../projects/projects_screen.dart';
import '../settings/settings_screen.dart';
import '../statistics/stats_screen.dart';
import '../tasks/quick_add_task_sheet.dart';
import '../tasks/task_smart_rules.dart';
import '../tasks/tasks_entry_screen.dart';
import 'app_drawer.dart';

final _homeExtraDataProvider = FutureProvider<_HomeExtraData>((ref) async {
  final db = await ref.watch(dbProvider).database;
  final balance = await FinancePlanningStore.getActiveAccountsBalance(db);
  final goals = await FinancePlanningStore.getGoals(db);
  return _HomeExtraData(realBalance: balance, goals: goals);
});

class _HomeExtraData {
  final double realBalance;
  final List<FinancialGoal> goals;

  const _HomeExtraData({required this.realBalance, required this.goals});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  late final List<Widget> _pages = const [
    TaskDashboard(),
    TasksEntryScreen(),
    FinanceEntryScreen(),
    ProjectsScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      body: IndexedStack(index: _currentIndex, children: _pages),
      floatingActionButton: const UniversalQuickActionButton(),
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

class UniversalQuickActionButton extends StatelessWidget {
  const UniversalQuickActionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      tooltip: 'Capturar rapidamente',
      onPressed: () => QuickAddTaskSheet.show(context),
      onLongPress: () => _showUniversalActions(context),
      child: const Icon(Icons.add),
    );
  }

  void _showUniversalActions(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('Ação rápida universal', style: TextStyle(fontWeight: FontWeight.w900))),
            ListTile(
              leading: const Icon(Icons.add_task),
              title: const Text('Nova tarefa'),
              subtitle: const Text('Captura inteligente'),
              onTap: () {
                Navigator.pop(ctx);
                QuickAddTaskSheet.show(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_downward),
              title: const Text('Nova despesa'),
              subtitle: const Text('Lançamento financeiro rápido'),
              onTap: () {
                Navigator.pop(ctx);
                showQuickTransactionBottomSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.arrow_upward),
              title: const Text('Nova receita'),
              subtitle: const Text('Abra o lançamento rápido e selecione Receita'),
              onTap: () {
                Navigator.pop(ctx);
                showQuickTransactionBottomSheet(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.rocket_launch),
              title: const Text('Novo projeto'),
              subtitle: const Text('Abrir módulo de projetos'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.payments_outlined),
              title: const Text('Nova dívida'),
              subtitle: const Text('Cadastrar dívida'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateDebtScreen()));
              },
            ),
          ],
        ),
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
  final Widget page;

  const _MoreTile({required this.icon, required this.title, required this.page});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
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

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final transactions = ref.watch(transactionsProvider);
    final projects = ref.watch(projectsProvider);
    final appSettings = ref.watch(appSettingsProvider);
    final extraDataAsync = ref.watch(_homeExtraDataProvider);

    final hideValues = _shouldHideValues(appSettings);
    final realBalance = extraDataAsync.valueOrNull?.realBalance ?? 0;
    final goals = extraDataAsync.valueOrNull?.goals ?? const <FinancialGoal>[];
    final result = _monthResult(transactions);
    final timelineItems = _buildTimeline(tasks, transactions);
    final activeProjects = projects.where((p) => p.status == 'active').toList()..sort((a, b) => b.progress.compareTo(a.progress));
    final activeGoals = goals.where((g) => g.status == 'active' && !g.isArchived).toList()..sort((a, b) => _goalRatio(b).compareTo(_goalRatio(a)));

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 268,
          title: const Text('Início'),
          actions: [
            IconButton(
              tooltip: hideValues ? 'Revelar valores' : 'Ocultar valores',
              icon: Icon(hideValues ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _valuesRevealed = !_valuesRevealed),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _HomeFinanceHeader(
              balance: realBalance,
              monthResult: result,
              hideValues: hideValues,
              loading: extraDataAsync.isLoading,
              onOpenFinance: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceEntryScreen())),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _TimelineSection(
              items: timelineItems,
              hideValues: hideValues,
              onOpenTask: (task) => Navigator.push(context, MaterialPageRoute(builder: (_) => TasksEntryScreen(key: ValueKey(task.id)))),
              onOpenTransaction: (transaction) => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTransactionScreen(transaction: transaction))),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
            child: _ContextCarousel(
              projects: activeProjects,
              goals: activeGoals,
              hideValues: hideValues,
              onOpenProjects: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen())),
              onOpenGoals: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialGoalsScreen())),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 110),
            child: _HomeShortcutGrid(
              onTasks: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksEntryScreen())),
              onFinance: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceEntryScreen())),
              onCalendar: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
              onTransaction: () => showQuickTransactionBottomSheet(context),
            ),
          ),
        ),
      ],
    );
  }

  bool _shouldHideValues(Map<String, String> appSettings) {
    final homeShowsValues = (appSettings[AppSettingKeys.homeShowFinancialValues] ?? 'true') == 'true';
    final visualLockEnabled = (appSettings[AppSettingKeys.financeVisualLock] ?? 'false') == 'true';
    final privacyHideHomeValues = (appSettings[AppSettingKeys.privacyHideHomeValues] ?? 'false') == 'true';
    final financeDiscreteMode = (appSettings[AppSettingKeys.financeDiscreteMode] ?? 'false') == 'true';
    return privacyHideHomeValues || financeDiscreteMode || !homeShowsValues || (visualLockEnabled && !_valuesRevealed);
  }
}

class _HomeFinanceHeader extends StatelessWidget {
  final double balance;
  final double monthResult;
  final bool hideValues;
  final bool loading;
  final VoidCallback onOpenFinance;

  const _HomeFinanceHeader({required this.balance, required this.monthResult, required this.hideValues, required this.loading, required this.onOpenFinance});

  @override
  Widget build(BuildContext context) {
    final resultColor = monthResult >= 0 ? Colors.green : Colors.red;
    final balanceColor = balance >= 0 ? Colors.green : Colors.red;
    return InkWell(
      onTap: onOpenFinance,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 86, 20, 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.90), Theme.of(context).colorScheme.surface],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Saldo real consolidado', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(loading ? 'Carregando...' : _money(balance, hideValues), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: hideValues ? Colors.grey.shade800 : balanceColor, fontSize: 35, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(color: resultColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(16), border: Border.all(color: resultColor.withValues(alpha: 0.16))),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(monthResult >= 0 ? Icons.trending_up : Icons.trending_down, color: resultColor, size: 18),
                  const SizedBox(width: 8),
                  Text('Resultado do mês: ${_money(monthResult, hideValues)}', style: TextStyle(color: hideValues ? Colors.grey.shade800 : resultColor, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const Spacer(),
            Text('Toque para abrir o dashboard financeiro', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _TimelineSection extends StatelessWidget {
  final List<_HomeTimelineItem> items;
  final bool hideValues;
  final ValueChanged<Task> onOpenTask;
  final ValueChanged<FinancialTransaction> onOpenTransaction;

  const _TimelineSection({required this.items, required this.hideValues, required this.onOpenTask, required this.onOpenTransaction});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(child: Text('O que eu preciso saber agora?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
              Text('${items.length}', style: TextStyle(color: Colors.grey.shade700)),
            ]),
            const SizedBox(height: 6),
            Text('Tarefas e contas do dia em uma linha do tempo.', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const _EmptyHomeState(icon: Icons.celebration_outlined, title: 'Nada crítico agora', subtitle: 'Sem tarefas ou contas pendentes para hoje.')
            else
              ...items.take(8).map((item) => _TimelineTile(item: item, hideValues: hideValues, onOpenTask: onOpenTask, onOpenTransaction: onOpenTransaction)),
          ],
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final _HomeTimelineItem item;
  final bool hideValues;
  final ValueChanged<Task> onOpenTask;
  final ValueChanged<FinancialTransaction> onOpenTransaction;

  const _TimelineTile({required this.item, required this.hideValues, required this.onOpenTask, required this.onOpenTransaction});

  @override
  Widget build(BuildContext context) {
    final color = item.isTask ? Colors.blue : (item.transaction?.type == 'income' ? Colors.green : Colors.red);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(item.isTask ? Icons.checklist : Icons.payments_outlined, color: color)),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(item.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: item.transaction == null ? Text(item.timeLabel, style: const TextStyle(fontWeight: FontWeight.w800)) : Text(_money(item.transaction!.amount, hideValues), style: TextStyle(color: color, fontWeight: FontWeight.w900)),
      onTap: () {
        if (item.task != null) onOpenTask(item.task!);
        if (item.transaction != null) onOpenTransaction(item.transaction!);
      },
    );
  }
}

class _ContextCarousel extends StatelessWidget {
  final List<Project> projects;
  final List<FinancialGoal> goals;
  final bool hideValues;
  final VoidCallback onOpenProjects;
  final VoidCallback onOpenGoals;

  const _ContextCarousel({required this.projects, required this.goals, required this.hideValues, required this.onOpenProjects, required this.onOpenGoals});

  @override
  Widget build(BuildContext context) {
    final total = projects.take(4).length + goals.take(4).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Projetos e metas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (total == 0)
          const _EmptyHomeState(icon: Icons.flag_outlined, title: 'Sem projetos ou metas ativas', subtitle: 'Projetos e metas financeiras aparecem aqui.')
        else
          SizedBox(
            height: 138,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...projects.take(4).map((project) => _ContextCard(title: project.name, subtitle: 'Projeto ativo', progress: (project.progress / 100).clamp(0, 1).toDouble(), color: Colors.deepPurple, icon: Icons.rocket_launch, value: '${project.progress.toStringAsFixed(0)}%', onTap: onOpenProjects)),
                ...goals.take(4).map((goal) => _ContextCard(title: goal.name, subtitle: 'Meta financeira', progress: _goalRatio(goal).clamp(0, 1).toDouble(), color: Colors.green, icon: Icons.flag, value: _money(goal.currentAmount, hideValues), onTap: onOpenGoals)),
              ],
            ),
          ),
      ],
    );
  }
}

class _ContextCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final double progress;
  final Color color;
  final IconData icon;
  final String value;
  final VoidCallback onTap;

  const _ContextCard({required this.title, required this.subtitle, required this.progress, required this.color, required this.icon, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(right: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: color.withValues(alpha: 0.18))),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)), const SizedBox(width: 10), Expanded(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w900)))]),
              const Spacer(),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900)),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              const SizedBox(height: 8),
              ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: progress, minHeight: 7, color: color, backgroundColor: color.withValues(alpha: 0.12))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _HomeShortcutGrid extends StatelessWidget {
  final VoidCallback onTasks;
  final VoidCallback onFinance;
  final VoidCallback onCalendar;
  final VoidCallback onTransaction;

  const _HomeShortcutGrid({required this.onTasks, required this.onFinance, required this.onCalendar, required this.onTransaction});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.8,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        _ShortcutTile(icon: Icons.task_alt, label: 'Tarefas', onTap: onTasks),
        _ShortcutTile(icon: Icons.account_balance_wallet, label: 'Finanças', onTap: onFinance),
        _ShortcutTile(icon: Icons.calendar_month, label: 'Calendário', onTap: onCalendar),
        _ShortcutTile(icon: Icons.bolt, label: 'Lançar valor', onTap: onTransaction),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShortcutTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.shade300)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon), const SizedBox(width: 8), Text(label, style: const TextStyle(fontWeight: FontWeight.w800))]),
      ),
    );
  }
}

class _EmptyHomeState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyHomeState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(18)),
      child: Column(children: [Icon(icon, size: 38, color: Colors.grey.shade600), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700))]),
    );
  }
}

class _HomeTimelineItem {
  final DateTime sortDate;
  final String timeLabel;
  final String title;
  final String subtitle;
  final Task? task;
  final FinancialTransaction? transaction;

  const _HomeTimelineItem({required this.sortDate, required this.timeLabel, required this.title, required this.subtitle, this.task, this.transaction});

  bool get isTask => task != null;
}

List<_HomeTimelineItem> _buildTimeline(List<Task> tasks, List<FinancialTransaction> transactions) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final items = <_HomeTimelineItem>[];

  for (final task in tasks.where((t) => t.parentTaskId == null && t.status != 'concluida' && t.status != 'canceled')) {
    final date = DateTime.tryParse(task.date ?? '');
    final isToday = date != null && date.year == today.year && date.month == today.month && date.day == today.day;
    final isOverdue = TaskSmartRules.isOverdue(task);
    if (!isToday && !isOverdue) continue;
    final sortDate = _dateWithTime(date ?? today, task.time, isOverdue ? '00:01' : '23:59');
    items.add(_HomeTimelineItem(sortDate: sortDate, timeLabel: task.time ?? (isOverdue ? 'Atrasada' : 'Hoje'), title: task.title, subtitle: isOverdue ? 'Tarefa atrasada' : 'Tarefa de hoje', task: task));
  }

  for (final transaction in transactions.where((t) => t.status == 'pending' || t.status == 'overdue')) {
    final rawDate = DateTime.tryParse(transaction.dueDate ?? transaction.transactionDate);
    if (rawDate == null) continue;
    final dueDate = DateTime(rawDate.year, rawDate.month, rawDate.day);
    final isToday = dueDate == today;
    final isOverdue = dueDate.isBefore(today) || transaction.status == 'overdue';
    if (!isToday && !isOverdue) continue;
    final label = transaction.type == 'income' ? 'Receita ${isOverdue ? 'atrasada' : 'prevista'}' : 'Conta ${isOverdue ? 'atrasada' : 'a pagar'}';
    items.add(_HomeTimelineItem(sortDate: _dateWithTime(dueDate, null, isOverdue ? '00:02' : '23:59'), timeLabel: isOverdue ? 'Atrasada' : 'Hoje', title: transaction.title, subtitle: label, transaction: transaction));
  }

  items.sort((a, b) => a.sortDate.compareTo(b.sortDate));
  return items;
}

DateTime _dateWithTime(DateTime date, String? time, String fallback) {
  final value = time ?? fallback;
  final parts = value.split(':');
  final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 23 : 23;
  final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 59 : 59;
  return DateTime(date.year, date.month, date.day, hour, minute);
}

double _monthResult(List<FinancialTransaction> transactions) {
  final now = DateTime.now();
  double income = 0;
  double expense = 0;
  for (final transaction in transactions.where((t) => t.status == 'paid' && t.status != 'canceled')) {
    final date = DateTime.tryParse(transaction.paidDate ?? transaction.dueDate ?? transaction.transactionDate);
    if (date == null || date.year != now.year || date.month != now.month) continue;
    if (transaction.type == 'income') income += transaction.amount;
    if (transaction.type == 'expense') expense += transaction.amount;
  }
  return income - expense;
}

String _money(num value, bool hidden) => hidden ? 'R\$ ******' : MoneyFormatter.format(value);

double _goalRatio(FinancialGoal goal) => goal.targetAmount <= 0 ? 0 : goal.currentAmount / goal.targetAmount;
