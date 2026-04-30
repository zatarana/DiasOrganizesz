import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/finance_planning_store.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/providers.dart';
import '../debts/debts_screen.dart';
import 'create_transaction_screen.dart';
import 'credit_cards_screen.dart';
import 'finance_categories_screen.dart';
import 'finance_export_screen.dart';
import 'finance_hub_screen.dart';
import 'finance_planning_screen.dart';
import 'finance_reports_screen.dart';
import 'finance_screen.dart';
import 'financial_goals_screen.dart';

class FinanceEntryScreen extends ConsumerStatefulWidget {
  const FinanceEntryScreen({super.key});

  @override
  ConsumerState<FinanceEntryScreen> createState() => _FinanceEntryScreenState();
}

class _FinanceEntryScreenState extends ConsumerState<FinanceEntryScreen> {
  late Future<double> _realBalanceFuture;
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _realBalanceFuture = _loadRealBalance();
  }

  Future<double> _loadRealBalance() async {
    final db = await ref.read(dbProvider).database;
    await FinancePlanningStore.recalculateAllAccountBalances(db);
    return FinancePlanningStore.getActiveAccountsBalance(db);
  }

  Future<void> _refreshData() async {
    await ref.read(transactionsProvider.notifier).loadTransactions();
    await ref.read(debtsProvider.notifier).loadDebts();
    final nextBalanceFuture = _loadRealBalance();
    if (mounted) setState(() => _realBalanceFuture = nextBalanceFuture);
    await nextBalanceFuture;
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
  }

  void _goToCurrentMonth() {
    final now = DateTime.now();
    setState(() => _selectedMonth = DateTime(now.year, now.month));
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(transactionsProvider);
    final debts = ref.watch(debtsProvider);
    final monthTransactions = transactions.where((transaction) => _isSameMonth(_expectedDate(transaction), _selectedMonth)).toList();
    final dashboard = _FinanceDashboard.from(monthTransactions, debts);
    final upcoming = _upcomingTransactionsForMonth(transactions, _selectedMonth);
    final recentMonthTransactions = _recentTransactions(monthTransactions);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanças'),
        actions: [
          IconButton(
            tooltip: 'Tela completa',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => _open(context, const FinanceScreen()),
          ),
          IconButton(
            tooltip: 'Mais módulos',
            icon: const Icon(Icons.dashboard_customize_outlined),
            onPressed: () => _open(context, const FinanceHubScreen()),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          children: [
            _MonthNavigationBar(
              selectedMonth: _selectedMonth,
              isCurrentMonth: _isCurrentMonth,
              onPrevious: () => _changeMonth(-1),
              onNext: () => _changeMonth(1),
              onToday: _goToCurrentMonth,
            ),
            const SizedBox(height: 10),
            FutureBuilder<double>(
              future: _realBalanceFuture,
              builder: (context, snapshot) {
                return _MonthHeroCard(
                  month: _selectedMonth,
                  dashboard: dashboard,
                  realBalance: snapshot.data,
                  isLoadingRealBalance: snapshot.connectionState == ConnectionState.waiting,
                );
              },
            ),
            const SizedBox(height: 14),
            _QuickActionsGrid(
              onNewTransaction: () => _open(context, const CreateTransactionScreen()),
              onTransactions: () => _open(context, const FinanceScreen()),
              onPlanning: () => _open(context, const FinancePlanningScreen()),
              onDebts: () => _open(context, const DebtsScreen()),
              onReports: () => _open(context, const FinanceReportsScreen()),
              onCards: () => _open(context, const CreditCardsScreen()),
            ),
            const SizedBox(height: 14),
            _SectionTitle(
              title: 'Atenção em ${_capitalize(DateFormat('MMMM', 'pt_BR').format(_selectedMonth))}',
              actionLabel: 'Ver tudo',
              onAction: () => _open(context, const FinanceScreen()),
            ),
            const SizedBox(height: 8),
            _AttentionCard(dashboard: dashboard, upcoming: upcoming),
            const SizedBox(height: 14),
            _SectionTitle(
              title: 'Vencimentos do mês',
              actionLabel: 'Abrir lista',
              onAction: () => _open(context, const FinanceScreen()),
            ),
            const SizedBox(height: 8),
            if (upcoming.isEmpty)
              const _EmptyPanel(
                icon: Icons.event_available_outlined,
                title: 'Nada pendente neste mês',
                subtitle: 'Quando houver contas, receitas ou parcelas previstas para o mês selecionado, elas aparecem aqui.',
              )
            else
              ...upcoming.take(5).map((transaction) => _UpcomingTransactionTile(transaction: transaction)),
            const SizedBox(height: 14),
            _SectionTitle(
              title: 'Últimas movimentações do mês',
              actionLabel: 'Ver lista',
              onAction: () => _open(context, const FinanceScreen()),
            ),
            const SizedBox(height: 8),
            if (recentMonthTransactions.isEmpty)
              const _EmptyPanel(
                icon: Icons.receipt_long_outlined,
                title: 'Nenhum lançamento neste mês',
                subtitle: 'Use o botão Novo lançamento para começar a registrar receitas e despesas.',
              )
            else
              ...recentMonthTransactions.take(5).map((transaction) => _RecentTransactionTile(transaction: transaction)),
            const SizedBox(height: 14),
            _SectionTitle(title: 'Módulos financeiros'),
            const SizedBox(height: 8),
            _ModuleShortcutList(
              onGoals: () => _open(context, const FinancialGoalsScreen()),
              onCategories: () => _open(context, const FinanceCategoriesScreen()),
              onExport: () => _open(context, const FinanceExportScreen()),
              onCentral: () => _open(context, const FinanceHubScreen()),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context, const CreateTransactionScreen()),
        icon: const Icon(Icons.add),
        label: const Text('Novo lançamento'),
      ),
    );
  }

  static void _open(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}

class _MonthNavigationBar extends StatelessWidget {
  final DateTime selectedMonth;
  final bool isCurrentMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _MonthNavigationBar({
    required this.selectedMonth,
    required this.isCurrentMonth,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
  });

  @override
  Widget build(BuildContext context) {
    final label = _capitalize(DateFormat('MMMM yyyy', 'pt_BR').format(selectedMonth));
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            IconButton(tooltip: 'Mês anterior', onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Column(
                children: [
                  Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(isCurrentMonth ? 'Mês atual' : 'Visualizando outro mês', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                ],
              ),
            ),
            IconButton(tooltip: 'Próximo mês', onPressed: onNext, icon: const Icon(Icons.chevron_right)),
            if (!isCurrentMonth)
              TextButton(onPressed: onToday, child: const Text('Hoje')),
          ],
        ),
      ),
    );
  }
}

