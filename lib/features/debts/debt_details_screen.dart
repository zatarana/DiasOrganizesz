import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/providers.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/transaction_model.dart';
import '../finance/create_transaction_screen.dart';
import 'create_debt_screen.dart';

class DebtDetailsScreen extends ConsumerStatefulWidget {
  final Debt debt;

  const DebtDetailsScreen({super.key, required this.debt});

  @override
  ConsumerState<DebtDetailsScreen> createState() => _DebtDetailsScreenState();
}

class _DebtDetailsScreenState extends ConsumerState<DebtDetailsScreen> {
  static const String _defaultAccountSettingKey = 'default_financial_account_id';

  DateTime? _transactionDate(FinancialTransaction transaction) => DateTime.tryParse(transaction.dueDate ?? transaction.transactionDate);

  String _formatDate(String? rawDate) {
    if (rawDate == null) return 'Sem data';
    final date = DateTime.tryParse(rawDate);
    if (date == null) return 'Data inválida';
    return DateFormat('dd/MM/yyyy').format(date);
  }

  String _money(num value) => 'R\$ ${value.toDouble().toStringAsFixed(2)}';

  double _parseMoney(String text) => double.tryParse(text.replaceAll(',', '.')) ?? 0.0;

  double _roundCents(double value) => double.parse(value.toStringAsFixed(2));

  DateTime _safeMonthlyDueDate(DateTime firstDate, int monthOffset) {
    final base = DateTime(firstDate.year, firstDate.month + monthOffset, 1);
    final lastDay = DateUtils.getDaysInMonth(base.year, base.month);
    final day = firstDate.day > lastDay ? lastDay : firstDate.day;
    return DateTime(base.year, base.month, day);
  }

  List<double> _buildInstallmentAmounts(double total, int count, double preferredAmount) {
    if (count <= 0) return const [];
    final amounts = <double>[];
    var accumulated = 0.0;
    final base = preferredAmount > 0 ? preferredAmount : _roundCents(total / count);

    for (var i = 0; i < count; i++) {
      final isLast = i == count - 1;
      final value = isLast ? _roundCents(total - accumulated) : _roundCents(base);
      amounts.add(value < 0 ? 0 : value);
      accumulated += value;
    }

    return amounts;
  }

  Future<int?> _getDefaultAccountId() async {
    final setting = await ref.read(dbProvider).getSetting(_defaultAccountSettingKey);
    return int.tryParse(setting?.value ?? '');
  }

  String _comparisonText(double totalMoneyToPay, double originalTotal) {
    final diff = totalMoneyToPay - originalTotal;
    if (diff.abs() < 0.01) return 'Você pagará exatamente o valor original da dívida.';
    if (diff < 0) return 'Você pagará ${_money(diff.abs())} a menos que o valor original.';
    return 'Você pagará ${_money(diff)} a mais que o valor original.';
  }

