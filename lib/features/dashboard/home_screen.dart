import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../tasks/create_task_screen.dart';
import '../tasks/task_list_screen.dart';
import '../calendar/calendar_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/categories_screen.dart';
import '../finance/finance_screen.dart';
import '../debts/debts_screen.dart';
import '../projects/projects_screen.dart';

  late final List<Widget> _pages = [
    const FinanceScreen(),
    const ProjectsScreen(),
    const MoreScreen(),
    final showFab = _currentIndex == 0 || _currentIndex == 1;
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
          ListTile(
            leading: const Icon(Icons.money_off),
            title: const Text('Dívidas'),
            subtitle: const Text('Acesse rapidamente suas dívidas e parcelas'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtsScreen())),
          ),
          const Divider(),
          const ListTile(
            title: Text('Outros recursos', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Calendário'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Categorias'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.pie_chart),
            title: const Text('Estatísticas'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configurações'),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),

class TaskDashboard extends ConsumerStatefulWidget {
  ConsumerState<TaskDashboard> createState() => _TaskDashboardState();
}

class _TaskDashboardState extends ConsumerState<TaskDashboard> {
  bool _temporaryUnlock = false;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final projects = ref.watch(projectsProvider);
    final debts = ref.watch(debtsProvider);
    final appSettings = ref.watch(appSettingsProvider);

    final currency = appSettings[AppSettingKeys.defaultCurrency] ?? 'BRL';
    final showFinancial = (appSettings[AppSettingKeys.homeShowFinancialValues] ?? 'true') == 'true';
    final privacyHide = (appSettings[AppSettingKeys.privacyHideHomeValues] ?? 'false') == 'true';
    final discreteMode = (appSettings[AppSettingKeys.financeDiscreteMode] ?? 'false') == 'true';
    final visualLock = (appSettings[AppSettingKeys.financeVisualLock] ?? 'false') == 'true';
    final showProjectsCard = (appSettings[AppSettingKeys.homeShowProjectsCard] ?? 'true') == 'true';
    final shouldMask = !showFinancial || privacyHide || discreteMode || (visualLock && !_temporaryUnlock);

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);


    final monthTransactions = transactions.where((t) {
      final dt = DateTime.tryParse(t.transactionDate);
      return dt != null && dt.year == now.year && dt.month == now.month && t.status != 'canceled';
    }).toList();

    final receitasMes = monthTransactions.where((t) => t.type == 'income').fold<double>(0, (sum, t) => sum + t.amount);
    final despesasMes = monthTransactions.where((t) => t.type == 'expense').fold<double>(0, (sum, t) => sum + t.amount);
    final saldoPrevisto = receitasMes - despesasMes;

    final receitasRealizadas = monthTransactions.where((t) => t.type == 'income' && t.status == 'paid').fold<double>(0, (sum, t) => sum + t.amount);
    final despesasRealizadas = monthTransactions.where((t) => t.type == 'expense' && t.status == 'paid').fold<double>(0, (sum, t) => sum + t.amount);
    final saldoRealizado = receitasRealizadas - despesasRealizadas;

    final debtTransactions = transactions.where((t) => t.debtId != null && t.status != 'canceled').toList();
    final totalDividas = debts.where((d) => d.status != 'paid' && d.status != 'canceled').fold<double>(0, (sum, d) => sum + d.totalAmount);
    final pagoDividas = debtTransactions.where((t) => t.status == 'paid' && t.type == 'expense').fold<double>(0, (sum, t) => sum + t.amount);
    final valorRestante = (totalDividas - pagoDividas).clamp(0, double.infinity);

    final proximasParcelas = debtTransactions.where((t) {
      final due = t.dueDate == null ? null : DateTime.tryParse(t.dueDate!);
      return due != null && due.isAfter(now) && t.status != 'paid';
    }).toList()
      ..sort((a, b) => DateTime.parse(a.dueDate!).compareTo(DateTime.parse(b.dueDate!)));

    final proximaParcela = proximasParcelas.isEmpty ? null : proximasParcelas.first;
    final parcelasAtrasadas = debtTransactions.where((t) => t.status == 'overdue').length;

    final projetosEmAndamento = projects.where((p) => p.status == 'active').length;
    final projetosAtrasados = projects.where((p) {
      if (p.status == 'completed' || p.status == 'canceled' || p.endDate == null) return false;
      final end = DateTime.tryParse(p.endDate!);
      return end != null && end.isBefore(now);
    }).toList();

    final projetosComPrazo = projects.where((p) {
      if (p.status == 'completed' || p.status == 'canceled' || p.endDate == null) return false;
      final end = DateTime.tryParse(p.endDate!);
      return end != null && end.isAfter(now);
    }).toList()
      ..sort((a, b) => DateTime.parse(a.endDate!).compareTo(DateTime.parse(b.endDate!)));

    final projetoMaisProximo = projetosComPrazo.isEmpty ? null : projetosComPrazo.first;
    final mediaProgresso = projects.isEmpty ? 0.0 : projects.fold<double>(0, (sum, p) => sum + p.progress) / projects.length;

    final tarefasAtrasadas = tasks.where((t) => t.status == 'atrasada').length;
    final despesasVencidas = transactions.where((t) => t.type == 'expense' && t.status == 'overdue').length;
    final parcelasVencidas = debtTransactions.where((t) => t.status == 'overdue').length;
    final projetosPrazoVencido = projetosAtrasados.length;

    String money(double value) {
      if (shouldMask) return currency == 'USD' ? '\$ ******' : 'R\$ ******';
      final prefix = currency == 'USD' ? '\$' : 'R\$';
      return '$prefix ${value.toStringAsFixed(2)}';
        actions: [
          if (visualLock)
            IconButton(
              icon: Icon(_temporaryUnlock ? Icons.lock_open : Icons.lock),
              tooltip: _temporaryUnlock ? 'Ocultar valores' : 'Revelar valores',
              onPressed: () => setState(() => _temporaryUnlock = !_temporaryUnlock),
            ),
        ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.1,
            children: [
              _DashboardSummaryCard(
                title: 'Financeiro do mês',
                icon: Icons.account_balance_wallet,
                color: Colors.blue,
                lines: [
                  'Receitas: ${money(receitasMes)}',
                  'Despesas: ${money(despesasMes)}',
                  'Previsto: ${money(saldoPrevisto)}',
                  'Realizado: ${money(saldoRealizado)}',
                ],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen())),
              _DashboardSummaryCard(
                title: 'Dívidas',
                icon: Icons.money_off,
                color: Colors.deepOrange,
                lines: [
                  'Total: ${money(totalDividas)}',
                  'Restante: ${money(valorRestante)}',
                  'Próxima: ${proximaParcela?.dueDate != null ? DateFormat('dd/MM').format(DateTime.parse(proximaParcela!.dueDate!)) : '-'}',
                  'Atrasadas: $parcelasAtrasadas',
                ],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtsScreen())),
              ),
              if (showProjectsCard)
                _DashboardSummaryCard(
                  title: 'Projetos',
                  icon: Icons.rocket_launch,
                  color: Colors.purple,
                  lines: [
                    'Em andamento: $projetosEmAndamento',
                    'Atrasados: ${projetosAtrasados.length}',
                    'Prazo mais próximo: ${projetoMaisProximo?.name ?? '-'}',
                    'Média progresso: ${mediaProgresso.toStringAsFixed(0)}%',
                  ],
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen())),
                ),
              _DashboardSummaryCard(
                title: 'Alertas',
                icon: Icons.warning_amber,
                color: Colors.red,
                lines: [
                  'Tarefas atrasadas: $tarefasAtrasadas',
                  'Despesas vencidas: $despesasVencidas',
                  'Parcelas vencidas: $parcelasVencidas',
                  'Projetos vencidos: $projetosPrazoVencido',
                ],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskListScreen())),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tarefas de hoje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (todayTasks.isNotEmpty) Text('${todayTasks.length} tarefa(s)'),
            ],
          ),
          const SizedBox(height: 8),
          if (todayTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Nenhuma tarefa para hoje! 🎉')),
            )
          else
            ...todayTasks.map((t) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(t.title, style: TextStyle(decoration: t.status == 'concluida' ? TextDecoration.lineThrough : null)),
                    subtitle: Text('${t.priority.toUpperCase()} - ${t.status}'),
                    trailing: Icon(
                      t.status == 'concluida' ? Icons.check_circle : Icons.circle_outlined,
                      color: t.status == 'concluida' ? Colors.green : Colors.grey,
                    onTap: () {
                      ref.read(tasksProvider.notifier).updateTask(
                            t.copyWith(
                              status: t.status == 'concluida' ? 'pendente' : 'concluida',
                              updatedAt: DateTime.now().toIso8601String(),
                            ),
                          );
                    },
                  ),
                )),
        ],
}

