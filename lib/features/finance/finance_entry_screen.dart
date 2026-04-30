import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money_formatter.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/financial_category_model.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/providers.dart';
import '../debts/debts_screen.dart';
import 'create_transaction_screen.dart';
import 'credit_cards_screen.dart';
import 'finance_budget_rules.dart';
import 'finance_budgets_screen.dart';
import 'finance_categories_screen.dart';
import 'finance_export_screen.dart';
import 'finance_hub_screen.dart';
import 'finance_planning_screen.dart';
import 'finance_reports_screen.dart';
import 'finance_screen.dart';
import 'finance_screen_data.dart';
import 'finance_screen_data_provider.dart';
import 'finance_transaction_rules.dart';
import 'financial_goals_screen.dart';

class FinanceEntryScreen extends ConsumerStatefulWidget {
  const FinanceEntryScreen({super.key});

  @override
  ConsumerState<FinanceEntryScreen> createState() => _FinanceEntryScreenState();
}

class _FinanceEntryScreenState extends ConsumerState<FinanceEntryScreen> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
  }

  FinanceScreenFilters get _filters => FinanceScreenFilters(
        selectedMonth: _selectedMonth,
        filterType: 'all',
        filterStatus: 'all',
        filterCategory: null,
        filterSubcategory: null,
        searchQuery: '',
      );

  Future<void> _refreshData() async {
    await ref.read(transactionsProvider.notifier).loadTransactions();
    await ref.read(debtsProvider.notifier).loadDebts();
    ref.invalidate(financeBudgetsProvider);
    ref.invalidate(realAccountBalanceProvider);
    await Future.wait([
      ref.read(realAccountBalanceProvider.future),
      ref.read(financeBudgetsProvider.future),
    ]);
  }

  void _changeMonth(int delta) {
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta));
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
    final data = ref.watch(financeScreenDataProvider(_filters));
    final realBalanceAsync = ref.watch(realAccountBalanceProvider);
    final budgetsAsync = ref.watch(financeBudgetsProvider);
    final debts = ref.watch(debtsProvider);
    final categories = ref.watch(financialCategoriesProvider);
    final transactions = ref.watch(transactionsProvider);
    final budgetUsages = budgetsAsync.maybeWhen(
      data: (budgets) => FinanceBudgetRules.usageForAll(
        budgets.where((budget) => budget.month == _monthKey(_selectedMonth)).toList(),
        transactions,
      ),
      orElse: () => const <FinanceBudgetUsage>[],
    );
    final attention = _FinanceAttentionSnapshot.from(data: data, debts: debts, budgetUsages: budgetUsages);
    final recentMonthTransactions = _recentTransactions(data.filteredTransactions);
    final categoryHighlights = _categoryHighlights(data, categories);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              stretch: true,
              expandedHeight: 245,
              title: const Text('Finanças'),
              actions: [
                IconButton(
                  tooltip: 'Buscar movimentações',
                  icon: const Icon(Icons.search),
                  onPressed: () => _open(context, const FinanceScreen()),
                ),
                IconButton(
                  tooltip: 'Ajustes financeiros',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => _open(context, const FinanceHubScreen()),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: _SliverBalanceHeader(
                  month: _selectedMonth,
                  data: data,
                  realBalance: realBalanceAsync.valueOrNull,
                  isLoadingRealBalance: realBalanceAsync.isLoading,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _CompactMonthNavigationBar(
                  selectedMonth: _selectedMonth,
                  isCurrentMonth: _isCurrentMonth,
                  onPrevious: () => _changeMonth(-1),
                  onNext: () => _changeMonth(1),
                  onToday: _goToCurrentMonth,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: _ImmediateAttentionCarousel(
                  snapshot: attention,
                  isLoadingBudgets: budgetsAsync.isLoading,
                  onDebts: () => _open(context, const DebtsScreen()),
                  onTransactions: () => _open(context, const FinanceScreen()),
                  onBudgets: () => _open(context, const FinanceBudgetsScreen()),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _DashboardSectionTitle(
                  title: 'Visão rápida',
                  actionLabel: 'Relatórios',
                  onAction: () => _open(context, const FinanceReportsScreen()),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: _QuickChartsCard(
                  data: data,
                  categoryHighlights: categoryHighlights,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _DashboardSectionTitle(
                  title: 'Transações recentes',
                  actionLabel: 'Ver lista',
                  onAction: () => _open(context, const FinanceScreen()),
                ),
              ),
            ),
            if (recentMonthTransactions.isEmpty)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: _EmptyFinancePanel(
                    icon: Icons.receipt_long_outlined,
                    title: 'Nenhum lançamento neste mês',
                    subtitle: 'Use Novo lançamento para registrar receitas, despesas ou parcelas.',
                  ),
                ),
              )
            else
              SliverList.separated(
                itemCount: recentMonthTransactions.take(5).length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final transaction = recentMonthTransactions[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _RecentTransactionTile(
                      transaction: transaction,
                      onTap: () => _open(context, CreateTransactionScreen(transaction: transaction)),
                    ),
                  );
                },
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _DashboardSectionTitle(title: 'Ferramentas financeiras'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
              sliver: SliverGrid(
                delegate: SliverChildListDelegate.fixed([
                  _FinanceToolCard(icon: Icons.add_card_outlined, title: 'Lançar', subtitle: 'Receita ou despesa', color: Colors.green, onTap: () => _open(context, const CreateTransactionScreen())),
                  _FinanceToolCard(icon: Icons.receipt_long_outlined, title: 'Lista', subtitle: 'Filtros completos', color: Colors.blue, onTap: () => _open(context, const FinanceScreen())),
                  _FinanceToolCard(icon: Icons.account_balance_wallet_outlined, title: 'Contas', subtitle: 'Saldo e metas', color: Colors.teal, onTap: () => _open(context, const FinancePlanningScreen())),
                  _FinanceToolCard(icon: Icons.payments_outlined, title: 'Dívidas', subtitle: 'Acordos e parcelas', color: Colors.deepOrange, onTap: () => _open(context, const DebtsScreen())),
                  _FinanceToolCard(icon: Icons.credit_card, title: 'Cartões', subtitle: 'Faturas', color: Colors.deepPurple, onTap: () => _open(context, const CreditCardsScreen())),
                  _FinanceToolCard(icon: Icons.analytics_outlined, title: 'Relatórios', subtitle: 'Gráficos e CSV', color: Colors.indigo, onTap: () => _open(context, const FinanceReportsScreen())),
                  _FinanceToolCard(icon: Icons.flag_outlined, title: 'Metas', subtitle: 'Objetivos', color: Colors.pink, onTap: () => _open(context, const FinancialGoalsScreen())),
                  _FinanceToolCard(icon: Icons.category_outlined, title: 'Categorias', subtitle: 'Organizar', color: Colors.brown, onTap: () => _open(context, const FinanceCategoriesScreen())),
                  _FinanceToolCard(icon: Icons.file_download_outlined, title: 'Exportar', subtitle: 'Dados externos', color: Colors.blueGrey, onTap: () => _open(context, const FinanceExportScreen())),
                ]),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 0.92,
                ),
              ),
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

class _SliverBalanceHeader extends StatelessWidget {
  final DateTime month;
  final FinanceScreenData data;
  final double? realBalance;
  final bool isLoadingRealBalance;

  const _SliverBalanceHeader({required this.month, required this.data, required this.realBalance, required this.isLoadingRealBalance});

  @override
  Widget build(BuildContext context) {
    final summary = data.summary;
    final real = realBalance ?? 0;
    final realColor = real >= 0 ? Colors.green : Colors.red;
    final resultColor = summary.realizedResult >= 0 ? Colors.green : Colors.red;
    final forecastColor = summary.expectedBalance >= 0 ? Colors.green : Colors.red;
    final monthLabel = _capitalize(DateFormat('MMMM yyyy', 'pt_BR').format(month));

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.95), Theme.of(context).colorScheme.surface],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 66, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('Saldo consolidado', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: isLoadingRealBalance
                    ? Row(
                        key: const ValueKey('loading-balance'),
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 10), Text('Atualizando saldo', style: TextStyle(fontWeight: FontWeight.w800))],
                      )
                    : Text(_money(real), key: const ValueKey('real-balance'), textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: realColor)),
              ),
              const SizedBox(height: 4),
              Text('Resultado de $monthLabel: ${_money(summary.realizedResult)}', style: TextStyle(color: resultColor, fontWeight: FontWeight.w700)),
              const Spacer(),
              Row(
                children: [
                  Expanded(child: _FlowMiniCard(title: 'Receitas', value: summary.paidIncome, expected: summary.expectedIncome, icon: Icons.arrow_upward, color: Colors.green)),
                  const SizedBox(width: 10),
                  Expanded(child: _FlowMiniCard(title: 'Despesas', value: summary.paidExpense, expected: summary.expectedExpense, icon: Icons.arrow_downward, color: Colors.red)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: Text('Previsto: ${_money(summary.expectedBalance)}', style: TextStyle(color: forecastColor, fontWeight: FontWeight.w700))),
                  Text('${data.filteredTransactions.where((t) => t.status != 'canceled').length} mov.', style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FlowMiniCard extends StatelessWidget {
  final String title;
  final double value;
  final double expected;
  final IconData icon;
  final Color color;

  const _FlowMiniCard({required this.title, required this.value, required this.expected, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    final ratio = expected <= 0 ? 0.0 : (value / expected).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.86), borderRadius: BorderRadius.circular(18), border: Border.all(color: color.withValues(alpha: 0.14))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, color: color, size: 18), const SizedBox(width: 6), Text(title, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w700))]),
          const SizedBox(height: 6),
          Text(_money(value), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(999), child: LinearProgressIndicator(value: ratio, minHeight: 5, color: color, backgroundColor: color.withValues(alpha: 0.14))),
        ],
      ),
    );
  }
}

