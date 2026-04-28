import 'package:flutter/material.dart';

import 'finance_budgets_screen.dart';
import 'finance_category_report_screen.dart';
import 'finance_debit_credit_screen.dart';
import 'finance_monthly_evolution_screen.dart';
import 'finance_planned_vs_realized_report_screen.dart';
import 'finance_subcategory_report_screen.dart';

class FinanceReportsScreen extends StatelessWidget {
  const FinanceReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Relatórios Financeiros')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _ReportsHeader(),
          const SizedBox(height: 16),
          _ReportNavigationCard(
            icon: Icons.show_chart,
            title: 'Evolução mensal',
            subtitle: 'Compare receitas, despesas, resultado e economia mês a mês.',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceMonthlyEvolutionScreen())),
          ),
          const SizedBox(height: 8),
          _ReportNavigationCard(
            icon: Icons.credit_score_outlined,
            title: 'Débito vs crédito',
            subtitle: 'Compare gastos diretos, compras no cartão e pagamentos de fatura.',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceDebitCreditScreen())),
          ),
          const SizedBox(height: 8),
          _ReportNavigationCard(
            icon: Icons.compare_arrows,
            title: 'Previsto x realizado',
            subtitle: 'Compare receitas, despesas e resultado planejado com o que foi pago.',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancePlannedVsRealizedReportScreen())),
          ),
          const SizedBox(height: 8),
          _ReportNavigationCard(
            icon: Icons.category_outlined,
            title: 'Gastos por categoria',
            subtitle: 'Veja ranking mensal das maiores categorias de gasto.',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceCategoryReportScreen())),
          ),
          const SizedBox(height: 8),
          _ReportNavigationCard(
            icon: Icons.leaderboard_outlined,
            title: 'Gastos por subcategoria',
            subtitle: 'Ranking mensal, percentuais e maiores focos de gasto.',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceSubcategoryReportScreen())),
          ),
          const SizedBox(height: 8),
          _ReportNavigationCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Orçamentos avançados',
            subtitle: 'Acompanhe limites gerais, por categoria e por subcategoria.',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceBudgetsScreen())),
          ),
          const SizedBox(height: 16),
          const _ComingSoonCard(),
        ],
      ),
    );
  }
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                CircleAvatar(child: Icon(Icons.analytics_outlined)),
                SizedBox(width: 12),
                Expanded(child: Text('Central de análise', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Use estes relatórios para entender para onde o dinheiro está indo, acompanhar limites e encontrar padrões de gasto.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportNavigationCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ReportNavigationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.grey.withValues(alpha: 0.08),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Próximos relatórios', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('• Exportação futura em CSV/PDF'),
          ],
        ),
      ),
    );
  }
}
