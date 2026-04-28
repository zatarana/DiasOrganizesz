import 'package:flutter/material.dart';

import 'credit_cards_screen.dart';

class CreditCardsShortcut extends StatelessWidget {
  final String title;
  final String subtitle;

  const CreditCardsShortcut({
    super.key,
    this.title = 'Cartões e faturas',
    this.subtitle = 'Cadastre cartões, acompanhe faturas e registre pagamentos.',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.credit_card)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreditCardsScreen()));
        },
      ),
    );
  }
}