class _MonthHeroCard extends StatelessWidget {
  final DateTime month;
  final _FinanceDashboard dashboard;
  final double? realBalance;
  final bool isLoadingRealBalance;

  const _MonthHeroCard({
    required this.month,
    required this.dashboard,
    required this.realBalance,
    required this.isLoadingRealBalance,
  });

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'pt_BR').format(month);
    final resolvedRealBalance = realBalance ?? 0;
    final realBalanceColor = resolvedRealBalance >= 0 ? Colors.green : Colors.red;
    final resultColor = dashboard.monthResult >= 0 ? Colors.green : Colors.red;
    final forecastColor = dashboard.forecastResult >= 0 ? Colors.green : Colors.red;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.55),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Saldo real agora', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: isLoadingRealBalance
                            ? Row(
                                key: const ValueKey('loading-balance'),
                                children: const [
                                  SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                                  SizedBox(width: 10),
                                  Text('Atualizando saldo...', style: TextStyle(fontWeight: FontWeight.w700)),
                                ],
                              )
                            : Text(
                                _money(resolvedRealBalance),
                                key: const ValueKey('real-balance'),
                                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: realBalanceColor),
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Soma das contas ativas, já recalculada com lançamentos pagos e transferências.',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white.withValues(alpha: 0.8),
                  child: Icon(Icons.account_balance_wallet_outlined, color: realBalanceColor, size: 30),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.insights_outlined, color: forecastColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Resultado previsto em ${_capitalize(monthLabel)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                        Text(_money(dashboard.forecastResult), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: forecastColor)),
                      ],
                    ),
                  ),
                  Text('${dashboard.totalMovements} mov.', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _HeroMetric(label: 'Resultado do mês', value: _money(dashboard.monthResult), color: resultColor)),
                const SizedBox(width: 8),
                Expanded(child: _HeroMetric(label: 'Recebido', value: _money(dashboard.paidIncome), color: Colors.green)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _HeroMetric(label: 'Pago', value: _money(dashboard.paidExpense), color: Colors.red)),
                const SizedBox(width: 8),
                Expanded(child: _HeroMetric(label: 'A receber', value: _money(dashboard.pendingIncome), color: Colors.teal)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _HeroMetric(label: 'A pagar', value: _money(dashboard.pendingExpense), color: Colors.deepOrange)),
                const SizedBox(width: 8),
                Expanded(child: _HeroMetric(label: 'Dívidas', value: '${dashboard.openDebts} · ${_money(dashboard.openDebtAmount)}', color: Colors.brown)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeroMetric({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  final VoidCallback onNewTransaction;
  final VoidCallback onTransactions;
  final VoidCallback onPlanning;
  final VoidCallback onDebts;
  final VoidCallback onReports;
  final VoidCallback onCards;

  const _QuickActionsGrid({
    required this.onNewTransaction,
    required this.onTransactions,
    required this.onPlanning,
    required this.onDebts,
    required this.onReports,
    required this.onCards,
  });

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(icon: Icons.add_card_outlined, label: 'Lançar', color: Colors.green, onTap: onNewTransaction),
      _QuickAction(icon: Icons.receipt_long_outlined, label: 'Movimentações', color: Colors.blue, onTap: onTransactions),
      _QuickAction(icon: Icons.account_balance_wallet_outlined, label: 'Contas', color: Colors.teal, onTap: onPlanning),
      _QuickAction(icon: Icons.payments_outlined, label: 'Dívidas', color: Colors.deepOrange, onTap: onDebts),
      _QuickAction(icon: Icons.analytics_outlined, label: 'Relatórios', color: Colors.indigo, onTap: onReports),
      _QuickAction(icon: Icons.credit_card, label: 'Cartões', color: Colors.deepPurple, onTap: onCards),
    ];

    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.96,
      ),
      itemBuilder: (context, index) => actions[index],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: color.withValues(alpha: 0.16))),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionTitle({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _AttentionCard extends StatelessWidget {
  final _FinanceDashboard dashboard;
  final List<FinancialTransaction> upcoming;

  const _AttentionCard({required this.dashboard, required this.upcoming});

  @override
  Widget build(BuildContext context) {
    final alerts = <_AttentionItem>[
      if (dashboard.overdueCount > 0)
        _AttentionItem(Icons.warning_amber_outlined, '${dashboard.overdueCount} movimentação(ões) em atraso', _money(dashboard.overdueAmount), Colors.red),
      if (dashboard.pendingExpense > 0)
        _AttentionItem(Icons.schedule_outlined, 'Despesas pendentes no mês', _money(dashboard.pendingExpense), Colors.deepOrange),
      if (dashboard.pendingIncome > 0)
        _AttentionItem(Icons.request_quote_outlined, 'Receitas a receber', _money(dashboard.pendingIncome), Colors.teal),
      if (dashboard.openDebts > 0)
        _AttentionItem(Icons.payments_outlined, 'Dívidas abertas', '${dashboard.openDebts} registro(s)', Colors.blueGrey),
      if (upcoming.isNotEmpty)
        _AttentionItem(Icons.event_note_outlined, 'Vencimentos do mês', '${upcoming.length} item(ns)', Colors.indigo),
    ];

    if (alerts.isEmpty) {
      return const _EmptyPanel(
        icon: Icons.check_circle_outline,
        title: 'Tudo tranquilo por enquanto',
        subtitle: 'Sem atrasos, dívidas abertas ou pendências relevantes no mês.',
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: alerts.map((item) => _AttentionRow(item: item)).toList()),
      ),
    );
  }
}

class _AttentionItem {
  final IconData icon;
  final String title;
  final String value;
  final Color color;

  const _AttentionItem(this.icon, this.title, this.value, this.color);
}

class _AttentionRow extends StatelessWidget {
  final _AttentionItem item;

  const _AttentionRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(backgroundColor: item.color.withValues(alpha: 0.12), child: Icon(item.icon, color: item.color)),
      title: Text(item.title),
      trailing: Text(item.value, style: TextStyle(fontWeight: FontWeight.bold, color: item.color)),
    );
  }
}

