import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/finance_planning_store.dart';
import '../../domain/providers.dart';
import '../../data/models/financial_category_model.dart';
import '../../data/models/transaction_model.dart';
import 'create_transaction_screen.dart';
import 'finance_categories_screen.dart';
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

  Future<void> _openPlanning() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const FinancePlanningScreen()));
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

  FinancialCategory? _findCategory(List<FinancialCategory> categories, int? categoryId) {
    if (categoryId == null) return null;
    for (final category in categories) {
      if (category.id == categoryId) return category;
    }
    return null;
  }

  Color _safeCategoryColor(FinancialCategory? category, FinancialTransaction transaction) {
    if (category == null) return transaction.type == 'income' ? Colors.green : Colors.red;
    return Color(int.tryParse(category.color) ?? (transaction.type == 'income' ? 0xFF4CAF50 : 0xFFF44336));
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
    return existing.title == source.title && existing.type == source.type && existing.categoryId == source.categoryId && existing.amount.toStringAsFixed(2) == source.amount.toStringAsFixed(2);
  }

  Future<void> _generateFixedTransactions() async {
    final allTransactions = ref.read(transactionsProvider);
    final accounts = await FinancePlanningStore.getAccounts(await ref.read(dbProvider).database);
    final activeAccountIds = accounts.where((account) => !account.isArchived && account.id != null).map((account) => account.id!).toSet();
    final previousMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);

    final previousFixed = allTransactions.where((transaction) {
      final expected = _expectedDate(transaction);
      return expected != null && expected.month == previousMonth.month && expected.year == previousMonth.year && transaction.isFixed && transaction.recurrenceType == 'monthly' && transaction.status != 'canceled';
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
      final newTransaction = FinancialTransaction(title: source.title, description: source.description, amount: source.amount, type: source.type, transactionDate: newTransactionDate.toIso8601String(), dueDate: newDueDate?.toIso8601String(), paidDate: null, categoryId: source.categoryId, accountId: copiedAccountId, paymentMethod: source.paymentMethod, status: 'pending', reminderEnabled: source.reminderEnabled, isFixed: true, recurrenceType: 'monthly', notes: source.notes, createdAt: now, updatedAt: now);
      await ref.read(transactionsProvider.notifier).addTransaction(newTransaction);
      added++;
    }

    if (!mounted) return;
    if (added > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$added lançamento(s) fixo(s) gerado(s). ${skipped > 0 ? '$skipped duplicado(s) ignorado(s).' : ''}${accountCleared > 0 ? ' $accountCleared conta(s) arquivada(s) removida(s).' : ''}')));
    } else if (skipped > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nenhum lançamento novo. $skipped recorrente(s) já existiam neste mês.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum lançamento fixo encontrado no mês anterior.')));
    }
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

    final updated = transaction.copyWith(status: isPaid ? 'paid' : _statusAfterUnpay(transaction), paidDate: isPaid ? DateTime.now().toIso8601String() : null, clearPaidDate: !isPaid, updatedAt: DateTime.now().toIso8601String());
    await ref.read(transactionsProvider.notifier).updateTransaction(updated);
    setState(() {});
  }

  double _paidIncomeForMonth(List<FinancialTransaction> transactions, DateTime month) {
    return transactions.where((t) => t.status == 'paid' && t.type == 'income' && (_isSameMonth(_paidDate(t), month) || (_paidDate(t) == null && _isSameMonth(_expectedDate(t), month)))).fold<double>(0, (sum, t) => sum + t.amount);
  }

  double _paidExpenseForMonth(List<FinancialTransaction> transactions, DateTime month) {
    return transactions.where((t) => t.status == 'paid' && t.type == 'expense' && (_isSameMonth(_paidDate(t), month) || (_paidDate(t) == null && _isSameMonth(_expectedDate(t), month)))).fold<double>(0, (sum, t) => sum + t.amount);
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

  @override
  Widget build(BuildContext context) {
    final allTransactions = ref.watch(transactionsProvider);
    final allCategories = ref.watch(financialCategoriesProvider);

    final filtered = allTransactions.where((transaction) {
      if (transaction.status == 'canceled' && _filterStatus != 'all') return false;
      if (!_belongsToSelectedMonth(transaction)) return false;
      if (_filterType != 'all' && transaction.type != _filterType) return false;
      if (_filterStatus == 'paid' && transaction.status != 'paid') return false;
      if (_filterStatus == 'pending' && transaction.status != 'pending') return false;
      if (_filterStatus == 'overdue' && transaction.status != 'overdue') return false;
      if (_filterCategory != null && transaction.categoryId != _filterCategory) return false;
      if (_searchController.text.trim().isNotEmpty && !transaction.title.toLowerCase().contains(_searchController.text.trim().toLowerCase())) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final ad = _expectedDate(a) ?? DateTime(2100);
        final bd = _expectedDate(b) ?? DateTime(2100);
        return ad.compareTo(bd);
      });

    double receitasPrevistas = 0;
    double despesasPrevistas = 0;
    double receitasPagas = 0;
    double despesasPagas = 0;
    int qtdeDespesasVencidas = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (final transaction in allTransactions) {
      if (transaction.status == 'canceled') continue;
      final expected = _expectedDate(transaction);
      final paid = _paidDate(transaction);
      final expectedInMonth = _isSameMonth(expected, _selectedMonth);
      final paidInMonth = transaction.status == 'paid' && (_isSameMonth(paid, _selectedMonth) || (paid == null && expectedInMonth));

      if (expectedInMonth) {
        if (transaction.type == 'income') {
          receitasPrevistas += transaction.amount;
        } else if (transaction.type == 'expense') {
          despesasPrevistas += transaction.amount;
          final dueDate = expected == null ? null : DateTime(expected.year, expected.month, expected.day);
          if ((transaction.status == 'pending' || transaction.status == 'overdue') && dueDate != null && dueDate.isBefore(today)) qtdeDespesasVencidas++;
        }
      }

      if (paidInMonth) {
        if (transaction.type == 'income') {
          receitasPagas += transaction.amount;
        } else if (transaction.type == 'expense') {
          despesasPagas += transaction.amount;
        }
      }
    }

    final saldoPrevisto = receitasPrevistas - despesasPrevistas;
    final resultadoRealizado = receitasPagas - despesasPagas;
    final previousMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    final previousIncome = _paidIncomeForMonth(allTransactions, previousMonth);
    final previousExpense = _paidExpenseForMonth(allTransactions, previousMonth);
    final previousResult = previousIncome - previousExpense;
    final resultDiff = resultadoRealizado - previousResult;
    final expenseDiff = despesasPagas - previousExpense;
    final paidExpenseRatio = despesasPrevistas <= 0 ? 0.0 : (despesasPagas / despesasPrevistas).clamp(0.0, 1.0).toDouble();
    final categoryTotals = _paidExpensesByCategory(allTransactions, _selectedMonth);
    final sortedCategories = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topCategoryEntry = sortedCategories.isEmpty ? null : sortedCategories.first;
    final topCategory = topCategoryEntry == null ? null : _findCategory(allCategories, topCategoryEntry.key);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanças'),
        actions: [
          IconButton(icon: const Icon(Icons.savings_outlined), onPressed: _openPlanning, tooltip: 'Contas, orçamentos e metas'),
          IconButton(icon: const Icon(Icons.auto_mode), onPressed: _generateFixedTransactions, tooltip: 'Gerar Recorrentes do Mês Anterior'),
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
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(onPressed: _openPlanning, icon: const Icon(Icons.savings_outlined), label: const Text('Contas, Orçamentos e Metas')),
                      const SizedBox(height: 12),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth), Text(DateFormat('MMMM yyyy', 'pt_BR').format(_selectedMonth).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth)]),
                      const SizedBox(height: 8),
                      _buildSummaryCard(realAccountBalance, saldoPrevisto, resultadoRealizado, receitasPrevistas, despesasPrevistas, qtdeDespesasVencidas),
                      const SizedBox(height: 16),
                      _buildAnalysisSection(previousResult: previousResult, resultDiff: resultDiff, expenseDiff: expenseDiff, paidExpenseRatio: paidExpenseRatio, topCategoryName: topCategory?.name ?? (topCategoryEntry == null ? 'Sem gastos pagos' : 'Sem categoria'), topCategoryAmount: topCategoryEntry?.value ?? 0, paidExpenses: despesasPagas, paidIncomes: receitasPagas),
                      const SizedBox(height: 16),
                      TextField(controller: _searchController, decoration: InputDecoration(hintText: 'Buscar movimentação...', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 16)), onChanged: (_) => setState(() {})),
                      const SizedBox(height: 16),
                      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [_buildFilterChip('Todos', 'all', _filterType, (v) => setState(() => _filterType = v)), const SizedBox(width: 8), _buildFilterChip('Receitas', 'income', _filterType, (v) => setState(() => _filterType = v)), const SizedBox(width: 8), _buildFilterChip('Despesas', 'expense', _filterType, (v) => setState(() => _filterType = v)), const SizedBox(width: 16), _buildFilterChip('Tudo', 'all', _filterStatus, (v) => setState(() => _filterStatus = v)), const SizedBox(width: 8), _buildFilterChip('Pago', 'paid', _filterStatus, (v) => setState(() => _filterStatus = v)), const SizedBox(width: 8), _buildFilterChip('Pendente', 'pending', _filterStatus, (v) => setState(() => _filterStatus = v)), const SizedBox(width: 8), _buildFilterChip('Atrasado', 'overdue', _filterStatus, (v) => setState(() => _filterStatus = v))])),
                      if (allCategories.isNotEmpty) ...[const SizedBox(height: 8), SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [ChoiceChip(label: const Text('Todas as Categorias'), selected: _filterCategory == null, onSelected: (_) => setState(() => _filterCategory = null)), const SizedBox(width: 8), ...allCategories.map((c) => Padding(padding: const EdgeInsets.only(right: 8.0), child: ChoiceChip(label: Text(c.name), selected: _filterCategory == c.id, onSelected: (selected) => setState(() => _filterCategory = selected ? c.id : null))))]))],
                      const SizedBox(height: 16),
                      const Text('Movimentações', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              filtered.isEmpty
                  ? SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(32.0), child: Center(child: Text('Nenhuma movimentação para o período e filtros atuais.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)))))
                  : SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final transaction = filtered[index];
                        final isPaid = transaction.status == 'paid';
                        final isCanceled = transaction.status == 'canceled';
                        final cat = _findCategory(allCategories, transaction.categoryId);
                        final color = _safeCategoryColor(cat, transaction);
                        final expected = _expectedDate(transaction);
                        return ListTile(
                          leading: CircleAvatar(backgroundColor: isCanceled ? Colors.grey.withValues(alpha: 0.2) : color.withValues(alpha: 0.2), child: Icon(transaction.type == 'income' ? Icons.arrow_upward : Icons.arrow_downward, color: isCanceled ? Colors.grey : color)),
                          title: Text(transaction.title, style: TextStyle(decoration: isCanceled ? TextDecoration.lineThrough : null, color: isCanceled ? Colors.grey : Colors.black87)),
                          subtitle: Text('${expected == null ? 'Sem data' : 'Venc./Prev.: ${DateFormat('dd/MM/yyyy').format(expected)}'}${cat != null ? ' • ${cat.name}' : ''}'),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [Text('R\$ ${transaction.amount.toStringAsFixed(2)}', style: TextStyle(color: isCanceled ? Colors.grey : (transaction.type == 'income' ? Colors.green : Colors.red), fontWeight: FontWeight.bold, decoration: isCanceled ? TextDecoration.lineThrough : null)), Text(isCanceled ? 'Cancelado' : (transaction.status == 'paid' ? 'Efetuado' : (transaction.status == 'overdue' ? 'Atrasado' : 'Pendente')), style: TextStyle(color: isCanceled ? Colors.grey : (transaction.status == 'paid' ? Colors.green : (transaction.status == 'overdue' ? Colors.red : Colors.orange)), fontSize: 12))]), Checkbox(value: isPaid, onChanged: isCanceled ? null : (val) { if (val != null) _togglePaid(transaction, val); })]),
                          onTap: () => _openTransactionForm(transaction: transaction),
                        );
                      }, childCount: filtered.length),
                    ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _openTransactionForm(), child: const Icon(Icons.add)),
    );
  }

  Widget _buildFilterChip(String label, String value, String groupValue, Function(String) onSelect) => ChoiceChip(label: Text(label), selected: groupValue == value, onSelected: (selected) { if (selected) onSelect(value); });

  Widget _buildSummaryCard(double realBalance, double saldoPrevisto, double resultadoRealizado, double receitas, double despesas, int despesasVencidas) {
    return Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), child: Padding(padding: const EdgeInsets.all(20.0), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: _summaryValue('Saldo real em contas', realBalance, realBalance >= 0 ? Colors.green : Colors.red, big: true)), const SizedBox(width: 12), Expanded(child: _summaryValue('Resultado do mês', resultadoRealizado, resultadoRealizado >= 0 ? Colors.green : Colors.red))]), const SizedBox(height: 16), const Divider(), const SizedBox(height: 16), Wrap(spacing: 16, runSpacing: 12, children: [_buildStat('Previsto mês', saldoPrevisto, saldoPrevisto >= 0 ? Colors.green : Colors.red), _buildStat('Receitas previstas', receitas, Colors.green), _buildStat('Despesas previstas', despesas, Colors.red)]), if (despesasVencidas > 0) ...[const SizedBox(height: 16), Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)), child: Row(children: [const Icon(Icons.warning, color: Colors.red, size: 20), const SizedBox(width: 8), Expanded(child: Text('$despesasVencidas despesa(s) vencida(s)!', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))]))]])));
  }

  Widget _summaryValue(String label, double amount, Color color, {bool big = false}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Text('R\$ ${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: big ? 21 : 17, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis)]);
  }

  Widget _buildAnalysisSection({required double previousResult, required double resultDiff, required double expenseDiff, required double paidExpenseRatio, required String topCategoryName, required double topCategoryAmount, required double paidExpenses, required double paidIncomes}) {
    final economyRate = paidIncomes <= 0 ? 0.0 : ((paidIncomes - paidExpenses) / paidIncomes) * 100;
    final resultLabel = resultDiff >= 0 ? 'Melhor que mês anterior' : 'Pior que mês anterior';
    final expenseLabel = expenseDiff <= 0 ? 'Gastos menores' : 'Gastos maiores';
    return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Análise de gastos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 10), LinearProgressIndicator(value: paidExpenseRatio), const SizedBox(height: 6), Text('Despesas pagas representam ${(paidExpenseRatio * 100).toStringAsFixed(0)}% das despesas previstas.'), const SizedBox(height: 12), Wrap(spacing: 10, runSpacing: 10, children: [_analysisChip(Icons.compare_arrows, '$resultLabel: R\$ ${resultDiff.abs().toStringAsFixed(2)}', resultDiff >= 0 ? Colors.green : Colors.red), _analysisChip(Icons.trending_up, '$expenseLabel: R\$ ${expenseDiff.abs().toStringAsFixed(2)}', expenseDiff <= 0 ? Colors.green : Colors.orange), _analysisChip(Icons.pie_chart, 'Maior gasto: $topCategoryName — R\$ ${topCategoryAmount.toStringAsFixed(2)}', Colors.blue), _analysisChip(Icons.savings, 'Taxa de sobra: ${economyRate.toStringAsFixed(1)}%', economyRate >= 0 ? Colors.green : Colors.red)]), if (previousResult != 0) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Resultado mês anterior: R\$ ${previousResult.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade700)))])));
  }

  Widget _analysisChip(IconData icon, String label, Color color) {
    return Container(constraints: const BoxConstraints(maxWidth: 320), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), decoration: BoxDecoration(color: color.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: color), const SizedBox(width: 6), Flexible(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontWeight: FontWeight.w600)))]));
  }

  Widget _buildStat(String label, double amount, Color color) {
    return SizedBox(width: 140, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Text('R\$ ${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis)]));
  }
}