class _CompactMonthNavigationBar extends StatelessWidget {
  final DateTime selectedMonth;
  final bool isCurrentMonth;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;

  const _CompactMonthNavigationBar({required this.selectedMonth, required this.isCurrentMonth, required this.onPrevious, required this.onNext, required this.onToday});

  @override
  Widget build(BuildContext context) {
    final label = _capitalize(DateFormat('MMMM yyyy', 'pt_BR').format(selectedMonth));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.grey.shade300)),
      child: Row(
        children: [
          IconButton(tooltip: 'Mês anterior', onPressed: onPrevious, icon: const Icon(Icons.chevron_left)),
          Expanded(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800))),
          IconButton(tooltip: 'Próximo mês', onPressed: onNext, icon: const Icon(Icons.chevron_right)),
          if (!isCurrentMonth) TextButton(onPressed: onToday, child: const Text('Hoje')),
        ],
      ),
    );
  }
}

class _ImmediateAttentionCarousel extends StatelessWidget {
  final _FinanceAttentionSnapshot snapshot;
  final bool isLoadingBudgets;
  final VoidCallback onDebts;
  final VoidCallback onTransactions;
  final VoidCallback onBudgets;

  const _ImmediateAttentionCarousel({required this.snapshot, required this.isLoadingBudgets, required this.onDebts, required this.onTransactions, required this.onBudgets});

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _AttentionMiniCard(
        icon: Icons.event_note_outlined,
        title: 'Vencimentos próximos',
        value: snapshot.pendingTransactions == 0 ? 'Tudo certo' : '${snapshot.pendingTransactions} item(ns)',
        subtitle: snapshot.pendingAmount == 0 ? 'Nada pendente no mês' : _money(snapshot.pendingAmount),
        color: snapshot.pendingTransactions == 0 ? Colors.green : Colors.deepOrange,
        urgency: snapshot.pendingTransactions == 0 ? _AttentionUrgency.good : _AttentionUrgency.warning,
        onTap: onTransactions,
      ),
      _AttentionMiniCard(
        icon: Icons.payments_outlined,
        title: 'Dívidas críticas',
        value: snapshot.criticalDebts == 0 ? 'Sem alerta' : '${snapshot.criticalDebts} crítica(s)',
        subtitle: snapshot.openDebts == 0 ? 'Sem dívidas abertas' : '${snapshot.openDebts} abertas · ${_money(snapshot.openDebtAmount)}',
        color: snapshot.criticalDebts == 0 ? Colors.green : Colors.red,
        urgency: snapshot.criticalDebts == 0 ? _AttentionUrgency.good : _AttentionUrgency.danger,
        onTap: onDebts,
      ),
      _AttentionMiniCard(
        icon: Icons.warning_amber_outlined,
        title: 'Atrasos',
        value: snapshot.overdueTransactions == 0 ? 'Sem atraso' : '${snapshot.overdueTransactions} atraso(s)',
        subtitle: _money(snapshot.overdueAmount),
        color: snapshot.overdueTransactions == 0 ? Colors.green : Colors.red,
        urgency: snapshot.overdueTransactions == 0 ? _AttentionUrgency.good : _AttentionUrgency.danger,
        onTap: onTransactions,
      ),
      _AttentionMiniCard(
        icon: Icons.speed_outlined,
        title: 'Orçamentos no limite',
        value: isLoadingBudgets ? 'Carregando' : (snapshot.budgetsAtLimit == 0 ? 'Tudo ok' : '${snapshot.budgetsAtLimit} alerta(s)'),
        subtitle: isLoadingBudgets ? 'Verificando limites' : (snapshot.worstBudgetName ?? 'Nenhum orçamento acima de 80%'),
        color: snapshot.budgetsAtLimit == 0 ? Colors.indigo : Colors.deepOrange,
        urgency: snapshot.budgetsAtLimit == 0 ? _AttentionUrgency.good : _AttentionUrgency.warning,
        onTap: onBudgets,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DashboardSectionTitle(title: 'Atenção imediata'),
        const SizedBox(height: 8),
        SizedBox(
          height: 138,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) => SizedBox(width: 232, child: cards[index]),
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemCount: cards.length,
          ),
        ),
      ],
    );
  }
}