class _UpcomingTransactionTile extends StatelessWidget {
  final FinancialTransaction transaction;

  const _UpcomingTransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final date = _expectedDate(transaction);
    final isIncome = transaction.type == 'income';
    final color = transaction.status == 'overdue' ? Colors.red : (isIncome ? Colors.green : Colors.deepOrange);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward, color: color),
        ),
        title: Text(transaction.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(date == null ? 'Sem data prevista' : DateFormat('dd/MM/yyyy').format(date)),
        trailing: Text(_money(transaction.amount), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _RecentTransactionTile extends StatelessWidget {
  final FinancialTransaction transaction;

  const _RecentTransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final date = _expectedDate(transaction);
    final isIncome = transaction.type == 'income';
    final isCanceled = transaction.status == 'canceled';
    final color = isCanceled ? Colors.grey : (isIncome ? Colors.green : Colors.red);
    final statusLabel = switch (transaction.status) {
      'paid' => 'Pago',
      'pending' => 'Pendente',
      'overdue' => 'Atrasado',
      'canceled' => 'Cancelado',
      _ => transaction.status,
    };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward, color: color),
        ),
        title: Text(transaction.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w600, decoration: isCanceled ? TextDecoration.lineThrough : null)),
        subtitle: Text('${date == null ? 'Sem data' : DateFormat('dd/MM/yyyy').format(date)} • $statusLabel'),
        trailing: Text(_money(transaction.amount), style: TextStyle(color: color, fontWeight: FontWeight.bold, decoration: isCanceled ? TextDecoration.lineThrough : null)),
      ),
    );
  }
}

