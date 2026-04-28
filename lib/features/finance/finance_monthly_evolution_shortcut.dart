import 'package:flutter/material.dart';

import 'finance_monthly_evolution_screen.dart';

class FinanceMonthlyEvolutionShortcut extends StatelessWidget {
  final String title;
  final String subtitle;

  const FinanceMonthlyEvolutionShortcut({
    super.key,
    this.title = 'Evolução mensal',
    this.subtitle = 'Compare receitas, despesas, resultado e economia mês a mês.',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.show_chart)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceMonthlyEvolutionScreen()));
        },
      ),
    );
  }
}
