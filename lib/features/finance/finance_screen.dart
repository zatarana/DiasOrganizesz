import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/providers.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/category_model.dart';
import 'create_transaction_screen.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  DateTime _selectedMonth = DateTime.now();
  String _filterType = 'all'; // all, receita, despesa
  String _filterStatus = 'all'; // all, paid, pending
  int? _filterCategory;
  final TextEditingController _searchController = TextEditingController();

  void _nextMonth() {
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1));
  }

  void _prevMonth() {
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1));
  }

  @override
  Widget build(BuildContext context) {
    var allTransactions = ref.watch(transactionsProvider);
    
    // Apply Filters
    var filtered = allTransactions.where((t) {
      final tDate = DateTime.tryParse(t.date);
      if (tDate == null) return false;
      if (tDate.month != _selectedMonth.month || tDate.year != _selectedMonth.year) return false;
      
      if (_filterType != 'all' && t.type != _filterType) return false;
      if (_filterStatus == 'paid' && !t.isPaid) return false;
      if (_filterStatus == 'pending' && t.isPaid) return false;
      if (_filterCategory != null && t.categoryId != _filterCategory) return false;
      
      if (_searchController.text.isNotEmpty && !t.title.toLowerCase().contains(_searchController.text.toLowerCase())) {
        return false;
      }
      
      return true;
    }).toList();

    double receitasPagas = 0;
    double receitasPendentes = 0;
    double despesasPagas = 0;
    double despesasPendentes = 0;
    int despesasVencidas = 0;

    for (var t in allTransactions) { // calculando totais do mes
      final tDate = DateTime.tryParse(t.date);
      if (tDate != null && tDate.month == _selectedMonth.month && tDate.year == _selectedMonth.year) {
        if (t.type == 'receita') {
          if (t.isPaid) receitasPagas += t.amount;
          else receitasPendentes += t.amount;
        } else if (t.type == 'despesa') {
          if (t.isPaid) despesasPagas += t.amount;
          else {
            despesasPendentes += t.amount;
            final dueDate = t.dueDate != null ? DateTime.tryParse(t.dueDate!) : tDate;
            if (dueDate != null && dueDate.isBefore(DateTime.now()) && dueDate.day < DateTime.now().day) {
              despesasVencidas++;
            }
          }
        }
      }
    }

    final totalReceitas = receitasPagas + receitasPendentes;
    final totalDespesas = despesasPagas + despesasPendentes;
    final saldoMensal = totalReceitas - totalDespesas;
    final saldoRealizado = receitasPagas - despesasPagas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanças'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(icon: const Icon(Icons.chevron_left), onPressed: _prevMonth),
                      Text(DateFormat('MMMM yyyy', 'pt_BR').format(_selectedMonth).toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildSummaryCard(saldoMensal, saldoRealizado, totalReceitas, totalDespesas, despesasVencidas),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar movimentação...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onChanged: (v) => setState((){}),
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildFilterChip('Todos', 'all', _filterType, (v) => setState(() => _filterType = v)),
                        const SizedBox(width: 8),
                        _buildFilterChip('Receitas', 'receita', _filterType, (v) => setState(() => _filterType = v)),
                        const SizedBox(width: 8),
                        _buildFilterChip('Despesas', 'despesa', _filterType, (v) => setState(() => _filterType = v)),
                        const SizedBox(width: 16),
                        _buildFilterChip('Tudo', 'all', _filterStatus, (v) => setState(() => _filterStatus = v)),
                        const SizedBox(width: 8),
                        _buildFilterChip('Pago', 'paid', _filterStatus, (v) => setState(() => _filterStatus = v)),
                        const SizedBox(width: 8),
                        _buildFilterChip('Pendente', 'pending', _filterStatus, (v) => setState(() => _filterStatus = v)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Movimentações', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          filtered.isEmpty 
          ? SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Center(child: Text('Nenhuma movimentação para o período e filtros atuais.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600))),
              ),
            )
          : SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final t = filtered[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: t.type == 'receita' ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    child: Icon(
                      t.type == 'receita' ? Icons.arrow_upward : Icons.arrow_downward,
                      color: t.type == 'receita' ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(t.title, style: TextStyle(decoration: t.isPaid ? TextDecoration.none : null)),
                  subtitle: Text(DateFormat('dd/MM/yyyy').format(DateTime.parse(t.date))),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'R\$ ${t.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: t.type == 'receita' ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(t.isPaid ? 'Efetuado' : 'Pendente', style: TextStyle(color: t.isPaid ? Colors.green : Colors.orange, fontSize: 12)),
                        ]
                      ),
                      Checkbox(
                        value: t.isPaid,
                        onChanged: (val) {
                          if (val != null) {
                            ref.read(transactionsProvider.notifier).updateTransaction(t.copyWith(isPaid: val));
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                     Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTransactionScreen(transaction: t)));
                  },
                );
              },
              childCount: filtered.length,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTransactionScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String groupValue, Function(String) onSelect) {
    return ChoiceChip(
      label: Text(label),
      selected: groupValue == value,
      onSelected: (b) { if(b) onSelect(value); },
    );
  }

  Widget _buildSummaryCard(double saldoPrevisto, double saldoRealizado, double receitas, double despesas, int despesasVencidas) {
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
                    const Text('Saldo Realizado', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    Text(
                      'R\$ ${saldoRealizado.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: saldoRealizado >= 0 ? Colors.green : Colors.red),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Saldo Previsto', style: TextStyle(fontSize: 14, color: Colors.grey)),
                    Text(
                      'R\$ ${saldoPrevisto.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: saldoPrevisto >= 0 ? Colors.green : Colors.red),
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
                _buildStat('Receitas', receitas, Colors.green),
                _buildStat('Despesas', despesas, Colors.red),
              ],
            ),
             if (despesasVencidas > 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    children: [
                      const Icon(Icons.warning, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text('$despesasVencidas despesa(s) vencida(s)!', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )
             ]
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
        Text(
          'R\$ ${amount.toStringAsFixed(2)}',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}
