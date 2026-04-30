import 'package:flutter/material.dart';

import '../debts/debts_screen.dart';
import 'credit_cards_screen.dart';
import 'finance_budgets_screen.dart';
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
      appBar: AppBar(title: const Text('Ferramentas financeiras')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _ToolsHeader(),
          const SizedBox(height: 16),
          _ToolsSection(
            title: 'Configurar e organizar',
            subtitle: 'Cadastros e estruturas que alimentam o dashboard financeiro.',
            children: [
              _ToolActionCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Contas e saldos',
                subtitle: 'Contas, saldos, transferências e ajustes manuais.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancePlanningScreen())),
              ),
              _ToolActionCard(
                icon: Icons.category_outlined,
                title: 'Categorias',
                subtitle: 'Organização para filtros, relatórios e orçamentos.',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceCategoriesScreen())),
              ),
              _ToolActionCard(
                icon: Icons.credit_card,
                title: 'Cartões e faturas',
                subtitle: 'Cartões, compras, faturas e pagamentos vinculados.',
                highlightColor: Colors.deepPurple,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreditCardsScreen())),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ToolsSection(
            title: 'Planejar',
            subtitle: 'Limites, metas e compromissos financeiros.',
            children: [
              _ToolActionCard(
                icon: Icons.speed_outlined,
                title: 'Orçamentos',
                subtitle: 'Limites mensais por categoria e acompanhamento de uso.',
                highlightColor: Colors.orange,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceBudgetsScreen())),
              ),
              _ToolActionCard(
                icon: Icons.flag_outlined,
                title: 'Metas financeiras',
                subtitle: 'Objetivos de economia, progresso e valor alvo.',
                highlightColor: Colors.green,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancialGoalsScreen())),
              ),
              _ToolActionCard(
                icon: Icons.payments_outlined,
                title: 'Dívidas',
                subtitle: 'Dívidas, acordos, parcelas, atrasos e abatimentos.',
                highlightColor: Colors.deepOrange,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtsScreen())),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ToolsSection(
            title: 'Analisar e exportar',
            subtitle: 'Leitura de dados e saída para uso externo.',
            children: [
              _ToolActionCard(
                icon: Icons.analytics_outlined,
                title: 'Relatórios',
                subtitle: 'Gráficos, evolução mensal e distribuição por categoria.',
                highlightColor: Colors.blue,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceReportsScreen())),
              ),
              _ToolActionCard(
                icon: Icons.file_download_outlined,
                title: 'Exportação CSV',
                subtitle: 'Exportar transações e resumos financeiros.',
                highlightColor: Colors.teal,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceExportScreen())),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _ToolsNoteCard(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _ToolsHeader extends StatelessWidget {
  const _ToolsHeader();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(Icons.tune, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Ferramentas de gestão', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    'O dashboard principal fica na aba Finanças. Esta área reúne cadastros, configurações, relatórios e módulos auxiliares.',
                    style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolsSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _ToolsSection({required this.title, required this.subtitle, required this.children});

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
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
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

class _ToolActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color? highlightColor;
  final VoidCallback onTap;

  const _ToolActionCard({required this.icon, required this.title, required this.subtitle, required this.onTap, this.highlightColor});

  @override
  Widget build(BuildContext context) {
    final color = highlightColor ?? Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: color.withValues(alpha: 0.14))),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _ToolsNoteCard extends StatelessWidget {
  const _ToolsNoteCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.65),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: const Padding(
        padding: EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline),
            SizedBox(width: 10),
            Expanded(
              child: Text('Use esta tela para gerenciar o sistema financeiro. Para acompanhar saldo, vencimentos, gráficos e lançamentos recentes, volte ao dashboard de Finanças.'),
            ),
          ],
        ),
      ),
    );
  }
}
