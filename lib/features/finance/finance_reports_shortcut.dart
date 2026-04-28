import 'package:flutter/material.dart';

import 'finance_reports_screen.dart';

class FinanceReportsShortcut extends StatelessWidget {
  final String title;
  final String subtitle;

  const FinanceReportsShortcut({
    super.key,
    this.title = 'Relatórios financeiros',
    this.subtitle = 'Acesse rankings, orçamentos avançados e análises mensais.',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.analytics_outlined)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceReportsScreen()));
        },
      ),
    );
  }
}