enum _AttentionUrgency { good, warning, danger }

class _AttentionMiniCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;
  final _AttentionUrgency urgency;
  final VoidCallback onTap;

  const _AttentionMiniCard({required this.icon, required this.title, required this.value, required this.subtitle, required this.color, required this.urgency, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final badgeLabel = switch (urgency) {
      _AttentionUrgency.good => 'OK',
      _AttentionUrgency.warning => 'Atenção',
      _AttentionUrgency.danger => 'Crítico',
    };
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: color.withValues(alpha: 0.22))),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
                    child: Text(badgeLabel, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 11)),
                  ),
                ],
              ),
              const Spacer(),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 17)),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickChartsCard extends StatelessWidget {
  final FinanceScreenData data;
  final List<_CategoryHighlight> categoryHighlights;

  const _QuickChartsCard({required this.data, required this.categoryHighlights});

  @override
  Widget build(BuildContext context) {
    final totalExpenses = data.summary.paidExpense;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 96, height: 96, child: CustomPaint(painter: _MiniPiePainter(items: categoryHighlights), child: Center(child: Text(totalExpenses <= 0 ? '0%' : 'Top\n${categoryHighlights.length}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))))),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Distribuição de despesas', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(totalExpenses <= 0 ? 'Sem despesas pagas no mês.' : 'Total pago: ${_money(totalExpenses)}', style: TextStyle(color: Colors.grey.shade700)),
                  const SizedBox(height: 10),
                  if (categoryHighlights.isEmpty)
                    Text('As maiores categorias aparecem aqui quando houver lançamentos pagos.', style: TextStyle(color: Colors.grey.shade700))
                  else
                    ...categoryHighlights.take(3).map((item) => _CategoryHighlightRow(item: item, total: totalExpenses)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryHighlightRow extends StatelessWidget {
  final _CategoryHighlight item;
  final double total;

  const _CategoryHighlightRow({required this.item, required this.total});

  @override
  Widget build(BuildContext context) {
    final percent = total <= 0 ? 0 : (item.amount / total) * 100;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(shape: BoxShape.circle, color: item.color)),
          const SizedBox(width: 8),
          Expanded(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
          Text('${percent.toStringAsFixed(0)}%', style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _MiniPiePainter extends CustomPainter {
  final List<_CategoryHighlight> items;

  const _MiniPiePainter({required this.items});

  @override
  void paint(Canvas canvas, Size size) {
    final total = items.fold<double>(0, (sum, item) => sum + item.amount);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()..style = PaintingStyle.fill;

    if (total <= 0) {
      paint.color = Colors.grey.shade200;
      canvas.drawCircle(center, radius, paint);
    } else {
      var start = -1.5708;
      for (final item in items) {
        final sweep = (item.amount / total) * 6.28318;
        paint.color = item.color;
        canvas.drawArc(rect, start, sweep, true, paint);
        start += sweep;
      }
    }

    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.56, paint);
  }

  @override
  bool shouldRepaint(covariant _MiniPiePainter oldDelegate) => oldDelegate.items != items;
}

class _DashboardSectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _DashboardSectionTitle({required this.title, this.actionLabel, this.onAction});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        if (actionLabel != null && onAction != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _RecentTransactionTile extends StatelessWidget {
  final FinancialTransaction transaction;
  final VoidCallback onTap;

  const _RecentTransactionTile({required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final date = FinanceTransactionRules.expectedDate(transaction);
    final isIncome = transaction.type == 'income';
    final isCanceled = transaction.status == 'canceled';
    final color = isCanceled ? Colors.grey : (isIncome ? Colors.green : Colors.red);
    final statusLabel = switch (transaction.status) { 'paid' => 'Pago', 'pending' => 'Pendente', 'overdue' => 'Atrasado', 'canceled' => 'Cancelado', _ => transaction.status };

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade300)),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward, color: color)),
        title: Text(transaction.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.w700, decoration: isCanceled ? TextDecoration.lineThrough : null)),
        subtitle: Text('${date == null ? 'Sem data' : DateFormat('dd/MM/yyyy').format(date)} • $statusLabel'),
        trailing: Text(_money(transaction.amount), style: TextStyle(color: color, fontWeight: FontWeight.w900, decoration: isCanceled ? TextDecoration.lineThrough : null)),
        onTap: onTap,
      ),
    );
  }
}

class _FinanceToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FinanceToolCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

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
              CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(icon, color: color)),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              const SizedBox(height: 2),
              Text(subtitle, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyFinancePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyFinancePanel({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(children: [Icon(icon, size: 34, color: Colors.grey.shade600), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(subtitle, style: TextStyle(color: Colors.grey.shade700))]))]),
      ),
    );
  }
}

