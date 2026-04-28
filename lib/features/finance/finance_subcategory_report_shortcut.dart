import 'package:flutter/material.dart';

import 'finance_subcategory_report_screen.dart';

class FinanceSubcategoryReportShortcut extends StatelessWidget {
  final String title;
  final String subtitle;

  const FinanceSubcategoryReportShortcut({
    super.key,
    this.title = 'Gastos por subcategoria',
    this.subtitle = 'Veja ranking mensal, percentuais e maiores focos de gasto.',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.leaderboard_outlined)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceSubcategoryReportScreen()));
        },
      ),
    );
  }
}
