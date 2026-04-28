import 'package:flutter/material.dart';

import 'finance_budgets_screen.dart';

class FinanceBudgetsShortcut extends StatelessWidget {
  final String title;
  final String subtitle;

  const FinanceBudgetsShortcut({
    super.key,
    this.title = 'Orçamentos avançados',
    this.subtitle = 'Controle limites gerais, por categoria e por subcategoria.',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.tune)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceBudgetsScreen()));
        },
      ),
    );
  }
}
