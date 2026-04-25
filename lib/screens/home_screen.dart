import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/riverpod_providers.dart';
import 'create_task_screen.dart';
import 'task_list_screen.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

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
    final pd = tasks.where((t) => t.status == 'pendente').length;
    final cd = tasks.where((t) => t.status == 'concluida').length;
    final ad = tasks.where((t) => t.status == 'atrasada').length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Olá! Resumo do seu dia.',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
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
                const Text('Próximas tarefas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()));
                  },
                  child: const Text('Ver Estatísticas'),
                ),
              ],
            ),
            Expanded(
              child: tasks.isEmpty
                  ? const Center(child: Text('Nenhuma tarefa pendente.'))
                  : ListView.builder(
                      itemCount: tasks.length,
                      itemBuilder: (ctx, i) {
                        final t = tasks[i];
                        return ListTile(
                          title: Text(t.title),
                          subtitle: Text(t.date),
                          trailing: Icon(
                            t.status == 'concluida' ? Icons.check_circle : Icons.circle_outlined,
                            color: t.status == 'concluida' ? Colors.green : Colors.grey,
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
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(colors: [color.withOpacity(0.7), color]),
        ),
        child: Column(
          children: [
            Text(count.toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