class _DashboardSummaryCard extends StatelessWidget {
  final List<String> lines;
  final IconData icon;
  final VoidCallback onTap;

  const _DashboardSummaryCard({
    required this.title,
    required this.lines,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  @override
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
              ...lines.map((line) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                  )),
            ],
          ),

    final currency = appSettings[AppSettingKeys.defaultCurrency] ?? 'BRL';
    final showFinancial = (appSettings[AppSettingKeys.homeShowFinancialValues] ?? 'true') == 'true';
    final privacyHide = (appSettings[AppSettingKeys.privacyHideHomeValues] ?? 'false') == 'true';
    final discreteMode = (appSettings[AppSettingKeys.financeDiscreteMode] ?? 'false') == 'true';
    final visualLock = (appSettings[AppSettingKeys.financeVisualLock] ?? 'false') == 'true';
    final showProjectsCard = (appSettings[AppSettingKeys.homeShowProjectsCard] ?? 'true') == 'true';
    final shouldMask = !showFinancial || privacyHide || discreteMode || (visualLock && !_temporaryUnlock);

    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    final todayTasks = tasks.where((t) => t.date == todayStr).toList();

    final monthTransactions = transactions.where((t) {
      final dt = DateTime.tryParse(t.transactionDate);
      return dt != null && dt.year == now.year && dt.month == now.month && t.status != 'canceled';
    }).toList();

    final receitasMes = monthTransactions.where((t) => t.type == 'income').fold<double>(0, (sum, t) => sum + t.amount);
    final despesasMes = monthTransactions.where((t) => t.type == 'expense').fold<double>(0, (sum, t) => sum + t.amount);
    final saldoPrevisto = receitasMes - despesasMes;

    final receitasRealizadas = monthTransactions.where((t) => t.type == 'income' && t.status == 'paid').fold<double>(0, (sum, t) => sum + t.amount);
    final despesasRealizadas = monthTransactions.where((t) => t.type == 'expense' && t.status == 'paid').fold<double>(0, (sum, t) => sum + t.amount);
    final saldoRealizado = receitasRealizadas - despesasRealizadas;

    final debtTransactions = transactions.where((t) => t.debtId != null && t.status != 'canceled').toList();
    final totalDividas = debts.where((d) => d.status != 'paid' && d.status != 'canceled').fold<double>(0, (sum, d) => sum + d.totalAmount);
    final pagoDividas = debtTransactions.where((t) => t.status == 'paid' && t.type == 'expense').fold<double>(0, (sum, t) => sum + t.amount);
    final valorRestante = (totalDividas - pagoDividas).clamp(0, double.infinity);

    final proximasParcelas = debtTransactions.where((t) {
      final due = t.dueDate == null ? null : DateTime.tryParse(t.dueDate!);
      return due != null && due.isAfter(now) && t.status != 'paid';
    }).toList()
      ..sort((a, b) => DateTime.parse(a.dueDate!).compareTo(DateTime.parse(b.dueDate!)));

    final proximaParcela = proximasParcelas.isEmpty ? null : proximasParcelas.first;
    final parcelasAtrasadas = debtTransactions.where((t) => t.status == 'overdue').length;

    final projetosEmAndamento = projects.where((p) => p.status == 'active').length;
    final projetosAtrasados = projects.where((p) {
      if (p.status == 'completed' || p.status == 'canceled' || p.endDate == null) return false;
      final end = DateTime.tryParse(p.endDate!);
      return end != null && end.isBefore(now);
    }).toList();

    final projetosComPrazo = projects.where((p) {
      if (p.status == 'completed' || p.status == 'canceled' || p.endDate == null) return false;
      final end = DateTime.tryParse(p.endDate!);
      return end != null && end.isAfter(now);
    }).toList()
      ..sort((a, b) => DateTime.parse(a.endDate!).compareTo(DateTime.parse(b.endDate!)));

    final projetoMaisProximo = projetosComPrazo.isEmpty ? null : projetosComPrazo.first;
    final mediaProgresso = projects.isEmpty ? 0.0 : projects.fold<double>(0, (sum, p) => sum + p.progress) / projects.length;

    final tarefasAtrasadas = tasks.where((t) => t.status == 'atrasada').length;
    final despesasVencidas = transactions.where((t) => t.type == 'expense' && t.status == 'overdue').length;
    final parcelasVencidas = debtTransactions.where((t) => t.status == 'overdue').length;
    final projetosPrazoVencido = projetosAtrasados.length;

    String money(double value) {
      if (shouldMask) return currency == 'USD' ? '\$ ******' : 'R\$ ******';
      final prefix = currency == 'USD' ? '\$' : 'R\$';
      return '$prefix ${value.toStringAsFixed(2)}';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('DiasOrganize', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (visualLock)
            IconButton(
              icon: Icon(_temporaryUnlock ? Icons.lock_open : Icons.lock),
              tooltip: _temporaryUnlock ? 'Ocultar valores' : 'Revelar valores',
              onPressed: () => setState(() => _temporaryUnlock = !_temporaryUnlock),
            ),
        ],
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
            childAspectRatio: 1.1,
            children: [
              _DashboardSummaryCard(
                title: 'Financeiro do mês',
                icon: Icons.account_balance_wallet,
                color: Colors.blue,
                lines: [
                  'Receitas: ${money(receitasMes)}',
                  'Despesas: ${money(despesasMes)}',
                  'Previsto: ${money(saldoPrevisto)}',
                  'Realizado: ${money(saldoRealizado)}',
                ],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen())),
              ),
              _DashboardSummaryCard(
                title: 'Dívidas',
                icon: Icons.money_off,
                color: Colors.deepOrange,
                lines: [
                  'Total: ${money(totalDividas)}',
                  'Restante: ${money(valorRestante)}',
                  'Próxima: ${proximaParcela?.dueDate != null ? DateFormat('dd/MM').format(DateTime.parse(proximaParcela!.dueDate!)) : '-'}',
                  'Atrasadas: $parcelasAtrasadas',
                ],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtsScreen())),
              ),
              if (showProjectsCard)
                _DashboardSummaryCard(
                  title: 'Projetos',
                  icon: Icons.rocket_launch,
                  color: Colors.purple,
                  lines: [
                    'Em andamento: $projetosEmAndamento',
                    'Atrasados: ${projetosAtrasados.length}',
                    'Prazo mais próximo: ${projetoMaisProximo?.name ?? '-'}',
                    'Média progresso: ${mediaProgresso.toStringAsFixed(0)}%',
                  ],
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen())),
                ),
              _DashboardSummaryCard(
                title: 'Alertas',
                icon: Icons.warning_amber,
                color: Colors.red,
                lines: [
                  'Tarefas atrasadas: $tarefasAtrasadas',
                  'Despesas vencidas: $despesasVencidas',
                  'Parcelas vencidas: $parcelasVencidas',
                  'Projetos vencidos: $projetosPrazoVencido',
                ],
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TaskListScreen())),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Tarefas de hoje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              if (todayTasks.isNotEmpty) Text('${todayTasks.length} tarefa(s)'),
            ],
          ),
          const SizedBox(height: 8),
          if (todayTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Nenhuma tarefa para hoje! 🎉')),
            )
          else
            ...todayTasks.map((t) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(t.title, style: TextStyle(decoration: t.status == 'concluida' ? TextDecoration.lineThrough : null)),
                    subtitle: Text('${t.priority.toUpperCase()} - ${t.status}'),
                    trailing: Icon(
                      t.status == 'concluida' ? Icons.check_circle : Icons.circle_outlined,
                      color: t.status == 'concluida' ? Colors.green : Colors.grey,
                    ),
                    onTap: () {
                      ref.read(tasksProvider.notifier).updateTask(
                            t.copyWith(
                              status: t.status == 'concluida' ? 'pendente' : 'concluida',
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
              ...lines.map((line) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(line, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
