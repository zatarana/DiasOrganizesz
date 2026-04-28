import 'package:flutter/material.dart';

import 'finance_entry_screen.dart';

class FinanceEntryShortcut extends StatelessWidget {
  final String title;
  final String subtitle;

  const FinanceEntryShortcut({
    super.key,
    this.title = 'Finanças',
    this.subtitle = 'Abra movimentações do mês ou a Central Financeira completa.',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.account_balance_wallet_outlined)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceEntryScreen()));
        },
      ),
    );
  }
}
