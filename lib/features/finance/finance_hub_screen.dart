import 'package:flutter/material.dart';

import '../debts/debts_screen.dart';
import 'credit_cards_screen.dart';
import 'finance_categories_screen.dart';
import 'finance_export_screen.dart';
import 'finance_planning_screen.dart';
import 'finance_reports_screen.dart';
import 'financial_goals_screen.dart';

class FinanceHubScreen extends StatelessWidget {
  const FinanceHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Central Financeira')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _HubHeader(),
          const SizedBox(height: 16),
          _HubSection(
            title: 'Visão e planejamento',
            subtitle: 'Organize contas, metas, limites e estrutura financeira.',
            children: [
              _HubActionCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Contas, saldos e planejamento',
                subtitle: 'Gerencie contas, saldos, transferências, reajustes e orçamentos.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancePlanningScreen())),
              ),
              _HubActionCard(
                icon: Icons.flag_outlined,
                title: 'Objetivos financeiros',
                subtitle: 'Acompanhe metas, progresso e sugestão de aporte mensal.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialGoalsScreen())),
              ),
              _HubActionCard(
                icon: Icons.category_outlined,
                title: 'Categorias e organização',
                subtitle: 'Ajuste categorias para relatórios, filtros e orçamento.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceCategoriesScreen())),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _HubSection(
            title: 'Compromissos e meios de pagamento',
            subtitle: 'Separe dívidas, cartão e pagamentos sem misturar conceitos.',
            children: [
              _HubActionCard(
                icon: Icons.money_off,
                title: 'Dívidas',
                subtitle: 'Veja dívidas, parcelas, atrasos e abatimentos dentro de Finanças.',
                highlightColor: Colors.deepOrange,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtsScreen())),
              ),
              _HubActionCard(
                icon: Icons.credit_card,
                title: 'Cartões e faturas',
                subtitle: 'Cadastre cartões, lance compras, mova faturas e registre pagamentos.',
                highlightColor: Colors.deepPurple,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreditCardsScreen())),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _HubSection(
            title: 'Análise e exportação',
            subtitle: 'Entenda padrões, compare períodos e leve dados para fora do app.',
            children: [
              _HubActionCard(
                icon: Icons.analytics_outlined,
                title: 'Central de relatórios',
                subtitle: 'Evolução mensal, débito vs crédito, categorias, subcategorias e previsto x realizado.',
                highlightColor: Colors.blue,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceReportsScreen())),
              ),
              _HubActionCard(
                icon: Icons.file_download_outlined,
                title: 'Exportação CSV',
                subtitle: 'Gere e copie CSV de transações, evolução mensal e débito vs crédito.',
                highlightColor: Colors.teal,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceExportScreen())),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _HubNoteCard(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _HubHeader extends StatelessWidget {
  const _HubHeader();

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
                CircleAvatar(child: Icon(Icons.auto_graph)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tudo que move seu dinheiro, em um só lugar',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Use esta central para acessar rapidamente planejamento, dívidas, cartões, objetivos, relatórios e exportações sem transformar a aba Finanças numa salada de botões.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class _HubSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _HubSection({required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
            ],
          ),
        ),
        ...children,
      ],
    );
  }
}

class _HubActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? highlightColor;
  final VoidCallback onTap;

  const _HubActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlightColor ?? Theme.of(context).colorScheme.primary;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _HubNoteCard extends StatelessWidget {
  const _HubNoteCard();

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
                'Esta central é modular: ela pode ser encaixada na aba Finanças sem alterar as telas internas já criadas nas fases anteriores.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
