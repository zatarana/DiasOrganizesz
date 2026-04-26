import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/providers.dart';
import '../../data/models/debt_model.dart';
import 'create_debt_screen.dart';
import 'debt_details_screen.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  String _currentFilter = 'todas'; // todas, ativas, quitadas, atrasadas, pausadas

  @override
  Widget build(BuildContext context) {
    final debts = ref.watch(debtsProvider);
    final transactions = ref.watch(transactionsProvider);
    final appSettings = ref.watch(appSettingsProvider);
    final showPaidDebts = (appSettings[AppSettingKeys.debtsShowPaid] ?? 'true') == 'true';

    double totalDividas = 0;
    double totalPago = 0;
    double totalAtrasado = 0;
    
    // List of calculated debts to display
    final allDebtSummaries = <Map<String, dynamic>>[];

    for (var debt in debts) {
      if (debt.status == 'canceled') continue;

      totalDividas += debt.totalAmount;
      
      double paidForThisDebt = 0;
      double overdueForThisDebt = 0;
      double totalDiscountForThisDebt = 0;
      int paidInstallments = 0;
      int overdueInstallments = 0;
      DateTime? nextDueDate;
      
      final linkedTransactions = transactions.where((t) => t.debtId == debt.id && t.status != 'canceled').toList();
      
      // Sort transactions by due date to get the true next due date
      linkedTransactions.sort((a, b) {
        if (a.dueDate == null && b.dueDate == null) return 0;
        if (a.dueDate == null) return 1;
        if (b.dueDate == null) return -1;
        return DateTime.parse(a.dueDate!).compareTo(DateTime.parse(b.dueDate!));
      });

      for (var t in linkedTransactions) {
        DateTime? due = t.dueDate != null ? DateTime.tryParse(t.dueDate!) : null;

        if (t.status == 'paid') {
          paidForThisDebt += t.amount;
          paidInstallments++;
          if (t.discountAmount != null && t.discountAmount! > 0) {
             paidForThisDebt += t.discountAmount!;
             totalDiscountForThisDebt += t.discountAmount!;
          }
        } else if (t.status == 'overdue') {
          overdueForThisDebt += t.amount;
          overdueInstallments++;
          if (nextDueDate == null && due != null) {
            nextDueDate = due; // Oldest overdue is effectively the next required payment
          }
        } else if (t.status == 'pending') {
          if (due != null) {
            if (due.isBefore(DateTime.now()) && due.day < DateTime.now().day) {
               overdueForThisDebt += t.amount;
               overdueInstallments++;
               if (nextDueDate == null) nextDueDate = due;
            } else {
               if (nextDueDate == null) nextDueDate = due;
            }
          }
        }
      }

      totalPago += paidForThisDebt;
      totalAtrasado += overdueForThisDebt;

      allDebtSummaries.add({
        'debt': debt,
        'paidAmount': paidForThisDebt,
        'overdueAmount': overdueForThisDebt,
        'totalDiscount': totalDiscountForThisDebt,
        'remainingAmount': debt.totalAmount - paidForThisDebt,
        'installmentsCount': linkedTransactions.length,
        'paidInstallments': paidInstallments,
        'overdueInstallments': overdueInstallments,
        'nextDueDate': nextDueDate,
      });
    }

    final totalPendente = totalDividas - totalPago;

    List<Map<String, dynamic>> filteredDebtSummaries = allDebtSummaries.where((ds) {
       final Debt d = ds['debt'];
       final remaining = ds['remainingAmount'] as double;
       final isPaidOut = remaining <= 0;

       if (!showPaidDebts && (d.status == 'paid' || isPaidOut) && _currentFilter != 'quitadas') {
         return false;
       }
       
       if (_currentFilter == 'todas') return true;
       if (_currentFilter == 'ativas') return d.status == 'active' && !isPaidOut;
       if (_currentFilter == 'quitadas') return d.status == 'paid' || isPaidOut;
       if (_currentFilter == 'atrasadas') return (ds['overdueAmount'] as double) > 0;
       if (_currentFilter == 'pausadas') return d.status == 'paused';
       return true;
    }).toList();

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
                   const SizedBox(height: 24),
                   const Text('Filtros Rápidos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   SingleChildScrollView(
                     scrollDirection: Axis.horizontal,
                     child: Row(
                       children: [
                         _buildFilterChip('Todas', 'todas'),
                         _buildFilterChip('Ativas', 'ativas'),
                         _buildFilterChip('Atrasadas', 'atrasadas'),
                         if (showPaidDebts) _buildFilterChip('Quitadas', 'quitadas'),
                         _buildFilterChip('Pausadas', 'pausadas'),
                       ],
                     ),
                   ),
                   const SizedBox(height: 16),
                   Text(
                     _currentFilter == 'todas' ? 'Todas as Dívidas' : 
                     _currentFilter == 'ativas' ? 'Dívidas Ativas' :
                     _currentFilter == 'atrasadas' ? 'Dívidas em Atraso' :
                     _currentFilter == 'quitadas' ? 'Dívidas Quitadas' : 
                     'Dívidas Pausadas', 
                     style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                   ),
                ],
              )
            )
          ),
          filteredDebtSummaries.isEmpty
          ? SliverToBoxAdapter(
             child: Padding(
               padding: const EdgeInsets.all(32.0),
               child: Center(
                 child: Text('Nenhuma dívida encontrada para este filtro.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600))
               ),
             ),
          )
          : SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final ds = filteredDebtSummaries[index];
              final Debt d = ds['debt'];
              final paid = ds['paidAmount'] as double;
              final remaining = ds['remainingAmount'] as double;
              final progress = d.totalAmount > 0 ? (paid / d.totalAmount) : 0.0;
              final nextDueDate = ds['nextDueDate'] as DateTime?;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => DebtDetailsScreen(debt: d)));
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Parcelas: ${ds['paidInstallments']} / ${ds['installmentsCount']} pagas',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                              if (nextDueDate != null && progress < 1.0)
                                Text(
                                  'Próx. Venc: ${DateFormat('dd/MM/yy').format(nextDueDate)}',
                                  style: TextStyle(fontSize: 12, color: Colors.indigo.shade400, fontWeight: FontWeight.bold),
                                ),
                            ],
                          )
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
                        if (d.status == 'canceled')
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text('DÍVIDA CANCELADA 🚫', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                          )
                        else if (d.status == 'paused')
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text('DÍVIDA PAUSADA ⏸️', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                          )
                        else if (progress >= 1.0 || d.status == 'paid')
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text('DÍVIDA QUITADA! 🎉', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                          )
                        else if (d.status == 'overdue' || ds['overdueAmount'] > 0)
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
            }, childCount: filteredDebtSummaries.length),
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

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _currentFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            setState(() => _currentFilter = value);
          }
        },
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