class _ModuleShortcutList extends StatelessWidget {
  final VoidCallback onGoals;
  final VoidCallback onCategories;
  final VoidCallback onExport;
  final VoidCallback onCentral;

  const _ModuleShortcutList({required this.onGoals, required this.onCategories, required this.onExport, required this.onCentral});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.shade300)),
      child: Column(
        children: [
          _ModuleTile(icon: Icons.flag_outlined, title: 'Objetivos financeiros', subtitle: 'Metas e progresso', onTap: onGoals),
          const Divider(height: 1),
          _ModuleTile(icon: Icons.category_outlined, title: 'Categorias', subtitle: 'Organização de receitas e despesas', onTap: onCategories),
          const Divider(height: 1),
          _ModuleTile(icon: Icons.file_download_outlined, title: 'Exportar dados', subtitle: 'CSV e relatórios externos', onTap: onExport),
          const Divider(height: 1),
          _ModuleTile(icon: Icons.dashboard_customize_outlined, title: 'Central financeira completa', subtitle: 'Todos os módulos em lista', onTap: onCentral),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModuleTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyPanel({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(icon, size: 34, color: Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade700)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinanceDashboard {
  final double paidIncome;
  final double paidExpense;
  final double pendingIncome;
  final double pendingExpense;
  final double overdueAmount;
  final int overdueCount;
  final int openDebts;
  final double openDebtAmount;
  final int totalMovements;

  const _FinanceDashboard({
    required this.paidIncome,
    required this.paidExpense,
    required this.pendingIncome,
    required this.pendingExpense,
    required this.overdueAmount,
    required this.overdueCount,
    required this.openDebts,
    required this.openDebtAmount,
    required this.totalMovements,
  });

  double get monthResult => paidIncome - paidExpense;
  double get forecastResult => (paidIncome + pendingIncome) - (paidExpense + pendingExpense);

  factory _FinanceDashboard.from(List<FinancialTransaction> monthTransactions, List<Debt> debts) {
    double sumWhere(bool Function(FinancialTransaction transaction) test) {
      return monthTransactions.where(test).fold<double>(0, (sum, transaction) => sum + transaction.amount);
    }

    final overdueTransactions = monthTransactions.where((transaction) => transaction.status == 'overdue').toList();
    final openDebts = debts.where((debt) => debt.status != 'paid' && debt.status != 'canceled').toList();
    return _FinanceDashboard(
      paidIncome: sumWhere((transaction) => transaction.status == 'paid' && transaction.type == 'income'),
      paidExpense: sumWhere((transaction) => transaction.status == 'paid' && transaction.type == 'expense'),
      pendingIncome: sumWhere((transaction) => transaction.status != 'canceled' && transaction.status != 'paid' && transaction.type == 'income'),
      pendingExpense: sumWhere((transaction) => transaction.status != 'canceled' && transaction.status != 'paid' && transaction.type == 'expense'),
      overdueAmount: overdueTransactions.fold<double>(0, (sum, transaction) => sum + transaction.amount),
      overdueCount: overdueTransactions.length,
      openDebts: openDebts.length,
      openDebtAmount: openDebts.fold<double>(0, (sum, debt) => sum + debt.totalAmount),
      totalMovements: monthTransactions.where((transaction) => transaction.status != 'canceled').length,
    );
  }
}

List<FinancialTransaction> _upcomingTransactionsForMonth(List<FinancialTransaction> transactions, DateTime month) {
  final upcoming = transactions.where((transaction) {
    if (transaction.status == 'paid' || transaction.status == 'canceled') return false;
    return _isSameMonth(_expectedDate(transaction), month);
  }).toList();

  upcoming.sort((a, b) {
    final aDate = _expectedDate(a) ?? DateTime(2100);
    final bDate = _expectedDate(b) ?? DateTime(2100);
    return aDate.compareTo(bDate);
  });
  return upcoming;
}

List<FinancialTransaction> _recentTransactions(List<FinancialTransaction> transactions) {
  final items = [...transactions]..sort((a, b) {
      final aDate = _expectedDate(a) ?? DateTime(1900);
      final bDate = _expectedDate(b) ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });
  return items;
}

DateTime? _expectedDate(FinancialTransaction transaction) {
  return DateTime.tryParse(transaction.dueDate ?? transaction.transactionDate);
}

bool _isSameMonth(DateTime? date, DateTime month) {
  if (date == null) return false;
  return date.year == month.year && date.month == month.month;
}

String _money(num value) {
  return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 2).format(value);
}

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}
