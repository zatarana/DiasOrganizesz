import 'package:flutter/material.dart';

import 'finance_hub_screen.dart';

class FinanceHubShortcut extends StatelessWidget {
  final String title;
  final String subtitle;

  const FinanceHubShortcut({
    super.key,
    this.title = 'Central Financeira',
    this.subtitle = 'Acesse planejamento, dívidas, cartões, objetivos, relatórios e exportações.',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.auto_graph)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceHubScreen()));
        },
      ),
    );
  }
}