class _FinanceAttentionSnapshot {
  final int pendingTransactions;
  final double pendingAmount;
  final int overdueTransactions;
  final double overdueAmount;
  final int openDebts;
  final int criticalDebts;
  final double openDebtAmount;
  final int budgetsAtLimit;
  final String? worstBudgetName;

  const _FinanceAttentionSnapshot({required this.pendingTransactions, required this.pendingAmount, required this.overdueTransactions, required this.overdueAmount, required this.openDebts, required this.criticalDebts, required this.openDebtAmount, required this.budgetsAtLimit, required this.worstBudgetName});

  factory _FinanceAttentionSnapshot.from({required FinanceScreenData data, required List<Debt> debts, required List<FinanceBudgetUsage> budgetUsages}) {
    final activeTransactions = data.filteredTransactions.where((transaction) => transaction.status != 'paid' && transaction.status != 'canceled').toList();
    final overdueTransactions = activeTransactions.where((transaction) => transaction.status == 'overdue' || FinanceTransactionRules.isOverdue(transaction)).toList();
    final openDebts = debts.where((debt) => debt.status != 'paid' && debt.status != 'canceled').toList();
    final criticalDebts = openDebts.where((debt) => debt.status == 'overdue').length;
    final budgetAlerts = budgetUsages.where((usage) => usage.plannedRatio >= 0.8 || usage.isOverPlanned).toList()
      ..sort((a, b) => b.plannedRatio.compareTo(a.plannedRatio));
    final worstBudget = budgetAlerts.isEmpty ? null : budgetAlerts.first;
    final worstBudgetName = worstBudget == null
        ? null
        : '${worstBudget.budget.name} · ${(worstBudget.plannedRatio * 100).clamp(0, 999).toStringAsFixed(0)}%';
    return _FinanceAttentionSnapshot(
      pendingTransactions: activeTransactions.length,
      pendingAmount: activeTransactions.fold<double>(0, (sum, transaction) => sum + transaction.amount),
      overdueTransactions: overdueTransactions.length,
      overdueAmount: overdueTransactions.fold<double>(0, (sum, transaction) => sum + transaction.amount),
      openDebts: openDebts.length,
      criticalDebts: criticalDebts,
      openDebtAmount: openDebts.fold<double>(0, (sum, debt) => sum + debt.totalAmount),
      budgetsAtLimit: budgetAlerts.length,
      worstBudgetName: worstBudgetName,
    );
  }
}

