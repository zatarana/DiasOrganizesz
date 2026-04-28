import 'dart:io';

String _asDartSource(String text) => text.replaceAll(r'\n', '\n');

void main() {
  final file = File('lib/features/finance/finance_screen.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }

  var text = file.readAsStringSync();

  text = text.replaceFirst(
    RegExp(r"String _money\(num value\) => 'R\\\$ \$\{value\.toDouble\(\)\.toStringAsFixed\(2\)\}';"),
    "String _money(num value) => NumberFormat.currency(locale: 'pt_BR', symbol: 'R\\\$', decimalDigits: 2).format(value);",
  );

  if (!text.contains('Future<double>? _realAccountBalanceFuture;')) {
    text = text.replaceFirst(
      '  final TextEditingController _searchController = TextEditingController();',
      '  final TextEditingController _searchController = TextEditingController();\n  Future<double>? _realAccountBalanceFuture;',
    );
  }

  text = text.replaceAll('if (mounted) setState(() {});', 'if (mounted) _refreshScreen();');
  text = text.replaceAll('    setState(() {});\n  }\n\n  double _paidIncomeForMonth', '    _refreshScreen();\n  }\n\n  double _paidIncomeForMonth');

  if (!text.contains('void _refreshRealAccountBalance()')) {
    text = text.replaceFirst(
      '  @override\n  void dispose() {',
      '  @override\n'
      '  void initState() {\n'
      '    super.initState();\n'
      '    _refreshRealAccountBalance();\n'
      '  }\n\n'
      '  void _refreshRealAccountBalance() {\n'
      '    _realAccountBalanceFuture = _loadRealAccountBalance();\n'
      '  }\n\n'
      '  void _refreshScreen() {\n'
      '    _refreshRealAccountBalance();\n'
      '    setState(() {});\n'
      '  }\n\n'
      '  @override\n'
      '  void dispose() {',
    );
  }

  text = text.replaceAll('future: _loadRealAccountBalance(),', 'future: _realAccountBalanceFuture,');

  text = text.replaceAll(
    '''        actions: [
          IconButton(icon: const Icon(Icons.savings_outlined), onPressed: _openPlanning, tooltip: 'Contas, orçamentos e metas'),
          IconButton(icon: const Icon(Icons.money_off), onPressed: _openDebts, tooltip: 'Dívidas'),
          IconButton(icon: const Icon(Icons.auto_mode), onPressed: _generateFixedTransactions, tooltip: 'Gerar recorrentes'),
          IconButton(icon: const Icon(Icons.category), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceCategoriesScreen())), tooltip: 'Categorias'),
        ],
''',
    '''        actions: [
          IconButton(icon: const Icon(Icons.savings_outlined), onPressed: _openPlanning, tooltip: 'Contas e metas'),
          IconButton(icon: const Icon(Icons.payments_outlined), onPressed: _openDebts, tooltip: 'Dívidas'),
          PopupMenuButton<String>(
            tooltip: 'Mais ações',
            onSelected: (value) async {
              switch (value) {
                case 'recurring':
                  await _generateFixedTransactions();
                  break;
                case 'categories':
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceCategoriesScreen()));
                  if (mounted) _refreshScreen();
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'recurring', child: ListTile(leading: Icon(Icons.auto_mode), title: Text('Gerar recorrentes'))),
              PopupMenuItem(value: 'categories', child: ListTile(leading: Icon(Icons.category), title: Text('Categorias'))),
            ],
          ),
        ],
''',
  );

  text = text.replaceAll(
    '''                      Row(
                        children: [
                          Expanded(child: ElevatedButton.icon(onPressed: _openPlanning, icon: const Icon(Icons.account_balance_wallet_outlined), label: const Text('Contas e metas'))),
                          const SizedBox(width: 8),
                          Expanded(child: OutlinedButton.icon(onPressed: _openDebts, icon: const Icon(Icons.money_off), label: const Text('Dívidas'))),
                        ],
                      ),
                      const SizedBox(height: 12),
''',
    '',
  );

  text = text.replaceAll('Icons.money_off', 'Icons.payments_outlined');
  text = text.replaceAll('withOpacity(0.08)', 'withValues(alpha: 0.08)');
  text = text.replaceAll('withOpacity(0.10)', 'withValues(alpha: 0.10)');
  text = text.replaceAll('withOpacity(0.18)', 'withValues(alpha: 0.18)');
  text = text.replaceAll('withOpacity(0.2)', 'withValues(alpha: 0.2)');

  text = text.replaceAll(
    '''    final paidExpenseRatio = despesasPrevistas <= 0 ? 0.0 : (despesasPagas / despesasPrevistas).clamp(0.0, 1.0).toDouble();
    final categoryTotals = _paidExpensesByCategory(allTransactions, _selectedMonth).entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topCategoryEntry = categoryTotals.isEmpty ? null : categoryTotals.first;
    final topCategory = topCategoryEntry == null ? null : _categoryOf(allCategories, topCategoryEntry.key);
''',
    '''    final visibleReceitasPagas = filtered.where((t) => t.status == 'paid' && t.type == 'income').fold<double>(0, (sum, t) => sum + t.amount);
    final visibleDespesasPagas = filtered.where((t) => t.status == 'paid' && t.type == 'expense').fold<double>(0, (sum, t) => sum + t.amount);
    final visibleDespesasPrevistas = filtered.where((t) => t.status != 'canceled' && t.type == 'expense').fold<double>(0, (sum, t) => sum + t.amount);
    final paidExpenseRatio = visibleDespesasPrevistas <= 0 ? 0.0 : (visibleDespesasPagas / visibleDespesasPrevistas).clamp(0.0, 1.0).toDouble();
    final visibleCategoryTotals = <int?, double>{};
    for (final transaction in filtered) {
      if (transaction.status != 'paid' || transaction.type != 'expense') continue;
      visibleCategoryTotals[transaction.categoryId] = (visibleCategoryTotals[transaction.categoryId] ?? 0) + transaction.amount;
    }
    final categoryTotals = visibleCategoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topCategoryEntry = categoryTotals.isEmpty ? null : categoryTotals.first;
    final topCategory = topCategoryEntry == null ? null : _categoryOf(allCategories, topCategoryEntry.key);
''',
  );

  text = text.replaceAll('paidExpenses: despesasPagas,\n                        paidIncomes: receitasPagas,', 'paidExpenses: visibleDespesasPagas,\n                        paidIncomes: visibleReceitasPagas,');

  final debtStart = text.indexOf('  Widget _buildDebtBridgeCard(FinanceDebtSnapshot snapshot) {');
  final debtEnd = text.indexOf('  Widget _buildTransactionTile(', debtStart);
  if (debtStart != -1 && debtEnd != -1) {
    const replacement = r'''  Widget _buildDebtBridgeCard(FinanceDebtSnapshot snapshot) {
    final subtitle = snapshot.hasOpenDebts
        ? '${snapshot.openDebtCount} dívida(s) aberta(s) · ${_money(snapshot.dueInMonth)} a vencer neste mês'
        : 'Nenhuma dívida aberta no momento.';

    return Card(
      color: Colors.deepOrange.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: const CircleAvatar(
          backgroundColor: Color(0xFFFFE0B2),
          child: Icon(Icons.payments_outlined, color: Colors.deepOrange),
        ),
        title: const Text('Dívidas', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: _openDebts,
      ),
    );
  }

''';
    text = text.replaceRange(debtStart, debtEnd, _asDartSource(replacement));
  }

  final tileStart = text.indexOf('  Widget _buildTransactionTile(');
  final tileEnd = text.indexOf('  String _statusLabel(', tileStart);
  if (tileStart != -1 && tileEnd != -1) {
    const replacement = r'''  Widget _buildTransactionTile(FinancialTransaction transaction, List<FinancialCategory> categories, List<Debt> debts) {
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

    final tile = ListTile(
      leading: CircleAvatar(
        backgroundColor: isCanceled ? Colors.grey.withValues(alpha: 0.2) : color.withValues(alpha: 0.18),
        child: Icon(transaction.debtId != null ? Icons.payments_outlined : (transaction.type == 'income' ? Icons.arrow_upward : Icons.arrow_downward), color: isCanceled ? Colors.grey : color),
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

    return Dismissible(
      key: ValueKey('finance_transaction_${transaction.id ?? transaction.createdAt}_${transaction.status}'),
      direction: isCanceled || isPaid ? DismissDirection.none : DismissDirection.startToEnd,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        color: Colors.green.withValues(alpha: 0.12),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 8),
            Text('Marcar como pago', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        await _togglePaid(transaction, true);
        return false;
      },
      child: tile,
    );
  }

''';
    text = text.replaceRange(tileStart, tileEnd, _asDartSource(replacement));
  }

  text = text.replaceAll(
    "filtered.isEmpty\n                  ? SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(32), child: Center(child: Text('Nenhuma movimentação para o período e filtros atuais.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)))))",
    "filtered.isEmpty\n                  ? SliverToBoxAdapter(child: _buildEmptyTransactionsState())",
  );

  if (!text.contains('_openFiltersSheet(')) {
    text = text.replaceAll(
      '''                      const SizedBox(height: 16),
                      _buildTypeFilters(),
                      const SizedBox(height: 8),
                      _buildStatusFilters(),
                      if (allCategories.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _buildCategoryFilters(allCategories),
                      ],
''',
      '''                      const SizedBox(height: 16),
                      _buildFilterButton(allCategories),
''',
    );
  }

  if (!text.contains('Widget _buildEmptyTransactionsState()')) {
    const emptyState = r'''  Widget _buildEmptyTransactionsState() {
    final hasFilters = _filterType != 'all' || _filterStatus != 'all' || _filterCategory != null || _searchController.text.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 96),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(
              hasFilters ? 'Nenhuma movimentação encontrada com estes filtros.' : 'Nenhuma movimentação neste mês.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              children: [
                if (hasFilters)
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _filterType = 'all';
                        _filterStatus = 'all';
                        _filterCategory = null;
                        _searchController.clear();
                      });
                    },
                    icon: const Icon(Icons.filter_alt_off),
                    label: const Text('Limpar filtros'),
                  ),
                ElevatedButton.icon(
                  onPressed: () => _openTransactionForm(),
                  icon: const Icon(Icons.add),
                  label: const Text('Nova movimentação'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

''';
    text = text.replaceFirst('  Widget _buildTypeFilters() {', _asDartSource(emptyState) + '  Widget _buildTypeFilters() {');
  }

  if (!text.contains('Widget _buildFilterButton(')) {
    const filterSheet = r'''  Widget _buildFilterButton(List<FinancialCategory> categories) {
    final activeCount = (_filterType != 'all' ? 1 : 0) + (_filterStatus != 'all' ? 1 : 0) + (_filterCategory != null ? 1 : 0);
    final label = activeCount == 0 ? 'Filtros' : 'Filtros ($activeCount ativo${activeCount == 1 ? '' : 's'})';
    return OutlinedButton.icon(
      onPressed: () => _openFiltersSheet(categories),
      icon: const Icon(Icons.tune),
      label: Text(label),
    );
  }

  void _openFiltersSheet(List<FinancialCategory> categories) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget chip(String label, bool selected, VoidCallback onTap) {
              return ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) {
                  onTap();
                  setModalState(() {});
                },
              );
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Text('Filtrar movimentações', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _filterType = 'all';
                                _filterStatus = 'all';
                                _filterCategory = null;
                              });
                              setModalState(() {});
                            },
                            child: const Text('Limpar'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text('Tipo', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          chip('Todos', _filterType == 'all', () => setState(() => _filterType = 'all')),
                          chip('Receitas', _filterType == 'income', () => setState(() => _filterType = 'income')),
                          chip('Despesas', _filterType == 'expense', () => setState(() => _filterType = 'expense')),
                          chip('Dívidas', _filterType == 'debt', () => setState(() => _filterType = 'debt')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text('Status', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          chip('Tudo', _filterStatus == 'all', () => setState(() => _filterStatus = 'all')),
                          chip('Pago', _filterStatus == 'paid', () => setState(() => _filterStatus = 'paid')),
                          chip('Pendente', _filterStatus == 'pending', () => setState(() => _filterStatus = 'pending')),
                          chip('Atrasado', _filterStatus == 'overdue', () => setState(() => _filterStatus = 'overdue')),
                        ],
                      ),
                      if (categories.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text('Categoria', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            chip('Todas', _filterCategory == null, () => setState(() => _filterCategory = null)),
                            ...categories.map((category) => chip(category.name, _filterCategory == category.id, () => setState(() => _filterCategory = category.id))),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          child: const Text('Aplicar filtros'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

''';
    text = text.replaceFirst('  Widget _buildTypeFilters() {', _asDartSource(filterSheet) + '  Widget _buildTypeFilters() {');
  }

  text = text.replaceAll(RegExp(r"'R\\\$ \$\{transaction\.amount\.toStringAsFixed\(2\)\}'"), "_money(transaction.amount)");
  text = text.replaceAll(RegExp(r"'R\\\$ \$\{amount\.toStringAsFixed\(2\)\}'"), "_money(amount)");
  text = text.replaceAll(RegExp(r"'R\\\$ \$\{resultDiff\.abs\(\)\.toStringAsFixed\(2\)\}'"), "_money(resultDiff.abs())");
  text = text.replaceAll(RegExp(r"'R\\\$ \$\{expenseDiff\.abs\(\)\.toStringAsFixed\(2\)\}'"), "_money(expenseDiff.abs())");
  text = text.replaceAll(RegExp(r"'R\\\$ \$\{topCategoryAmount\.toStringAsFixed\(2\)\}'"), "_money(topCategoryAmount)");
  text = text.replaceAll(RegExp(r"'R\\\$ \$\{previousResult\.toStringAsFixed\(2\)\}'"), "_money(previousResult)");

  file.writeAsStringSync(text);
  stdout.writeln('finance_screen.dart UX patch aplicado.');
}
