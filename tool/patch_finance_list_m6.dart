import 'dart:io';

void main() {
  final file = File('lib/features/finance/finance_screen.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }

  var text = file.readAsStringSync();

  if (!text.contains("import 'package:flutter_slidable/flutter_slidable.dart';")) {
    text = text.replaceFirst(
      "import 'package:flutter_riverpod/flutter_riverpod.dart';\n",
      "import 'package:flutter_riverpod/flutter_riverpod.dart';\nimport 'package:flutter_slidable/flutter_slidable.dart';\n",
    );
  }

  text = _insertQuickFilters(text);
  text = _replaceTransactionTile(text);

  final checks = <String>[
    "import 'package:flutter_slidable/flutter_slidable.dart';",
    '_buildQuickFilterBar',
    'Slidable(',
    'ActionPane(',
    'SlidableAction(',
    "label: 'Pagar'",
    "label: 'Desmarcar'",
    "label: 'Editar'",
    "label: 'Excluir'",
    'DrawerMotion()',
    'showQuickTransactionBottomSheet(context)',
  ];

  for (final check in checks) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO Etapa 6: lista financeira incompleta. Faltou: $check');
      exit(1);
    }
  }

  if (text.contains('Dismissible(') || text.contains('DismissDirection.horizontal')) {
    stderr.writeln('ERRO Etapa 6: Dismissible antigo ainda aparece na lista financeira.');
    exit(1);
  }

  file.writeAsStringSync(text);
  stdout.writeln('Etapa 6 aplicada: FinanceScreen com filtros rápidos e Slidable.');
}

String _insertQuickFilters(String text) {
  if (text.contains('Widget _buildQuickFilterBar()')) return text;

  text = text.replaceFirst(
    "                      TextField(\n",
    "                      _buildQuickFilterBar(),\n                      const SizedBox(height: 12),\n                      TextField(\n",
  );

  final marker = '  Widget _gap() => const SizedBox(width: 8);';
  final index = text.indexOf(marker);
  if (index == -1) {
    stderr.writeln('ERRO Etapa 6: marcador para filtros rápidos não encontrado.');
    exit(1);
  }

  return text.replaceRange(index, index, r'''
  Widget _buildQuickFilterBar() {
    final chips = <Widget>[
      _quickFilterChip('Todas', Icons.all_inbox, 'all', 'all'),
      _quickFilterChip('Receitas', Icons.arrow_upward, 'income', 'all'),
      _quickFilterChip('Despesas', Icons.arrow_downward, 'expense', 'all'),
      _quickFilterChip('Pagas', Icons.check_circle_outline, 'all', 'paid'),
      _quickFilterChip('Pendentes', Icons.schedule, 'all', 'pending'),
      _quickFilterChip('Atrasadas', Icons.warning_amber_outlined, 'all', 'overdue'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(child: Text('Filtros rápidos', style: TextStyle(fontWeight: FontWeight.bold))),
            TextButton.icon(
              onPressed: () => setState(() {
                _filterType = 'all';
                _filterStatus = 'all';
                _filterCategory = null;
                _searchController.clear();
              }),
              icon: const Icon(Icons.filter_alt_off, size: 18),
              label: const Text('Limpar'),
            ),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: chips),
        ),
      ],
    );
  }

  Widget _quickFilterChip(String label, IconData icon, String type, String status) {
    final selected = _filterType == type && _filterStatus == status && _filterCategory == null;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() {
          _filterType = type;
          _filterStatus = status;
          _filterCategory = null;
        }),
      ),
    );
  }

''');
}

String _replaceTransactionTile(String text) {
  final start = text.indexOf('  Future<void> _confirmDeleteTransaction(');
  final end = text.indexOf('  String _statusLabel(', start);
  if (start == -1 || end == -1) {
    stderr.writeln('ERRO Etapa 6: bloco de transação não encontrado. Rode F-M2 antes.');
    exit(1);
  }
  return text.replaceRange(start, end, _transactionBlock);
}

const _transactionBlock = r'''  Future<void> _confirmDeleteTransaction(FinancialTransaction transaction) async {
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
    setState(() {});
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
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_money(transaction.amount), style: TextStyle(color: isCanceled ? Colors.grey : (transaction.type == 'income' ? Colors.green : Colors.red), fontWeight: FontWeight.bold, decoration: isCanceled ? TextDecoration.lineThrough : null)),
            Text(_statusLabel(transaction.status), style: TextStyle(color: _statusColor(transaction.status), fontSize: 12)),
          ],
        ),
        onTap: () => _openTransactionForm(transaction: transaction),
      ),
    );

    return Slidable(
      key: ValueKey('finance_slidable_${transaction.id ?? transaction.createdAt}_${transaction.status}'),
      startActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.34,
        children: [
          SlidableAction(
            onPressed: isCanceled ? null : (_) => _togglePaid(transaction, !isPaid),
            backgroundColor: isPaid ? Colors.orange : Colors.green,
            foregroundColor: Colors.white,
            icon: isPaid ? Icons.undo : Icons.check,
            label: isPaid ? 'Desmarcar' : 'Pagar',
            borderRadius: BorderRadius.circular(16),
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.58,
        children: [
          SlidableAction(
            onPressed: (_) => _openTransactionForm(transaction: transaction),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            icon: Icons.edit_outlined,
            label: 'Editar',
            borderRadius: BorderRadius.circular(16),
          ),
          SlidableAction(
            onPressed: (_) => _confirmDeleteTransaction(transaction),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Excluir',
            borderRadius: BorderRadius.circular(16),
          ),
        ],
      ),
      child: tile,
    );
  }

''';
