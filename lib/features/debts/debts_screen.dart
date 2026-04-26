import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/providers.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/transaction_model.dart';
import 'create_debt_screen.dart';
import 'debt_details_screen.dart';

class DebtsScreen extends ConsumerStatefulWidget {
  const DebtsScreen({super.key});

  @override
  ConsumerState<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends ConsumerState<DebtsScreen> {
  String _currentFilter = 'todas';

  DateTime? _dueDateOf(FinancialTransaction transaction) {
    return DateTime.tryParse(transaction.dueDate ?? transaction.transactionDate);
  }

  bool _isInstallmentOverdue(FinancialTransaction transaction) {
    if (transaction.status == 'paid' || transaction.status == 'canceled') return false;
    if (transaction.status == 'overdue') return true;
    final due = _dueDateOf(transaction);
    if (due == null) return false;
    final dueDate = DateTime(due.year, due.month, due.day);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return dueDate.isBefore(today);
  }

  @override
  Widget build(BuildContext context) {
    final debts = ref.watch(debtsProvider);
    final transactions = ref.watch(transactionsProvider);
    final appSettings = ref.watch(appSettingsProvider);
    final showPaidDebts = (appSettings[AppSettingKeys.debtsShowPaid] ?? 'true') == 'true';

    double totalDividas = 0;
    double totalAbatido = 0;
    double totalAtrasado = 0;
    double totalDescontos = 0;

    final allDebtSummaries = <Map<String, dynamic>>[];

    for (final debt in debts) {
      if (debt.status == 'canceled') continue;

      totalDividas += debt.totalAmount;

      double paidMoneyForThisDebt = 0;
      double abatidoForThisDebt = 0;
      double overdueForThisDebt = 0;
      double totalDiscountForThisDebt = 0;
      int paidInstallments = 0;
      int overdueInstallments = 0;
      DateTime? nextDueDate;

      final linkedTransactions = transactions.where((transaction) => transaction.debtId == debt.id && transaction.status != 'canceled').toList();
      linkedTransactions.sort((a, b) {
        final ad = _dueDateOf(a) ?? DateTime(2100);
        final bd = _dueDateOf(b) ?? DateTime(2100);
        return ad.compareTo(bd);
      });

      for (final transaction in linkedTransactions) {
        final due = _dueDateOf(transaction);

        if (transaction.status == 'paid') {
          paidMoneyForThisDebt += transaction.amount;
          final discount = transaction.discountAmount ?? 0;
          totalDiscountForThisDebt += discount;
          abatidoForThisDebt += transaction.amount + discount;
          paidInstallments++;
        } else if (_isInstallmentOverdue(transaction)) {
          overdueForThisDebt += transaction.amount;
          overdueInstallments++;
          nextDueDate ??= due;
        } else if (transaction.status == 'pending') {
          nextDueDate ??= due;
        }
      }

      totalAbatido += abatidoForThisDebt;
      totalAtrasado += overdueForThisDebt;
      totalDescontos += totalDiscountForThisDebt;
      final remainingAmount = (debt.totalAmount - abatidoForThisDebt).clamp(0, double.infinity).toDouble();

      allDebtSummaries.add({
        'debt': debt,
        'paidMoney': paidMoneyForThisDebt,
        'paidAmount': abatidoForThisDebt,
        'overdueAmount': overdueForThisDebt,
        'totalDiscount': totalDiscountForThisDebt,
        'remainingAmount': remainingAmount,
        'installmentsCount': linkedTransactions.length,
        'paidInstallments': paidInstallments,
        'overdueInstallments': overdueInstallments,
        'nextDueDate': nextDueDate,
      });
    }

    final totalPendente = (totalDividas - totalAbatido).clamp(0, double.infinity).toDouble();

    final filteredDebtSummaries = allDebtSummaries.where((summary) {
      final Debt debt = summary['debt'];
      final remaining = summary['remainingAmount'] as double;
      final isPaidOut = remaining <= 0;

      if (!showPaidDebts && (debt.status == 'paid' || isPaidOut) && _currentFilter != 'quitadas') return false;
      if (_currentFilter == 'todas') return true;
      if (_currentFilter == 'ativas') return debt.status == 'active' && !isPaidOut;
      if (_currentFilter == 'quitadas') return debt.status == 'paid' || isPaidOut;
      if (_currentFilter == 'atrasadas') return (summary['overdueAmount'] as double) > 0;
      if (_currentFilter == 'pausadas') return debt.status == 'paused';
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Minhas Dívidas')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildSummaryCard(totalDividas, totalPendente, totalAbatido, totalAtrasado, totalDescontos),
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
                  Text(_currentFilterLabel(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          filteredDebtSummaries.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(
                      child: Text('Nenhuma dívida encontrada para este filtro.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final summary = filteredDebtSummaries[index];
                    final Debt debt = summary['debt'];
                    final paid = summary['paidAmount'] as double;
                    final paidMoney = summary['paidMoney'] as double;
                    final remaining = summary['remainingAmount'] as double;
                    final progress = debt.totalAmount > 0 ? (paid / debt.totalAmount).clamp(0.0, 1.0).toDouble() : 0.0;
                    final nextDueDate = summary['nextDueDate'] as DateTime?;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DebtDetailsScreen(debt: debt))),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text(debt.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis)),
                                  Text('R\$ ${debt.totalAmount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                                ],
                              ),
                              if (debt.creditorName != null && debt.creditorName!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text('Credor: ${debt.creditorName}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Abatido: R\$ ${paid.toStringAsFixed(2)}', style: const TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.bold)),
                                  Text('Falta: R\$ ${remaining.toStringAsFixed(2)}', style: const TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              if (paidMoney != paid) ...[
                                const SizedBox(height: 4),
                                Text('Pago em dinheiro: R\$ ${paidMoney.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                              ],
                              if (summary['installmentsCount'] > 0) ...[
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Parcelas: ${summary['paidInstallments']} / ${summary['installmentsCount']} pagas', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                    if (nextDueDate != null && progress < 1.0)
                                      Text('Próx. Venc: ${DateFormat('dd/MM/yy').format(nextDueDate)}', style: TextStyle(fontSize: 12, color: Colors.indigo.shade400, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 8,
                                  backgroundColor: Colors.grey.shade200,
                                  color: progress >= 1.0 ? Colors.green : Colors.blue,
                                ),
                              ),
                              if (debt.status == 'paused')
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text('DÍVIDA PAUSADA ⏸️', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
                                )
                              else if (progress >= 1.0 || debt.status == 'paid')
                                const Padding(
                                  padding: EdgeInsets.only(top: 8.0),
                                  child: Text('DÍVIDA QUITADA! 🎉', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                )
                              else if (debt.status == 'overdue' || summary['overdueAmount'] > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.warning, color: Colors.red, size: 16),
                                      const SizedBox(width: 4),
                                      Text('Atraso: R\$ ${(summary['overdueAmount'] as double).toStringAsFixed(2)} (${summary['overdueInstallments']} parcelas)', style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              if (summary['totalDiscount'] > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text('Economia gerada: R\$ ${(summary['totalDiscount'] as double).toStringAsFixed(2)}', style: const TextStyle(color: Colors.teal, fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }, childCount: filteredDebtSummaries.length),
                ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateDebtScreen())),
        child: const Icon(Icons.add),
      ),
    );
  }

  String _currentFilterLabel() {
    switch (_currentFilter) {
      case 'ativas':
        return 'Dívidas Ativas';
      case 'atrasadas':
        return 'Dívidas em Atraso';
      case 'quitadas':
        return 'Dívidas Quitadas';
      case 'pausadas':
        return 'Dívidas Pausadas';
      default:
        return 'Todas as Dívidas';
    }
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _currentFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) setState(() => _currentFilter = value);
        },
      ),
    );
  }

  Widget _buildSummaryCard(double dividas, double pendente, double abatido, double atrasado, double descontos) {
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
                    Text('R\$ ${dividas.toStringAsFixed(2)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Falta Pagar', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    Text('R\$ ${pendente.toStringAsFixed(2)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.orange)),
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
                _buildStat('Abatido', abatido, Colors.green),
                _buildStat('Em Atraso', atrasado, Colors.red),
                _buildStat('Descontos', descontos, Colors.teal),
              ],
            ),
          ],
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
        Text('R\$ ${amount.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
