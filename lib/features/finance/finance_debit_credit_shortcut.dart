import 'package:flutter/material.dart';

import 'finance_debit_credit_screen.dart';

class FinanceDebitCreditShortcut extends StatelessWidget {
  final String title;
  final String subtitle;

  const FinanceDebitCreditShortcut({
    super.key,
    this.title = 'Débito vs crédito',
    this.subtitle = 'Compare gastos diretos, compras no cartão e pagamentos de fatura.',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.credit_score_outlined)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceDebitCreditScreen()));
        },
      ),
    );
  }
}
