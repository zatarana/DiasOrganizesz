import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/finance_planning_store.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/financial_category_model.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/providers.dart';
import '../debts/debts_screen.dart';
import 'create_transaction_screen.dart';
import 'finance_categories_screen.dart';
import 'finance_debt_snapshot.dart';
import 'finance_planning_screen.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  DateTime _selectedMonth = DateTime.now();
  String _filterType = 'all';
  String _filterStatus = 'all';
  int? _filterCategory;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _nextMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1));
  void _prevMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1));
  void _currentMonth() => setState(() => _selectedMonth = DateTime.now());

  Future<void> _openPlanning() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancePlanningScreen()));
    if (mounted) setState(() {});
  }

  Future<void> _openDebts() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtsScreen()));
    if (mounted) setState(() {});
  }

  Future<void> _openTransactionForm({FinancialTransaction? transaction}) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTransactionScreen(transaction: transaction)));
    if (mounted) setState(() {});
  }

  bool _isSameMonth(DateTime? date, DateTime month) => date != null && date.month == month.month && date.year == month.year;
  DateTime? _expectedDate(FinancialTransaction transaction) => DateTime.tryParse(transaction.dueDate ?? transaction.transactionDate);
  DateTime? _paidDate(FinancialTransaction transaction) => transaction.paidDate == null ? null : DateTime.tryParse(transaction.paidDate!);

  Future<double> _loadRealAccountBalance() async {
    final db = await ref.read(dbProvider).database;
    return FinancePlanningStore.getActiveAccountsBalance(db);
  }

  FinancialCategory? _categoryOf(List<FinancialCategory> categories, int? categoryId) {
    if (categoryId == null) return null;
    for (final category in categories) {
      if (category.id == categoryId) return category;
    }
    return null;
  }

  Debt? _debtOf(List<Debt> debts, int? debtId) {
    if (debtId == null) return null;
    for (final debt in debts) {
      if (debt.id == debtId) return debt;
    }
    return null;
  }

  Color _transactionColor(FinancialTransaction transaction, FinancialCategory? category) {
    if (transaction.debtId != null) return Colors.deepOrange;
    if (category != null) return Color(int.tryParse(category.color) ?? 0xFF607D8B);
    return transaction.type == 'income' ? Colors.green : Colors.red;
  }

  DateTime _safeMonthlyDate(DateTime original, DateTime targetMonth) {
    final daysInMonth = DateUtils.getDaysInMonth(targetMonth.year, targetMonth.month);
    final day = original.day > daysInMonth ? daysInMonth : original.day;
    return DateTime(targetMonth.year, targetMonth.month, day, original.hour, original.minute, original.second);
  }

  bool _belongsToSelectedMonth(FinancialTransaction transaction) {
    final expected = _expectedDate(transaction);
    final paid = _paidDate(transaction);
    return _isSameMonth(expected, _selectedMonth) || _isSameMonth(paid, _selectedMonth);
  }

  bool _looksLikeDuplicateFixedTransaction(FinancialTransaction existing, FinancialTransaction source, DateTime targetExpectedDate) {
    if (existing.status == 'canceled') return false;
    if (!existing.isFixed) return false;
    final existingExpected = _expectedDate(existing);
    if (!_isSameMonth(existingExpected, targetExpectedDate)) return false;
    return existing.title == source.title &&
        existing.type == source.type &&
        existing.categoryId == source.categoryId &&
        existing.amount.toStringAsFixed(2) == source.amount.toStringAsFixed(2);
  }

  Future<void> _generateFixedTransactions() async {
    final allTransactions = ref.read(transactionsProvider);
    final accounts = await FinancePlanningStore.getAccounts(await ref.read(dbProvider).database);
    final activeAccountIds = accounts.where((account) => !account.isArchived && account.id != null).map((account) => account.id!).toSet();
    final previousMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);

    final previousFixed = allTransactions.where((transaction) {
      final expected = _expectedDate(transaction);
      return expected != null &&
          expected.month == previousMonth.month &&
          expected.year == previousMonth.year &&
          transaction.isFixed &&
          transaction.recurrenceType == 'monthly' &&
          transaction.status != 'canceled' &&
          transaction.debtId == null;
    }).toList();

    int added = 0;
    int skipped = 0;
    int accountCleared = 0;

    for (final source in previousFixed) {
      final oldTransactionDate = DateTime.tryParse(source.transactionDate) ?? previousMonth;
      final newTransactionDate = _safeMonthlyDate(oldTransactionDate, _selectedMonth);

      DateTime? newDueDate;
      if (source.dueDate != null) {
        final oldDue = DateTime.tryParse(source.dueDate!);
        if (oldDue != null) newDueDate = _safeMonthlyDate(oldDue, _selectedMonth);
      }

      final expectedTarget = newDueDate ?? newTransactionDate;
      final duplicated = allTransactions.any((existing) => _looksLikeDuplicateFixedTransaction(existing, source, expectedTarget));
      if (duplicated) {
        skipped++;
        continue;
      }

      final copiedAccountId = source.accountId != null && activeAccountIds.contains(source.accountId) ? source.accountId : null;
      if (source.accountId != null && copiedAccountId == null) accountCleared++;

      final now = DateTime.now().toIso8601String();
      final newTransaction = FinancialTransaction(
        title: source.title,
        description: source.description,
        amount: source.amount,
        type: source.type,
        transactionDate: newTransactionDate.toIso8601String(),
        dueDate: newDueDate?.toIso8601String(),
        paidDate: null,
        categoryId: source.categoryId,
        accountId: copiedAccountId,
        paymentMethod: source.paymentMethod,
        status: 'pending',
        reminderEnabled: source.reminderEnabled,
        isFixed: true,
        recurrenceType: 'monthly',
        notes: source.notes,
        createdAt: now,
        updatedAt: now,
      );
      await ref.read(transactionsProvider.notifier).addTransaction(newTransaction);
      added++;
    }

    if (!mounted) return;
    final message = added > 0
        ? '$added lançamento(s) fixo(s) gerado(s). ${skipped > 0 ? '$skipped duplicado(s) ignorado(s).' : ''}${accountCleared > 0 ? ' $accountCleared conta(s) arquivada(s) removida(s).' : ''}'
        : skipped > 0
            ? 'Nenhum lançamento novo. $skipped recorrente(s) já existiam neste mês.'
            : 'Nenhum lançamento fixo encontrado no mês anterior.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    setState(() {});
  }

  String _statusAfterUnpay(FinancialTransaction transaction) {
    final expected = _expectedDate(transaction);
    if (expected == null) return 'pending';
    final due = DateTime(expected.year, expected.month, expected.day);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return due.isBefore(today) ? 'overdue' : 'pending';
  }

  Future<void> _togglePaid(FinancialTransaction transaction, bool isPaid) async {
    if (isPaid && transaction.accountId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha uma conta antes de marcar como pago.')));
      await _openTransactionForm(transaction: transaction);
      return;
    }

    final updated = transaction.copyWith(
      status: isPaid ? 'paid' : _statusAfterUnpay(transaction),
      paidDate: isPaid ? DateTime.now().toIso8601String() : null,
      clearPaidDate: !isPaid,
      updatedAt: DateTime.now().toIso8601String(),
    );
    await ref.read(transactionsProvider.notifier).updateTransaction(updated);
    setState(() {});
  }

  double _paidIncomeForMonth(List<FinancialTransaction> transactions, DateTime month) {
    return transactions
        .where((t) => t.status == 'paid' && t.type == 'income' && (_isSameMonth(_paidDate(t), month) || (_paidDate(t) == null && _isSameMonth(_expectedDate(t), month))))
        .fold<double>(0, (sum, t) => sum + t.amount);
  }

  double _paidExpenseForMonth(List<FinancialTransaction> transactions, DateTime month) {
    return transactions
        .where((t) => t.status == 'paid' && t.type == 'expense' && (_isSameMonth(_paidDate(t), month) || (_paidDate(t) == null && _isSameMonth(_expectedDate(t), month))))
        .fold<double>(0, (sum, t) => sum + t.amount);
  }

  Map<int?, double> _paidExpensesByCategory(List<FinancialTransaction> transactions, DateTime month) {
    final result = <int?, double>{};
    for (final transaction in transactions) {
      if (transaction.status != 'paid' || transaction.type != 'expense') continue;
      final paid = _paidDate(transaction);
      final expected = _expectedDate(transaction);
      final inMonth = _isSameMonth(paid, month) || (paid == null && _isSameMonth(expected, month));
      if (!inMonth) continue;
      result[transaction.categoryId] = (result[transaction.categoryId] ?? 0) + transaction.amount;
    }
    return result;
  }

  bool _matchesSearch(FinancialTransaction transaction, FinancialCategory? category, Debt? debt, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    final fields = [
      transaction.title,
      transaction.description ?? '',
      transaction.notes ?? '',
      transaction.paymentMethod ?? '',
      category?.name ?? '',
      debt?.name ?? '',
      debt?.creditorName ?? '',
      transaction.installmentNumber == null ? '' : 'parcela ${transaction.installmentNumber}/${transaction.totalInstallments ?? ''}',
    ];
    return fields.any((field) => field.toLowerCase().contains(q));
  }

  String _money(num value) => 'R\$ ${value.toDouble().toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    final allTransactions = ref.watch(transactionsProvider);
    final allCategories = ref.watch(financialCategoriesProvider);
    final allDebts = ref.watch(debtsProvider);
    final debtSnapshot = FinanceDebtSnapshot.from(debts: allDebts, transactions: allTransactions, selectedMonth: _selectedMonth);

    final filtered = allTransactions.where((transaction) {
      if (transaction.status == 'canceled' && _filterStatus != 'all') return false;
      if (!_belongsToSelectedMonth(transaction)) return false;
      if (_filterType == 'income' && transaction.type != 'income') return false;
      if (_filterType == 'expense' && transaction.type != 'expense') return false;
      if (_filterType == 'debt' && transaction.debtId == null) return false;
      if (_filterStatus == 'paid' && transaction.status != 'paid') return false;
      if (_filterStatus == 'pending' && transaction.status != 'pending') return false;
      if (_filterStatus == 'overdue' && transaction.status != 'overdue') return false;
      if (_filterCategory != null && transaction.categoryId != _filterCategory) return false;
      final category = _categoryOf(allCategories, transaction.categoryId);
      final debt = _debtOf(allDebts, transaction.debtId);
      return _matchesSearch(transaction, category, debt, _searchController.text.trim());
    }).toList()
      ..sort((a, b) => (_expectedDate(a) ?? DateTime(2100)).compareTo(_expectedDate(b) ?? DateTime(2100)));

    double receitasPrevistas = 0;
    double despesasPrevistas = 0;
    double receitasPagas = 0;
    double despesasPagas = 0;
    int despesasVencidas = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final transaction in allTransactions.where((t) => t.status != 'canceled')) {
      final expected = _expectedDate(transaction);
      final paid = _paidDate(transaction);
      final expectedInMonth = _isSameMonth(expected, _selectedMonth);
      final paidInMonth = transaction.status == 'paid' && (_isSameMonth(paid, _selectedMonth) || (paid == null && expectedInMonth));

      if (expectedInMonth) {
        if (transaction.type == 'income') {
          receitasPrevistas += transaction.amount;
        } else {
          despesasPrevistas += transaction.amount;
          final due = expected == null ? null : DateTime(expected.year, expected.month, expected.day);
          if ((transaction.status == 'pending' || transaction.status == 'overdue') && due != null && due.isBefore(today)) despesasVencidas++;
        }
      }

      if (paidInMonth) {
        if (transaction.type == 'income') {
          receitasPagas += transaction.amount;
        } else {
          despesasPagas += transaction.amount;
        }
      }
    }

    final saldoPrevisto = receitasPrevistas - despesasPrevistas;
    final resultadoRealizado = receitasPagas - despesasPagas;
    final previousMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    final previousResult = _paidIncomeForMonth(allTransactions, previousMonth) - _paidExpenseForMonth(allTransactions, previousMonth);
    final resultDiff = resultadoRealizado - previousResult;
    final expenseDiff = despesasPagas - _paidExpenseForMonth(allTransactions, previousMonth);
    final paidExpenseRatio = despesasPrevistas <= 0 ? 0.0 : (despesasPagas / despesasPrevistas).clamp(0.0, 1.0).toDouble();
    final categoryTotals = _paidExpensesByCategory(allTransactions, _selectedMonth).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topCategoryEntry = categoryTotals.isEmpty ? null : categoryTotals.first;
    final topCategory = topCategoryEntry == null ? null : _categoryOf(allCategories, topCategoryEntry.key);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanças'),
        actions: [
          IconButton(icon: const Icon(Icons.savings_outlined), onPressed: _openPlanning, tooltip: 'Contas, orçamentos e metas'),
          IconButton(icon: const Icon(Icons.money_off), onPressed: _openDebts, tooltip: 'Dívidas'),
          IconButton(icon: const Icon(Icons.auto_mode), onPressed: _generateFixedTransactions, tooltip: 'Gerar recorrentes'),
          IconButton(icon: const Icon(Icons.category), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceCategoriesScreen())), tooltip: 'Categorias'),
        ],
      ),
      body: FutureBuilder<double>(
        future: _loadRealAccountBalance(),
        builder: (context, accountSnapshot) {
          final realAccountBalance = accountSnapshot.data ?? 0;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: ElevatedButton.icon(onPressed: _openPlanning, icon: const Icon(Icons.account_balance_wallet_outlined), label: const Text('Contas e metas'))),
                          const SizedBox(width: 8),
                          Expanded(child: OutlinedButton.icon(onPressed: _openDebts, icon: const Icon(Icons.money_off), label: const Text('Dívidas'))),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
                          InkWell(onTap: _currentMonth, child: Text(DateFormat('MMMM yyyy', 'pt_BR').format(_selectedMonth).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                          IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryCard(
                        realBalance: realAccountBalance,
                        saldoPrevisto: saldoPrevisto,
                        resultadoRealizado: resultadoRealizado,
                        receitas: receitasPrevistas,
                        despesas: despesasPrevistas,
                        despesasVencidas: despesasVencidas,
                        debtSnapshot: debtSnapshot,
                      ),
                      const SizedBox(height: 16),
                      _buildDebtBridgeCard(debtSnapshot),
                      const SizedBox(height: 16),
                      _buildAnalysisSection(
                        previousResult: previousResult,
                        resultDiff: resultDiff,
                        expenseDiff: expenseDiff,
                        paidExpenseRatio: paidExpenseRatio,
                        topCategoryName: topCategory?.name ?? (topCategoryEntry == null ? 'Sem gastos pagos' : 'Sem categoria'),
                        topCategoryAmount: topCategoryEntry?.value ?? 0,
                        paidExpenses: despesasPagas,
                        paidIncomes: receitasPagas,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Buscar título, categoria, dívida, credor ou observação...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 16),
                      _buildTypeFilters(),
                      const SizedBox(height: 8),
                      _buildStatusFilters(),
                      if (allCategories.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildCategoryFilters(allCategories),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Movimentações', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          Text('${filtered.length} item(ns)', style: TextStyle(color: Colors.grey.shade700)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              filtered.isEmpty
                  ? SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('Nenhuma movimentação para o período e filtros atuais.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)))))
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildTransactionTile(filtered[index], allCategories, allDebts),
                        childCount: filtered.length,
                      ),
                    ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _openTransactionForm(), child: const Icon(Icons.add)),
    );
  }

  Widget _buildTypeFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('Todos', 'all', _filterType, (v) => setState(() => _filterType = v)),
          _gap(),
          _filterChip('Receitas', 'income', _filterType, (v) => setState(() => _filterType = v)),
          _gap(),
          _filterChip('Despesas', 'expense', _filterType, (v) => setState(() => _filterType = v)),
          _gap(),
          _filterChip('Dívidas', 'debt', _filterType, (v) => setState(() => _filterType = v)),
        ],
      ),
    );
  }

  Widget _buildStatusFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('Tudo', 'all', _filterStatus, (v) => setState(() => _filterStatus = v)),
          _gap(),
          _filterChip('Pago', 'paid', _filterStatus, (v) => setState(() => _filterStatus = v)),
          _gap(),
          _filterChip('Pendente', 'pending', _filterStatus, (v) => setState(() => _filterStatus = v)),
          _gap(),
          _filterChip('Atrasado', 'overdue', _filterStatus, (v) => setState(() => _filterStatus = v)),
        ],
      ),
    );
  }

  Widget _buildCategoryFilters(List<FinancialCategory> categories) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(label: const Text('Todas as categorias'), selected: _filterCategory == null, onSelected: (_) => setState(() => _filterCategory = null)),
          const SizedBox(width: 8),
          ...categories.map((category) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(label: Text(category.name), selected: _filterCategory == category.id, onSelected: (selected) => setState(() => _filterCategory = selected ? category.id : null)),
              )),
        ],
      ),
    );
  }

  Widget _gap() => const SizedBox(width: 8);

  Widget _filterChip(String label, String value, String groupValue, ValueChanged<String> onSelect) {
    return ChoiceChip(label: Text(label), selected: groupValue == value, onSelected: (selected) { if (selected) onSelect(value); });
  }

  Widget _buildSummaryCard({required double realBalance, required double saldoPrevisto, required double resultadoRealizado, required double receitas, required double despesas, required int despesasVencidas, required FinanceDebtSnapshot debtSnapshot}) {
    final hasAlert = despesasVencidas > 0 || debtSnapshot.hasOverdueInstallments;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _summaryValue('Saldo real em contas', realBalance, realBalance >= 0 ? Colors.green : Colors.red, big: true)),
                const SizedBox(width: 12),
                Expanded(child: _summaryValue('Resultado do mês', resultadoRealizado, resultadoRealizado >= 0 ? Colors.green : Colors.red)),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                _stat('Previsto mês', saldoPrevisto, saldoPrevisto >= 0 ? Colors.green : Colors.red),
                _stat('Receitas previstas', receitas, Colors.green),
                _stat('Despesas previstas', despesas, Colors.red),
                _stat('Dívidas restantes', debtSnapshot.totalRemaining, Colors.deepOrange),
                _stat('Parcelas do mês', debtSnapshot.dueInMonth, Colors.orange),
              ],
            ),
            if (hasAlert) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text('${despesasVencidas > 0 ? '$despesasVencidas despesa(s) vencida(s)' : ''}${despesasVencidas > 0 && debtSnapshot.hasOverdueInstallments ? ' • ' : ''}${debtSnapshot.hasOverdueInstallments ? '${debtSnapshot.overdueInstallments} parcela(s) de dívida em atraso' : ''}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDebtBridgeCard(FinanceDebtSnapshot snapshot) {
    return Card(
      color: Colors.deepOrange.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.money_off, color: Colors.deepOrange),
                const SizedBox(width: 8),
                const Expanded(child: Text('Dívidas dentro das Finanças', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                TextButton(onPressed: _openDebts, child: const Text('Abrir')),
              ],
            ),
            const SizedBox(height: 8),
            Text(snapshot.hasOpenDebts ? '${snapshot.openDebtCount} dívida(s) aberta(s), com ${_money(snapshot.totalRemaining)} restante(s).' : 'Nenhuma dívida aberta no momento.'),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _analysisChip(Icons.event_available, 'A vencer no mês: ${_money(snapshot.dueInMonth)}', Colors.orange),
                _analysisChip(Icons.check_circle_outline, 'Abatido no mês: ${_money(snapshot.paidInMonth)}', Colors.green),
                _analysisChip(Icons.warning_amber, 'Em atraso: ${_money(snapshot.overdueAmount)}', snapshot.overdueAmount > 0 ? Colors.red : Colors.grey),
                if (snapshot.nextDueDate != null) _analysisChip(Icons.today, 'Próximo venc.: ${DateFormat('dd/MM/yyyy').format(snapshot.nextDueDate!)}', Colors.deepOrange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(FinancialTransaction transaction, List<FinancialCategory> categories, List<Debt> debts) {
    final isPaid = transaction.status == 'paid';
    final isCanceled = transaction.status == 'canceled';
    final category = _categoryOf(categories, transaction.categoryId);
    final debt = _debtOf(debts, transaction.debtId);
    final color = _transactionColor(transaction, category);
    final expected = _expectedDate(transaction);
    final subtitleParts = <String>[
      expected == null ? 'Sem data' : 'Venc./Prev.: ${DateFormat('dd/MM/yyyy').format(expected)}',
      if (category != null) category.name,
      if (debt != null) 'Dívida: ${debt.name}',
      if (transaction.installmentNumber != null) 'Parcela ${transaction.installmentNumber}/${transaction.totalInstallments ?? '-'}',
    ];

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isCanceled ? Colors.grey.withOpacity(0.2) : color.withOpacity(0.18),
        child: Icon(transaction.debtId != null ? Icons.money_off : (transaction.type == 'income' ? Icons.arrow_upward : Icons.arrow_downward), color: isCanceled ? Colors.grey : color),
      ),
      title: Text(transaction.title, style: TextStyle(decoration: isCanceled ? TextDecoration.lineThrough : null, color: isCanceled ? Colors.grey : Colors.black87)),
      subtitle: Text(subtitleParts.join(' • '), maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_money(transaction.amount), style: TextStyle(color: isCanceled ? Colors.grey : (transaction.type == 'income' ? Colors.green : Colors.red), fontWeight: FontWeight.bold, decoration: isCanceled ? TextDecoration.lineThrough : null)),
              Text(_statusLabel(transaction.status), style: TextStyle(color: _statusColor(transaction.status), fontSize: 12)),
            ],
          ),
          Checkbox(value: isPaid, onChanged: isCanceled ? null : (value) { if (value != null) _togglePaid(transaction, value); }),
        ],
      ),
      onTap: () => _openTransactionForm(transaction: transaction),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Efetuado';
      case 'overdue':
        return 'Atrasado';
      case 'canceled':
        return 'Cancelado';
      default:
        return 'Pendente';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'overdue':
        return Colors.red;
      case 'canceled':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  Widget _summaryValue(String label, double amount, Color color, {bool big = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Text(_money(amount), style: TextStyle(fontSize: big ? 21 : 17, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildAnalysisSection({required double previousResult, required double resultDiff, required double expenseDiff, required double paidExpenseRatio, required String topCategoryName, required double topCategoryAmount, required double paidExpenses, required double paidIncomes}) {
    final economyRate = paidIncomes <= 0 ? 0.0 : ((paidIncomes - paidExpenses) / paidIncomes) * 100;
    final resultLabel = resultDiff >= 0 ? 'Melhor que mês anterior' : 'Pior que mês anterior';
    final expenseLabel = expenseDiff <= 0 ? 'Gastos menores' : 'Gastos maiores';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Análise de gastos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: paidExpenseRatio),
            const SizedBox(height: 6),
            Text('Despesas pagas representam ${(paidExpenseRatio * 100).toStringAsFixed(0)}% das despesas previstas.'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _analysisChip(Icons.compare_arrows, '$resultLabel: ${_money(resultDiff.abs())}', resultDiff >= 0 ? Colors.green : Colors.red),
                _analysisChip(Icons.trending_up, '$expenseLabel: ${_money(expenseDiff.abs())}', expenseDiff <= 0 ? Colors.green : Colors.orange),
                _analysisChip(Icons.pie_chart, 'Maior gasto: $topCategoryName — ${_money(topCategoryAmount)}', Colors.blue),
                _analysisChip(Icons.savings, 'Taxa de sobra: ${economyRate.toStringAsFixed(1)}%', economyRate >= 0 ? Colors.green : Colors.red),
              ],
            ),
            if (previousResult != 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Resultado mês anterior: ${_money(previousResult)}', style: TextStyle(color: Colors.grey.shade700))),
          ],
        ),
      ),
    );
  }

  Widget _analysisChip(IconData icon, String label, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: color.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _stat(String label, double amount, Color color) {
    return SizedBox(
      width: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(_money(amount), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
