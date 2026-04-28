import 'package:flutter/material.dart';

import 'financial_goals_screen.dart';

class FinancialGoalsShortcut extends StatelessWidget {
  final String title;
  final String subtitle;

  const FinancialGoalsShortcut({
    super.key,
    this.title = 'Objetivos financeiros',
    this.subtitle = 'Acompanhe metas, progresso e sugestão de aporte mensal.',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.flag_outlined)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialGoalsScreen()));
        },
      ),
    );
  }
}
