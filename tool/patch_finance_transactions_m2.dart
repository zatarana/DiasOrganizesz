import 'dart:io';

String _asSource(String text) => text.replaceAll(r'\n', '\n');

void main() {
  final file = File('lib/features/finance/finance_screen.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }

  var text = file.readAsStringSync();

  final tileStart = text.indexOf('  Widget _buildTransactionTile(');
  final tileEnd = text.indexOf('  String _statusLabel(', tileStart);
  if (tileStart == -1 || tileEnd == -1) {
    stderr.writeln('ERRO F-M2: não foi possível localizar _buildTransactionTile.');
    exit(1);
  }
  text = text.replaceRange(tileStart, tileEnd, _asSource(_transactionTileSource));

  final emptyStart = text.indexOf('  Widget _buildEmptyTransactionsState() {');
  if (emptyStart == -1) {
    stderr.writeln('ERRO F-M2: _buildEmptyTransactionsState não existe. Rode patch_finance_screen_ux antes.');
    exit(1);
  }
  final emptyEnd = _findWidgetMethodEnd(text, emptyStart);
  if (emptyEnd == -1) {
    stderr.writeln('ERRO F-M2: não foi possível localizar o fim de _buildEmptyTransactionsState.');
    exit(1);
  }
  text = text.replaceRange(emptyStart, emptyEnd, _asSource(_emptyStateSource));

  final checks = <String>[
    '_confirmDeleteTransaction',
    '_buildSwipeActionBackground',
    'Editar movimentação',
    'Excluir movimentação',
    'Quer excluir esta movimentação?',
    'Nenhuma movimentação por aqui',
    'Nova movimentação',
    'Limpar filtros',
    'secondaryBackground:',
    'DismissDirection.horizontal',
  ];
  for (final check in checks) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO F-M2: patch incompleto. Faltou: $check');
      exit(1);
    }
  }

  file.writeAsStringSync(text);
  stdout.writeln('F-M2 aplicado: swipe editar/excluir com feedback e empty state elegante.');
}

int _findWidgetMethodEnd(String text, int start) {
  final firstBrace = text.indexOf('{', start);
  if (firstBrace == -1) return -1;
  var depth = 0;
  for (var i = firstBrace; i < text.length; i++) {
    final char = text[i];
    if (char == '{') depth++;
    if (char == '}') {
      depth--;
      if (depth == 0) return i + 1;
    }
  }
  return -1;
}

const _transactionTileSource = r'''  Future<void> _confirmDeleteTransaction(FinancialTransaction transaction) async {
    if (transaction.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quer excluir esta movimentação?'),
        content: Text('"${transaction.title}" será removida definitivamente da lista financeira.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(transactionsProvider.notifier).removeTransaction(transaction.id!);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${transaction.title}" excluída.')));
    _refreshScreen();
  }

  Widget _buildSwipeActionBackground({required IconData icon, required String label, required Color color, required Alignment alignment}) {
    final isLeft = alignment == Alignment.centerLeft;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 22),
      alignment: alignment,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisAlignment: isLeft ? MainAxisAlignment.start : MainAxisAlignment.end,
        children: [
          if (!isLeft) Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          if (!isLeft) const SizedBox(width: 10),
          CircleAvatar(backgroundColor: color.withValues(alpha: 0.16), child: Icon(icon, color: color)),
          if (isLeft) const SizedBox(width: 10),
          if (isLeft) Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        ],
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

    final tile = Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isCanceled ? Colors.grey.withValues(alpha: 0.2) : color.withValues(alpha: 0.18),
          child: Icon(transaction.debtId != null ? Icons.payments_outlined : (transaction.type == 'income' ? Icons.arrow_upward : Icons.arrow_downward), color: isCanceled ? Colors.grey : color),
        ),
        title: Text(transaction.title, style: TextStyle(decoration: isCanceled ? TextDecoration.lineThrough : null, color: isCanceled ? Colors.grey : Colors.black87, fontWeight: FontWeight.w600)),
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
      ),
    );

    return Dismissible(
      key: ValueKey('finance_transaction_${transaction.id ?? transaction.createdAt}_${transaction.status}'),
      direction: DismissDirection.horizontal,
      background: _buildSwipeActionBackground(
        icon: Icons.edit_outlined,
        label: 'Editar movimentação',
        color: Colors.blue,
        alignment: Alignment.centerLeft,
      ),
      secondaryBackground: _buildSwipeActionBackground(
        icon: Icons.delete_outline,
        label: 'Excluir movimentação',
        color: Colors.red,
        alignment: Alignment.centerRight,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          await _openTransactionForm(transaction: transaction);
          return false;
        }
        await _confirmDeleteTransaction(transaction);
        return false;
      },
      child: tile,
    );
  }

''';

const _emptyStateSource = r'''  Widget _buildEmptyTransactionsState() {
    final hasFilters = _filterType != 'all' || _filterStatus != 'all' || _filterCategory != null || _searchController.text.trim().isNotEmpty;
    final monthLabel = DateFormat('MMMM yyyy', 'pt_BR').format(_selectedMonth);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 104),
      child: Center(
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(hasFilters ? Icons.manage_search_outlined : Icons.receipt_long_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 16),
                Text(
                  hasFilters ? 'Nenhuma movimentação encontrada' : 'Nenhuma movimentação por aqui',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  hasFilters
                      ? 'Os filtros atuais não retornaram lançamentos. Limpe os filtros ou ajuste a busca para ver mais resultados.'
                      : 'Ainda não há receitas, despesas ou parcelas registradas em ${monthLabel[0].toUpperCase()}${monthLabel.substring(1)}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                ),
                const SizedBox(height: 18),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
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
                    FilledButton.icon(
                      onPressed: () => _openTransactionForm(),
                      icon: const Icon(Icons.add),
                      label: const Text('Nova movimentação'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Dica: deslize uma movimentação para a direita para editar ou para a esquerda para excluir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
''';
