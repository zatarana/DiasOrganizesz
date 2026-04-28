import 'package:flutter/material.dart';

import 'finance_export_screen.dart';

class FinanceExportShortcut extends StatelessWidget {
  final String title;
  final String subtitle;

  const FinanceExportShortcut({
    super.key,
    this.title = 'Exportação CSV',
    this.subtitle = 'Gere CSV de transações, evolução mensal e débito vs crédito.',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.file_download_outlined)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceExportScreen()));
        },
      ),
    );
  }
}
