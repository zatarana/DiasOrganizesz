import 'package:flutter/material.dart';

import 'finance_hub_screen.dart';
import 'finance_screen.dart';

class FinanceEntryScreen extends StatelessWidget {
  const FinanceEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finanças')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _EntryHeader(),
          const SizedBox(height: 16),
          _EntryCard(
            icon: Icons.receipt_long,
            title: 'Movimentações do mês',
            subtitle: 'Abra a tela clássica de receitas, despesas, filtros, busca, dívidas vinculadas e lançamentos recorrentes.',
            color: Colors.green,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen())),
          ),
          const SizedBox(height: 8),
          _EntryCard(
            icon: Icons.auto_graph,
            title: 'Central Financeira',
            subtitle: 'Acesse planejamento, contas, cartões, faturas, objetivos, relatórios, exportação e categorias.',
            color: Colors.blue,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceHubScreen())),
          ),
          const SizedBox(height: 16),
          const _EntryNote(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Lançar'),
      ),
    );
  }
}

class _EntryHeader extends StatelessWidget {
  const _EntryHeader();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                CircleAvatar(child: Icon(Icons.account_balance_wallet_outlined)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Escolha o que quer fazer agora',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'A tela de entrada separa o uso diário das análises avançadas. Assim o app continua rápido para lançar despesas, mas a central completa fica sempre a um toque.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _EntryCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _EntryNote extends StatelessWidget {
  const _EntryNote();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey.withValues(alpha: 0.08),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Esta tela foi criada como substituta segura da entrada antiga de Finanças. A troca da rota principal pode ser feita depois com baixo risco.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
