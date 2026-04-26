import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/providers.dart';
import '../../data/models/debt_model.dart';
import 'create_debt_screen.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {

  @override
  Widget build(BuildContext context) {
    final debts = ref.watch(debtsProvider);
    final transactions = ref.watch(transactionsProvider);

    double totalDividas = 0;
    double totalPago = 0;
    double totalAtrasado = 0;
    
    // List of calculated debts to display
    final debtSummaries = <Map<String, dynamic>>[];

    for (var debt in debts) {
      if (debt.status == 'canceled') continue;

      totalDividas += debt.totalAmount;
      
      double paidForThisDebt = 0;
      double overdueForThisDebt = 0;
      double totalDiscountForThisDebt = 0;
      int paidInstallments = 0;
      int overdueInstallments = 0;
      
      final linkedTransactions = transactions.where((t) => t.debtId == debt.id && t.status != 'canceled');
      
      for (var t in linkedTransactions) {
        if (t.status == 'paid') {
          paidForThisDebt += t.amount;
          paidInstallments++;
          if (t.discountAmount != null && t.discountAmount! > 0) {
             paidForThisDebt += t.discountAmount!; // economy counts as paid against the total limit technically, or reduces remaining
             totalDiscountForThisDebt += t.discountAmount!;
          }
        } else if (t.status == 'overdue') {
          overdueForThisDebt += t.amount;
          overdueInstallments++;
        } else if (t.status == 'pending') {
          if (t.dueDate != null) {
            final due = DateTime.tryParse(t.dueDate!);
            if (due != null && due.isBefore(DateTime.now()) && due.day < DateTime.now().day) {
               overdueForThisDebt += t.amount; // just in case it wasn't flagged overdue, but logic covers it.
               overdueInstallments++;
            }
          }
        }
      }

      totalPago += paidForThisDebt;
      totalAtrasado += overdueForThisDebt;

      debtSummaries.add({
        'debt': debt,
        'paidAmount': paidForThisDebt,
        'overdueAmount': overdueForThisDebt,
        'totalDiscount': totalDiscountForThisDebt,
        'remainingAmount': debt.totalAmount - paidForThisDebt,
        'installmentsCount': linkedTransactions.length,
        'paidInstallments': paidInstallments,
        'overdueInstallments': overdueInstallments,
      });
    }

    final totalPendente = totalDividas - totalPago;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas Dívidas'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   _buildSummaryCard(totalDividas, totalPendente, totalPago, totalAtrasado),
                   const SizedBox(height: 16),
                   const Text('Dívidas Ativas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              )
            )
          ),
          debtSummaries.isEmpty
          ? SliverToBoxAdapter(
             child: Padding(
               padding: const EdgeInsets.all(32.0),
               child: Center(
                 child: Text('Você não tem dívidas cadastradas. Que ótimo!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600))
               ),
             ),
          )
          : SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final ds = debtSummaries[index];
              final Debt d = ds['debt'];
              final paid = ds['paidAmount'] as double;
              final remaining = ds['remainingAmount'] as double;
              final progress = d.totalAmount > 0 ? (paid / d.totalAmount) : 0.0;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CreateDebtScreen(debt: d)));
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(d.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                            Text('R\$ ${d.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                          ],
                        ),
                        if (d.creditorName != null && d.creditorName!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text('Credor: ${d.creditorName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pago: R\$ ${paid.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
                            Text('Falta: R\$ ${remaining > 0 ? remaining.toStringAsFixed(2) : "0.00"}', style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        if (ds['installmentsCount'] > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Parcelas: ${ds['paidInstallments']} / ${ds['installmentsCount']} pagas',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                          ),
                        ],
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            color: progress >= 1.0 ? Colors.green : Colors.blue,
                          ),
                        ),
                        if (progress >= 1.0)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text('DÍVIDA QUITADA! 🎉', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                          )
                        else if (ds['overdueAmount'] > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Row(
                              children: [
                                const Icon(Icons.warning, color: Colors.red, size: 16),
                                const SizedBox(width: 4),
                                Text('Atraso: R\$ ${(ds['overdueAmount'] as double).toStringAsFixed(2)} (${ds['overdueInstallments']} parcelas)', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        if (ds['totalDiscount'] > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text('Economia gerada: R\$ ${(ds['totalDiscount'] as double).toStringAsFixed(2)}', style: const TextStyle(color: Colors.teal, fontSize: 12, fontWeight: FontWeight.bold)),
                          )
                      ],
                    ),
                  ),
                ),
              );
            }, childCount: debtSummaries.length),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateDebtScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCard(double dividas, double pendente, double pago, double atrasado) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total em Dívidas', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    Text(
                      'R\$ ${dividas.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ],
                ),
                 Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                     const Text('Falta Pagar', style: TextStyle(fontSize: 14, color: Colors.grey)),
                     Text(
                      'R\$ ${pendente.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStat('Já Pago', pago, Colors.green),
                _buildStat('Em Atraso', atrasado, Colors.red),
              ],
            ),
          ]
        ),
      ),
    );
  }

   Widget _buildStat(String label, double amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          'R\$ ${amount.toStringAsFixed(2)}',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