  Color _comparisonColor(double totalMoneyToPay, double originalTotal) {
    final diff = totalMoneyToPay - originalTotal;
    if (diff.abs() < 0.01) return Colors.blue;
    return diff < 0 ? Colors.teal : Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final debts = ref.watch(debtsProvider);
    final debtIndex = debts.indexWhere((d) => d.id == widget.debt.id);

    if (debtIndex == -1) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dívida Excluída')),
        body: const Center(child: Text('Esta dívida não existe mais.')),
      );
    }

    final currentDebt = debts[debtIndex];
    final allTransactions = ref.watch(transactionsProvider);
    final installments = allTransactions.where((t) => t.debtId == currentDebt.id && t.status != 'canceled').toList()
      ..sort((a, b) {
        if (a.installmentNumber != null && b.installmentNumber != null) return a.installmentNumber!.compareTo(b.installmentNumber!);
        final ad = _transactionDate(a) ?? DateTime(2100);
        final bd = _transactionDate(b) ?? DateTime(2100);
        return ad.compareTo(bd);
      });

    final paidAmount = installments.where((t) => t.status == 'paid').fold<double>(0, (sum, t) => sum + t.amount);
    final discounts = installments.where((t) => t.status == 'paid').fold<double>(0, (sum, t) => sum + (t.discountAmount ?? 0));
    final abatido = paidAmount + discounts;
    final remaining = (currentDebt.totalAmount - abatido).clamp(0, double.infinity).toDouble();
    final progress = currentDebt.totalAmount > 0 ? (abatido / currentDebt.totalAmount).clamp(0.0, 1.0).toDouble() : 0.0;
    final valueDiff = paidAmount - currentDebt.totalAmount;

    return Scaffold(
      appBar: AppBar(
        title: Text(currentDebt.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'edit') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => CreateDebtScreen(debt: currentDebt)));
              } else if (value == 'pause') {
                await ref.read(debtsProvider.notifier).updateDebt(currentDebt.copyWith(status: currentDebt.status == 'paused' ? 'active' : 'paused', updatedAt: DateTime.now().toIso8601String()));
              } else if (value == 'cancel') {
                await ref.read(debtsProvider.notifier).updateDebt(currentDebt.copyWith(status: currentDebt.status == 'canceled' ? 'active' : 'canceled', updatedAt: DateTime.now().toIso8601String()));
              } else if (value == 'delete') {
                _confirmDelete(currentDebt);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'edit', child: Text('Editar')),
              PopupMenuItem(value: 'pause', child: Text(currentDebt.status == 'paused' ? 'Retomar Dívida' : 'Pausar Dívida')),
              PopupMenuItem(value: 'cancel', child: Text(currentDebt.status == 'canceled' ? 'Reativar Dívida' : 'Cancelar Dívida')),
              const PopupMenuItem(value: 'delete', child: Text('Excluir', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: currentDebt.status == 'canceled' ? null : () => _openManualPayment(currentDebt, remaining, installments.length),
        icon: const Icon(Icons.add),
        label: const Text('Pagamento manual'),
      ),
      body: Column(
        children: [
          _buildHeader(currentDebt, paidAmount, discounts, abatido, remaining, progress, valueDiff),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: currentDebt.status == 'canceled' || currentDebt.status == 'paid' ? null : () => _startPayment(currentDebt, installments),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Iniciar pagamento'),
                ),
                OutlinedButton.icon(
                  onPressed: currentDebt.status == 'canceled' || currentDebt.status == 'paid' ? null : () => _showNegotiationOptions(currentDebt, installments, paidAmount, discounts),
                  icon: const Icon(Icons.handshake_outlined),
                  label: const Text('Negociar dívida'),
                ),
              ],
            ),
          ),
          const Divider(height: 28),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Parcelas e pagamentos (${installments.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: installments.isEmpty
                ? const Center(child: Text('Nenhuma parcela ou pagamento lançado. Use “Iniciar pagamento” para criar os lançamentos no Financeiro.'))
                : ListView.builder(
                    itemCount: installments.length,
                    itemBuilder: (context, index) => _buildInstallmentTile(installments[index]),
                  ),
          )
        ],
      ),
    );
  }

  Widget _buildHeader(Debt debt, double paidAmount, double discounts, double abatido, double remaining, double progress, double valueDiff) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _headerRow('Valor original:', _money(debt.totalAmount), Colors.black87, 20),
          const SizedBox(height: 8),
          _headerRow('Pago em dinheiro:', _money(paidAmount), Colors.green, 16),
          const SizedBox(height: 8),
          _headerRow('Descontos/abatimentos:', _money(discounts), Colors.teal, 16),
          const SizedBox(height: 8),
          _headerRow('Total abatido:', _money(abatido), Colors.blue, 16),
          const SizedBox(height: 8),
          _headerRow('Falta abater:', _money(remaining), Colors.orange, 16),
          if (debt.status == 'paid' || progress >= 1.0) ...[
            const SizedBox(height: 12),
            if (valueDiff < -0.01)
              Text('Quitada pagando ${_money(valueDiff.abs())} a menos que o valor original.', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold))
            else if (valueDiff > 0.01)
              Text('Quitada pagando ${_money(valueDiff)} a mais que o valor original.', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
            else
              const Text('Quitada no valor original!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              backgroundColor: Colors.grey.shade200,
              color: progress >= 1.0 ? Colors.green : Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerRow(String label, String value, Color color, double fontSize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade700))),
        Text(value, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildInstallmentTile(FinancialTransaction transaction) {
    final isPaid = transaction.status == 'paid';
    final isOverdue = _isInstallmentOverdue(transaction);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTransactionScreen(transaction: transaction)));
        },
        leading: Checkbox(
          value: isPaid,
          onChanged: (val) async {
            if (val != null) await _toggleInstallment(transaction, val);
          },
        ),
        title: Text(
          transaction.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            decoration: isPaid ? TextDecoration.lineThrough : null,
            fontWeight: isPaid ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Vencimento: ${_formatDate(transaction.dueDate ?? transaction.transactionDate)}',
              style: TextStyle(color: isOverdue ? Colors.red : null),
            ),
            Text('Status: ${_statusLabel(transaction.status)}', style: const TextStyle(fontSize: 12)),
            if (isPaid && transaction.paidDate != null)
              Text(
                'Pago em: ${_formatDate(transaction.paidDate)}',
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
            if (transaction.discountAmount != null && transaction.discountAmount! > 0)
              Text(
                'Abatimento negociado: ${_money(transaction.discountAmount!)}',
                style: const TextStyle(color: Colors.teal, fontSize: 12),
              ),
          ],
        ),
        trailing: Text(
          _money(transaction.amount),
          style: TextStyle(
            color: isPaid ? Colors.grey : (isOverdue ? Colors.red : Colors.black),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _openManualPayment(Debt currentDebt, double remaining, int existingCount) {
    final now = DateTime.now().toIso8601String();
    final amount = remaining > 0 ? remaining : (currentDebt.installmentAmount ?? currentDebt.totalAmount);
    final newTransaction = FinancialTransaction(
      title: 'Pagamento - ${currentDebt.name}',
      amount: amount,
      type: 'expense',
      status: 'pending',
      debtId: currentDebt.id,
      categoryId: currentDebt.categoryId,
      installmentNumber: existingCount + 1,
      totalInstallments: currentDebt.installmentCount,
      transactionDate: now,
      dueDate: now,
      createdAt: now,
      updatedAt: now,
    );
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTransactionScreen(transaction: newTransaction)));
  }

  Future<void> _startPayment(Debt debt, List<FinancialTransaction> existingInstallments) async {
    if (debt.id == null) return;
    if (existingInstallments.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta dívida já possui lançamentos no Financeiro.')));
      return;
    }

    final defaultAccountId = await _getDefaultAccountId();
    final settings = ref.read(appSettingsProvider);
    final remind = (settings[AppSettingKeys.debtsRemindersDefault] ?? 'false') == 'true';
    final count = (debt.installmentCount ?? 0) > 0 ? debt.installmentCount! : 1;
    final firstDue = DateTime.tryParse(debt.firstDueDate ?? '') ?? DateTime.now();
    final amounts = _buildInstallmentAmounts(debt.totalAmount, count, debt.installmentAmount ?? 0);

    for (var i = 0; i < count; i++) {
      final due = _safeMonthlyDueDate(firstDue, i);
      final now = DateTime.now().toIso8601String();
      await ref.read(transactionsProvider.notifier).addTransaction(
            FinancialTransaction(
              title: count == 1 ? 'Pagamento - ${debt.name}' : '${debt.name} (Parcela ${i + 1}/$count)',
              description: 'Lançamento criado pelo botão Iniciar pagamento da dívida.',
              amount: amounts[i],
              type: 'expense',
              transactionDate: due.toIso8601String(),
              dueDate: due.toIso8601String(),
              accountId: defaultAccountId,
              categoryId: debt.categoryId,
              status: 'pending',
              reminderEnabled: remind,
              debtId: debt.id,
              installmentNumber: i + 1,
              totalInstallments: count,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count lançamento(s) criado(s) na aba Finanças.')));
  }

  void _showNegotiationOptions(Debt debt, List<FinancialTransaction> installments, double paidAmount, double discounts) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.done_all),
              title: const Text('Negociar integral'),
              subtitle: const Text('Quitar a dívida em um único pagamento negociado.'),
              onTap: () {
                Navigator.pop(ctx);
                _showIntegralNegotiationDialog(debt, installments, paidAmount, discounts);
              },
            ),
            ListTile(
              leading: const Icon(Icons.format_list_numbered),
              title: const Text('Negociar parcelado'),
              subtitle: const Text('Substituir parcelas abertas por um novo acordo parcelado.'),
              onTap: () {
                Navigator.pop(ctx);
                _showInstallmentNegotiationDialog(debt, installments, paidAmount, discounts);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cancelOpenInstallments(List<FinancialTransaction> installments) async {
    for (final transaction in installments) {
      if (transaction.id == null || transaction.status == 'paid' || transaction.status == 'canceled') continue;
      await ref.read(transactionsProvider.notifier).updateTransaction(
            transaction.copyWith(
              status: 'canceled',
              reminderEnabled: false,
              updatedAt: DateTime.now().toIso8601String(),
            ),
          );
    }
  }

  void _showIntegralNegotiationDialog(Debt debt, List<FinancialTransaction> installments, double paidAmount, double discounts) {
    final remaining = (debt.totalAmount - paidAmount - discounts).clamp(0, double.infinity).toDouble();
    final amountController = TextEditingController(text: remaining.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final payoff = _parseMoney(amountController.text);
          final totalMoney = paidAmount + payoff;
          final color = _comparisonColor(totalMoney, debt.totalAmount);
          return AlertDialog(
            title: const Text('Negociar integral'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Valor original: ${_money(debt.totalAmount)}'),
                  Text('Já pago em dinheiro: ${_money(paidAmount)}'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Valor de quitação agora', border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  const SizedBox(height: 12),
                  Text('Total em dinheiro após quitar: ${_money(totalMoney)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(_comparisonText(totalMoney, debt.totalAmount), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              TextButton(
                onPressed: () async {
                  if (payoff <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um valor de quitação maior que zero.')));
                    return;
                  }
                  await _applyIntegralNegotiation(debt, installments, payoff, paidAmount, discounts);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Salvar quitação'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(amountController.dispose);
  }

  Future<void> _applyIntegralNegotiation(Debt debt, List<FinancialTransaction> installments, double payoff, double paidAmount, double discounts) async {
    if (debt.id == null) return;
    await _cancelOpenInstallments(installments);
    final defaultAccountId = await _getDefaultAccountId();
    final now = DateTime.now().toIso8601String();
    final discountNeeded = (debt.totalAmount - paidAmount - discounts - payoff).clamp(0, double.infinity).toDouble();

    await ref.read(transactionsProvider.notifier).addTransaction(
          FinancialTransaction(
            title: 'Quitação negociada - ${debt.name}',
            description: 'Quitação integral negociada. ${_comparisonText(paidAmount + payoff, debt.totalAmount)}',
            amount: _roundCents(payoff),
            type: 'expense',
            transactionDate: now,
            dueDate: now,
            paidDate: now,
            accountId: defaultAccountId,
            categoryId: debt.categoryId,
            paymentMethod: 'negociação',
            status: 'paid',
            reminderEnabled: false,
            debtId: debt.id,
            installmentNumber: 1,
            totalInstallments: 1,
            discountAmount: discountNeeded > 0 ? _roundCents(discountNeeded) : null,
            notes: 'Negociação integral registrada pela tela de dívida.',
            createdAt: now,
            updatedAt: now,
          ),
        );

    await ref.read(debtsProvider.notifier).updateDebt(debt.copyWith(status: 'paid', updatedAt: now));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dívida quitada por negociação integral.')));
  }

  void _showInstallmentNegotiationDialog(Debt debt, List<FinancialTransaction> installments, double paidAmount, double discounts) {
    final countController = TextEditingController(text: debt.installmentCount?.toString() ?? '');
    final amountController = TextEditingController(text: debt.installmentAmount?.toStringAsFixed(2) ?? '');
    DateTime firstDueDate = DateTime.tryParse(debt.firstDueDate ?? '') ?? DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final count = int.tryParse(countController.text) ?? 0;
          final installmentAmount = _parseMoney(amountController.text);
          final negotiatedTotal = _roundCents(count * installmentAmount);
          final totalMoney = paidAmount + negotiatedTotal;
          final color = _comparisonColor(totalMoney, debt.totalAmount);
          return AlertDialog(
            title: const Text('Negociar parcelado'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Valor original: ${_money(debt.totalAmount)}'),
                  Text('Já pago em dinheiro: ${_money(paidAmount)}'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: countController,
                    decoration: const InputDecoration(labelText: 'Quantidade de parcelas', border: OutlineInputBorder()),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setLocal(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Valor de cada parcela', border: OutlineInputBorder()),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(context: context, initialDate: firstDueDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                      if (picked != null) setLocal(() => firstDueDate = picked);
                    },
                    icon: const Icon(Icons.event),
                    label: Text('1º vencimento: ${DateFormat('dd/MM/yyyy').format(firstDueDate)}'),
                  ),
                  const SizedBox(height: 12),
                  Text('Total do novo acordo: ${_money(negotiatedTotal)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Total em dinheiro ao final: ${_money(totalMoney)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(_comparisonText(totalMoney, debt.totalAmount), style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
              TextButton(
                onPressed: () async {
                  if (count <= 0 || installmentAmount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe quantidade e valor de parcela válidos.')));
                    return;
                  }
                  await _applyInstallmentNegotiation(debt, installments, count, installmentAmount, firstDueDate, paidAmount, discounts);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: const Text('Salvar acordo'),
              ),
            ],
          );
        },
      ),
    ).whenComplete(() {
      countController.dispose();
      amountController.dispose();
    });
  }

  Future<void> _applyInstallmentNegotiation(Debt debt, List<FinancialTransaction> installments, int count, double installmentAmount, DateTime firstDueDate, double paidAmount, double discounts) async {
    if (debt.id == null) return;
    await _cancelOpenInstallments(installments);
    final defaultAccountId = await _getDefaultAccountId();
    final negotiatedTotal = _roundCents(count * installmentAmount);
    final discountNeeded = (debt.totalAmount - paidAmount - discounts - negotiatedTotal).clamp(0, double.infinity).toDouble();
    final amounts = _buildInstallmentAmounts(negotiatedTotal, count, installmentAmount);
    final settings = ref.read(appSettingsProvider);
    final remind = (settings[AppSettingKeys.debtsRemindersDefault] ?? 'false') == 'true';

    for (var i = 0; i < count; i++) {
      final due = _safeMonthlyDueDate(firstDueDate, i);
      final now = DateTime.now().toIso8601String();
      final isLast = i == count - 1;
      await ref.read(transactionsProvider.notifier).addTransaction(
            FinancialTransaction(
              title: '${debt.name} - acordo (${i + 1}/$count)',
              description: 'Parcela de acordo negociado. ${_comparisonText(paidAmount + negotiatedTotal, debt.totalAmount)}',
              amount: amounts[i],
              type: 'expense',
              transactionDate: due.toIso8601String(),
              dueDate: due.toIso8601String(),
              accountId: defaultAccountId,
              categoryId: debt.categoryId,
              status: 'pending',
              reminderEnabled: remind,
              debtId: debt.id,
              installmentNumber: i + 1,
              totalInstallments: count,
              discountAmount: isLast && discountNeeded > 0 ? _roundCents(discountNeeded) : null,
              notes: 'Acordo parcelado registrado pela tela de dívida.',
              createdAt: now,
              updatedAt: now,
            ),
          );
    }

    await ref.read(debtsProvider.notifier).updateDebt(
          debt.copyWith(
            installmentCount: count,
            installmentAmount: _roundCents(installmentAmount),
            firstDueDate: firstDueDate.toIso8601String(),
            status: 'active',
            updatedAt: DateTime.now().toIso8601String(),
          ),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$count parcela(s) negociada(s) criada(s) na aba Finanças.')));
  }

  bool _isInstallmentOverdue(FinancialTransaction transaction) {
    if (transaction.status == 'paid' || transaction.status == 'canceled') return false;
    final rawDate = transaction.dueDate ?? transaction.transactionDate;
    final due = DateTime.tryParse(rawDate);
    if (due == null) return false;
    final dueDate = DateTime(due.year, due.month, due.day);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return dueDate.isBefore(today);
  }

  Future<void> _toggleInstallment(FinancialTransaction transaction, bool isPaid) async {
    if (isPaid && transaction.accountId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha uma conta antes de marcar a parcela como paga.')));
      await Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTransactionScreen(transaction: transaction)));
      return;
    }

    String newStatus = isPaid ? 'paid' : 'pending';
    if (!isPaid && _isInstallmentOverdue(transaction)) newStatus = 'overdue';

    final updated = transaction.copyWith(
      status: newStatus,
      paidDate: isPaid ? DateTime.now().toIso8601String() : null,
      clearPaidDate: !isPaid,
      updatedAt: DateTime.now().toIso8601String(),
    );

    await ref.read(transactionsProvider.notifier).updateTransaction(updated);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'Pago';
      case 'pending':
        return 'Pendente';
      case 'overdue':
        return 'Atrasado';
      case 'canceled':
        return 'Cancelado';
      default:
        return status;
    }
  }

  void _confirmDelete(Debt debt) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Dívida'),
        content: const Text('Deseja excluir esta dívida? As parcelas vinculadas serão desvinculadas no financeiro.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              if (debt.id != null) await ref.read(debtsProvider.notifier).removeDebt(debt.id!);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
