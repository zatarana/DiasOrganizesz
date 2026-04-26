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
    // Watch debts to get latest updates if debt is modified
    final debts = ref.watch(debtsProvider);
    final debtIndex = debts.indexWhere((d) => d.id == widget.debt.id);
    
    // Fallback if debt was deleted
    if (debtIndex == -1) {
       return Scaffold(
         appBar: AppBar(title: const Text('Dívida Excluída')),
         body: const Center(child: Text('Esta dívida não existe mais.')),
       );
    }
    
    final currentDebt = debts[debtIndex];
    final allTransactions = ref.watch(transactionsProvider);
    final installments = allTransactions.where((t) => t.debtId == currentDebt.id && t.status != 'canceled').toList();
    
    installments.sort((a, b) {
       if (a.installmentNumber != null && b.installmentNumber != null) {
          return a.installmentNumber!.compareTo(b.installmentNumber!);
       }
       return 0;
    });

    double paidForThisDebt = 0;
    double totalDiscounts = 0;
    for (var t in installments) {
      if (t.status == 'paid') {
         paidForThisDebt += t.amount;
         if (t.discountAmount != null) {
           paidForThisDebt += t.discountAmount!;
           totalDiscounts += t.discountAmount!;
         }
      }
    }
    
    // Check for ad-hoc value differences (like user paid less/more without discount fields strictly matching)
    final progress = currentDebt.totalAmount > 0 ? (paidForThisDebt / currentDebt.totalAmount) : 0.0;
    
    // Real extra or missing against total
    final expectedAmount = currentDebt.totalAmount;
    final valueDiff = paidForThisDebt - expectedAmount; // > 0 means paid more than debt (juros/multas), < 0 means paid less (discount)

    return Scaffold(
      appBar: AppBar(
        title: Text(currentDebt.name),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
               if (value == 'edit') {
                 Navigator.push(context, MaterialPageRoute(builder: (_) => CreateDebtScreen(debt: currentDebt)));
               } else if (value == 'pause') {
                 ref.read(debtsProvider.notifier).updateDebt(currentDebt.copyWith(status: currentDebt.status == 'paused' ? 'active' : 'paused'));
               } else if (value == 'cancel') {
                 ref.read(debtsProvider.notifier).updateDebt(currentDebt.copyWith(status: currentDebt.status == 'canceled' ? 'active' : 'canceled'));
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
         onPressed: () {
            // New Ad-Hoc Transaction specifically for this debt
            final newT = FinancialTransaction(
              title: 'Pagamento - ${currentDebt.name}',
              amount: currentDebt.totalAmount > 0 ? (currentDebt.totalAmount - paidForThisDebt).clamp(0, double.infinity) : 0,
              type: 'expense',
              status: 'pending',
              debtId: currentDebt.id,
              categoryId: currentDebt.categoryId,
              installmentNumber: installments.length + 1,
              transactionDate: DateTime.now().toIso8601String(),
              createdAt: DateTime.now().toIso8601String(),
              updatedAt: DateTime.now().toIso8601String(),
            );
            Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTransactionScreen(transaction: newT)));
         },
         icon: const Icon(Icons.add),
         label: const Text('Add Pagamento'),
      ),
      body: Column(
        children: [
          _buildHeader(currentDebt, paidForThisDebt, progress, totalDiscounts, valueDiff),
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
                  itemBuilder: (context, index) {
                    final t = installments[index];
                    return _buildInstallmentTile(t);
                  },
                ),
          )
        ],
      ),
    );
  }

  Widget _buildHeader(Debt d, double paid, double progress, double totalDiscounts, double valueDiff) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
         crossAxisAlignment: CrossAxisAlignment.stretch,
         children: [
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
                Text('Valor Total Base:', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                Text('R\$ ${d.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
             ],
           ),
           const SizedBox(height: 8),
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
                const Text('Pago / Abatido:', style: TextStyle(fontSize: 14, color: Colors.green)),
                Text('R\$ ${paid.toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
             ],
           ),
           const SizedBox(height: 8),
           Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
             children: [
                const Text('Falta Pagar:', style: TextStyle(fontSize: 14, color: Colors.orange)),
                Text('R\$ ${(d.totalAmount - paid).clamp(0, double.infinity).toStringAsFixed(2)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
             ],
           ),
           if (d.status == 'paid') ...[
             const SizedBox(height: 12),
             if (valueDiff < 0)
                Text('Quitada com Economia! (Desconto Extra: R\$ ${valueDiff.abs().toStringAsFixed(2)})', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold))
             else if (valueDiff > 0)
                Text('Quitada com Acréscimos (Juros/Multas: R\$ ${valueDiff.toStringAsFixed(2)})', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
             else
                const Text('Quitada no valor exato!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
           ],
           const SizedBox(height: 16),
           ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: Colors.grey.shade200,
              color: progress >= 1.0 ? Colors.green : Colors.blue,
            ),
          ),
         ],
      ),
    );
  }

  Widget _buildInstallmentTile(FinancialTransaction t) {
    bool isPaid = t.status == 'paid';
    bool isOverdue = false;
    
    if (!isPaid && t.dueDate != null) {
      final due = DateTime.tryParse(t.dueDate!);
      if (due != null && due.isBefore(DateTime.now()) && due.day < DateTime.now().day) {
        isOverdue = true;
      }
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTransactionScreen(transaction: t)));
        },
        leading: Checkbox(
          value: isPaid,
          onChanged: (val) {
             if (val != null) {
               _toggleInstallment(t, val);
             }
          },
        ),
        title: Text(
          t.title,
          style: TextStyle(
            decoration: isPaid ? TextDecoration.lineThrough : null,
            fontWeight: isPaid ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (t.dueDate != null)
              Text(
                'Vencimento: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(t.dueDate!))}',
                style: TextStyle(color: isOverdue ? Colors.red : null),
              ),
            if (isPaid && t.paidDate != null)
              Text(
                'Pago em: ${DateFormat('dd/MM/yyyy').format(DateTime.parse(t.paidDate!))}',
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
            if (t.discountAmount != null && t.discountAmount! > 0)
              Text(
                'Desconto: R\$ ${t.discountAmount!.toStringAsFixed(2)}',
                style: const TextStyle(color: Colors.teal, fontSize: 12),
              )
          ],
        ),
        trailing: Text(
          'R\$ ${t.amount.toStringAsFixed(2)}',
          style: TextStyle(
             color: isPaid ? Colors.grey : (isOverdue ? Colors.red : Colors.black),
             fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _toggleInstallment(FinancialTransaction t, bool isPaid) {
     String newStatus = isPaid ? 'paid' : 'pending';
     if (!isPaid && t.dueDate != null) {
       final due = DateTime.tryParse(t.dueDate!);
       final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
       if (due != null) {
          final dueDateOnly = DateTime(due.year, due.month, due.day);
          if (dueDateOnly.isBefore(today)) {
             newStatus = 'overdue';
          }
       }
     }
     
     var updated = t.copyWith(
       status: newStatus, 
       paidDate: isPaid ? DateTime.now().toIso8601String() : null,
     );
     
     // Allow users to specify payment method and discount later, 
     // but typical checkbox just pays it immediately for the nominal amount with current date.
     ref.read(transactionsProvider.notifier).updateTransaction(updated);
  }

  void _confirmDelete(Debt d) {
     showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Dívida'),
        content: const Text('Deseja excluir esta dívida e apagar todas as parcelas atreladas a ela?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
               if (d.id != null) {
                 // Removendo a dívida automaticamente gerencia ou você pode remover as parcelas via provider.
                 // We should remove all transactions related first:
                 final allTransactions = ref.read(transactionsProvider);
                 final installments = allTransactions.where((t) => t.debtId == d.id).toList();
                 final transNotifier = ref.read(transactionsProvider.notifier);
                 for (var inst in installments) {
                    if (inst.id != null) await transNotifier.removeTransaction(inst.id!);
                 }
                 await ref.read(debtsProvider.notifier).removeDebt(d.id!);
               }
               if (mounted) {
                 Navigator.pop(ctx);
                 Navigator.pop(context);
               }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      )
     );
  }
}
