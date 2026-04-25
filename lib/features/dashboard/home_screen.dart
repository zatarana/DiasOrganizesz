import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../tasks/create_task_screen.dart';
import '../tasks/task_list_screen.dart';
import '../calendar/calendar_screen.dart';
import '../settings/settings_screen.dart';
import '../statistics/stats_screen.dart';
import 'app_drawer.dart';
import 'package:intl/intl.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = [
    const TaskDashboard(),
    const TaskListScreen(),
    const CalendarScreen(),
    const StatsScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateTaskScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (idx) => setState(() => _currentIndex = idx),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Início'),
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Tarefas'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Calendário'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: 'Estatísticas'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}

class TaskDashboard extends ConsumerWidget {
  const TaskDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final transactions = ref.watch(transactionsProvider);
    
    final pd = tasks.where((t) => t.status == 'pendente').length;
    final cd = tasks.where((t) => t.status == 'concluida').length;
    final ad = tasks.where((t) => t.status == 'atrasada').length;
    
    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final todayTasks = tasks.where((t) => t.date == todayStr).toList();
    
    double saldo = 0;
    for (var t in transactions) {
      if (t.type == 'receita') saldo += t.amount;
      else if (t.type == 'despesa') saldo -= t.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('DiasOrganize', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
      ),
      drawer: const AppDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Resumo Financeiro
            Card(
              color: Colors.blue.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.blue.shade200)),
              child: ListTile(
                leading: const Icon(Icons.account_balance_wallet, color: Colors.blue, size: 36),
                title: const Text('Saldo Atual', style: TextStyle(fontSize: 14)),
                subtitle: Text('\$${saldo.toStringAsFixed(2)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: saldo >= 0 ? Colors.green.shade700 : Colors.red.shade700)),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Resumo do dia',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatCard(title: 'Pendentes', count: pd, color: Colors.blue),
                _StatCard(title: 'Concluídas', count: cd, color: Colors.green),
                _StatCard(title: 'Atrasadas', count: ad, color: Colors.red),
              ],
            ),
            const SizedBox(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Tarefas de hoje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                if (todayTasks.isNotEmpty)
                  Text('${todayTasks.length} tarefa(s)'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: todayTasks.isEmpty
                  ? const Center(child: Text('Nenhuma tarefa para hoje! 🎉'))
                  : ListView.builder(
                      itemCount: todayTasks.length,
                      itemBuilder: (ctx, i) {
                        final t = todayTasks[i];
                        return Card(
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
                                  updatedAt: DateTime.now().toIso8601String()
                                )
                              );
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  const _StatCard({required this.title, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(colors: [color.withOpacity(0.8), color]),
        ),
        child: Column(
          children: [
            Text(count.toString(), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.white), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}
