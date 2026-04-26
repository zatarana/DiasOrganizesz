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
        final ad = DateTime.tryParse(a.dueDate ?? a.transactionDate) ?? DateTime(2100);
        final bd = DateTime.tryParse(b.dueDate ?? b.transactionDate) ?? DateTime(2100);
        return ad.compareTo(bd);
      });

    final paidAmount = installments.where((t) => t.status == 'paid').fold<double>(0, (sum, t) => sum + t.amount);
    final discounts = installments.where((t) => t.status == 'paid').fold<double>(0, (sum, t) => sum + (t.discountAmount ?? 0));
    final abatido = paidAmount + discounts;
    final remaining = (currentDebt.totalAmount - abatido).clamp(0, double.infinity).toDouble();
    final progress = currentDebt.totalAmount > 0 ? (abatido / currentDebt.totalAmount).clamp(0.0, 1.0).toDouble() : 0.0;
    final valueDiff = abatido - currentDebt.totalAmount;

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
        onPressed: currentDebt.status == 'canceled'
            ? null
            : () {
                final now = DateTime.now().toIso8601String();
                final amount = remaining > 0 ? remaining : (currentDebt.installmentAmount ?? 0.0);
                final newTransaction = FinancialTransaction(
                  title: 'Pagamento - ${currentDebt.name}',
                  amount: amount,
                  type: 'expense',
                  status: 'pending',
                  debtId: currentDebt.id,
                  categoryId: currentDebt.categoryId,
                  installmentNumber: installments.length + 1,
                  totalInstallments: currentDebt.installmentCount,
                  transactionDate: now,
                  dueDate: now,
                  createdAt: now,
                  updatedAt: now,
                );
                Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTransactionScreen(transaction: newTransaction)));
              },
        icon: const Icon(Icons.add),
        label: const Text('Add Pagamento'),
      ),
      body: Column(
        children: [
          _buildHeader(currentDebt, paidAmount, discounts, abatido, remaining, progress, valueDiff),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Parcelas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: installments.isEmpty
                ? const Center(child: Text('Nenhuma parcela gerada para esta dívida.'))
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
          _headerRow('Valor Total Base:', 'R\$ ${debt.totalAmount.toStringAsFixed(2)}', Colors.black87, 20),
          const SizedBox(height: 8),
          _headerRow('Pago em dinheiro:', 'R\$ ${paidAmount.toStringAsFixed(2)}', Colors.green, 16),
          const SizedBox(height: 8),
          _headerRow('Descontos abatidos:', 'R\$ ${discounts.toStringAsFixed(2)}', Colors.teal, 16),
          const SizedBox(height: 8),
          _headerRow('Total abatido:', 'R\$ ${abatido.toStringAsFixed(2)}', Colors.blue, 16),
          const SizedBox(height: 8),
          _headerRow('Falta pagar:', 'R\$ ${remaining.toStringAsFixed(2)}', Colors.orange, 16),
          if (debt.status == 'paid' || progress >= 1.0) ...[
            const SizedBox(height: 12),
            if (valueDiff < 0)
              Text('Quitada com economia de R\$ ${valueDiff.abs().toStringAsFixed(2)}', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold))
            else if (valueDiff > 0)
              Text('Quitada com acréscimos de R\$ ${valueDiff.toStringAsFixed(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
            else
              const Text('Quitada no valor exato!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
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
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
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
          onChanged: (val) {
            if (val != null) _toggleInstallment(transaction, val);
          },
        ),
        title: Text(
          transaction.title,
          style: TextStyle(
            decoration: isPaid ? TextDecoration.lineThrough : null,
            fontWeight: isPaid ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (transaction.dueDate != null)
              Text(
                'Vencimento: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(transaction.dueDate!))}',
                style: TextStyle(color: isOverdue ? Colors.red : null),
              ),
            if (isPaid && transaction.paidDate != null)
              Text(
                'Pago em: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(transaction.paidDate!))}',
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
            if (transaction.discountAmount != null && transaction.discountAmount! > 0)
              Text(
                'Desconto: R\$ ${transaction.discountAmount!.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.teal, fontSize: 12),
              ),
          ],
        ),
        trailing: Text(
          'R\$ ${transaction.amount.toStringAsFixed(2)}',
          style: TextStyle(
            color: isPaid ? Colors.grey : (isOverdue ? Colors.red : Colors.black),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
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

  void _toggleInstallment(FinancialTransaction transaction, bool isPaid) {
    String newStatus = isPaid ? 'paid' : 'pending';
    if (!isPaid && _isInstallmentOverdue(transaction)) newStatus = 'overdue';

    final updated = transaction.copyWith(
      status: newStatus,
      paidDate: isPaid ? DateTime.now().toIso8601String() : null,
      clearPaidDate: !isPaid,
      updatedAt: DateTime.now().toIso8601String(),
    );

    ref.read(transactionsProvider.notifier).updateTransaction(updated);
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
              if (mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
