import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/riverpod_providers.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final pd = tasks.where((t) => t.status == 'pendente').length;
    final cd = tasks.where((t) => t.status == 'concluida').length;
    final ad = tasks.where((t) => t.status == 'atrasada').length;
    final total = tasks.length;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Estatísticas')),
      body: total == 0 ? const Center(child: Text('Sem tarefas para analisar.')) : Column(
        children: [
          const SizedBox(height: 50),
          SizedBox(
            height: 250,
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(
                    value: pd.toDouble(), 
                    color: Colors.blue, 
                    title: 'Pend: $pd',
                    radius: 80,
                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                  ),
                  PieChartSectionData(
                    value: cd.toDouble(), 
                    color: Colors.green, 
                    title: 'Conc: $cd',
                    radius: 80,
                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                  ),
                  PieChartSectionData(
                    value: ad.toDouble(), 
                    color: Colors.red, 
                    title: 'Atr: $ad',
                    radius: 80,
                    titleStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
                  ),
                ],
                centerSpaceRadius: 40,
                sectionsSpace: 2,
              ),
            ),
          ),
          const SizedBox(height: 40),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    const Text('Taxa de Conclusão', style: TextStyle(fontSize: 18)),
                    const SizedBox(height: 10),
                    Text(
                      '${((cd / total) * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