class _CategoryHighlight {
  final String name;
  final double amount;
  final Color color;

  const _CategoryHighlight({required this.name, required this.amount, required this.color});
}

List<_CategoryHighlight> _categoryHighlights(FinanceScreenData data, List<FinancialCategory> categories) {
  final categoryMap = {for (final category in categories) category.id: category};
  final entries = data.summary.paidExpensesByCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return entries.take(5).map((entry) {
    final category = categoryMap[entry.key];
    return _CategoryHighlight(name: category?.name ?? 'Sem categoria', amount: entry.value, color: _categoryColor(category));
  }).toList();
}

List<FinancialTransaction> _recentTransactions(List<FinancialTransaction> transactions) {
  final items = transactions.where((transaction) => transaction.status != 'canceled').toList()
    ..sort((a, b) {
      final aDate = FinanceTransactionRules.expectedDate(a) ?? DateTime(1900);
      final bDate = FinanceTransactionRules.expectedDate(b) ?? DateTime(1900);
      return bDate.compareTo(aDate);
    });
  return items;
}

Color _categoryColor(FinancialCategory? category) {
  if (category == null) return Colors.blueGrey;
  final parsed = int.tryParse(category.color);
  if (parsed == null) return Colors.blueGrey;
  return Color(parsed);
}

String _monthKey(DateTime month) => '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}';

String _money(num value) => MoneyFormatter.format(value);

String _capitalize(String value) {
  if (value.isEmpty) return value;
  return value[0].toUpperCase() + value.substring(1);
}
