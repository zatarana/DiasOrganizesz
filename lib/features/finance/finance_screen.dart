import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/providers.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/financial_category_model.dart';
import 'create_transaction_screen.dart';
import 'finance_categories_screen.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen> {
  DateTime _selectedMonth = DateTime.now();
  String _filterType = 'all'; // all, income, expense
  String _filterStatus = 'all'; // all, paid, pending, overdue
  int? _filterCategory;
  final TextEditingController _searchController = TextEditingController();

  void _nextMonth() {
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1));
  }

  void _prevMonth() {
    setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1));
  }

  void _generateFixedTransactions() {
    final allTransactions = ref.read(transactionsProvider);
    final previousMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1);
    
    // Obter fixos e não cancelados do mês anterior
    final previousFixed = allTransactions.where((t) {
      final d = DateTime.tryParse(t.transactionDate);
      return d != null && d.month == previousMonth.month && d.year == previousMonth.year && t.isFixed && t.status != 'canceled';
    }).toList();

    int added = 0;
    for (var t in previousFixed) {
      final oldDate = DateTime.tryParse(t.transactionDate) ?? DateTime.now();
      // Criar nova data pro mês atual mantendo o dia se possível
      int targetDay = oldDate.day;
      final daysInMonth = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
      if (targetDay > daysInMonth) targetDay = daysInMonth; 

      final newDate = DateTime(_selectedMonth.year, _selectedMonth.month, targetDay);
      
      DateTime? newDueDate;
      if (t.dueDate != null) {
        final oldDue = DateTime.tryParse(t.dueDate!);
        if (oldDue != null) {
          int targetDueDay = oldDue.day;
          final daysInMonthDue = DateUtils.getDaysInMonth(_selectedMonth.year, _selectedMonth.month);
          if (targetDueDay > daysInMonthDue) targetDueDay = daysInMonthDue;
          newDueDate = DateTime(_selectedMonth.year, _selectedMonth.month, targetDueDay);
        }
      }

      final newT = FinancialTransaction(
          title: t.title,
          description: t.description,
          amount: t.amount,
          type: t.type,
          transactionDate: newDate.toIso8601String(),
          dueDate: newDueDate?.toIso8601String(),
          paidDate: null,
          categoryId: t.categoryId,
          paymentMethod: t.paymentMethod,
          status: 'pending', // nascem como pendentes
          isFixed: true,
          recurrenceType: 'monthly',
          notes: t.notes,
          createdAt: DateTime.now().toIso8601String(),
          updatedAt: DateTime.now().toIso8601String(),
      );
      ref.read(transactionsProvider.notifier).addTransaction(newT);
      added++;
    }

    if (added > 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$added lançamentos fixos gerados para este mês!')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum lançamento fixo encontrado no mês anterior.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    var allTransactions = ref.watch(transactionsProvider);
    var allCategories = ref.watch(financialCategoriesProvider);
    
    // Apply Filters
    var filtered = allTransactions.where((t) {
      final tDate = DateTime.tryParse(t.transactionDate);
      if (tDate == null) return false;
      if (tDate.month != _selectedMonth.month || tDate.year != _selectedMonth.year) return false;
      
      if (_filterType != 'all' && t.type != _filterType) return false;
      
      if (_filterStatus == 'paid' && t.status != 'paid') return false;
      if (_filterStatus == 'pending' && t.status != 'pending') return false;
      if (_filterStatus == 'overdue' && t.status != 'overdue') return false;

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
    int qtdeDespesasVencidas = 0;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    for (var t in allTransactions) { // calculando totais do mes
      final tDate = DateTime.tryParse(t.transactionDate);
      if (tDate != null && tDate.month == _selectedMonth.month && tDate.year == _selectedMonth.year) {
        if (t.status == 'canceled') continue; // Movimentação cancelada não deve entrar em nenhum cálculo

        if (t.type == 'income') {
          if (t.status == 'paid') {
            receitasPagas += t.amount;
          } else {
            receitasPendentes += t.amount;
          }
        } else if (t.type == 'expense') {
          if (t.status == 'paid') {
            despesasPagas += t.amount;
          } else {
            despesasPendentes += t.amount;
            final dueDateToUse = t.dueDate != null ? DateTime.tryParse(t.dueDate!) : tDate;
            if (dueDateToUse != null) {
              final dueDateMidnight = DateTime(dueDateToUse.year, dueDateToUse.month, dueDateToUse.day);
              if (t.status == 'pending' && dueDateMidnight.isBefore(today)) {
                qtdeDespesasVencidas++;
              }
            }
          }
        }
      }
    }

    final totalReceitas = receitasPagas + receitasPendentes;
    final totalDespesas = despesasPagas + despesasPendentes;
    final saldoPrevisto = totalReceitas - totalDespesas;
    final saldoRealizado = receitasPagas - despesasPagas;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanças'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_mode),
            onPressed: _generateFixedTransactions,
            tooltip: 'Gerar Recorrentes do Mês Anterior',
          ),
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceCategoriesScreen()));
            },
            tooltip: 'Categorias',
          ),
        ],
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
                  _buildSummaryCard(saldoPrevisto, saldoRealizado, totalReceitas, totalDespesas, qtdeDespesasVencidas),
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
                        _buildFilterChip('Receitas', 'income', _filterType, (v) => setState(() => _filterType = v)),
                        const SizedBox(width: 8),
                        _buildFilterChip('Despesas', 'expense', _filterType, (v) => setState(() => _filterType = v)),
                        const SizedBox(width: 16),
                        _buildFilterChip('Tudo', 'all', _filterStatus, (v) => setState(() => _filterStatus = v)),
                        const SizedBox(width: 8),
                        _buildFilterChip('Pago', 'paid', _filterStatus, (v) => setState(() => _filterStatus = v)),
                        const SizedBox(width: 8),
                        _buildFilterChip('Pendente', 'pending', _filterStatus, (v) => setState(() => _filterStatus = v)),
                        const SizedBox(width: 8),
                        _buildFilterChip('Atrasado', 'overdue', _filterStatus, (v) => setState(() => _filterStatus = v)),
                      ],
                    ),
                  ),
                  if (allCategories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Todas as Categorias'),
                            selected: _filterCategory == null,
                            onSelected: (b) => setState(() => _filterCategory = null),
                          ),
                          const SizedBox(width: 8),
                          ...allCategories.map((c) => Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: ChoiceChip(
                              label: Text(c.name),
                              selected: _filterCategory == c.id,
                              onSelected: (b) => setState(() => _filterCategory = b ? c.id : null),
                            ),
                          )),
                        ],
                      ),
                    ),
                  ],
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
                final isPaid = t.status == 'paid';
                final isCanceled = t.status == 'canceled';
                final cat = allCategories.where((c) => c.id == t.categoryId).firstOrNull;
                final color = cat != null ? Color(int.parse(cat.color)) : (t.type == 'income' ? Colors.green : Colors.red);
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isCanceled ? Colors.grey.withOpacity(0.2) : color.withOpacity(0.2),
                    child: Icon(
                      t.type == 'income' ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isCanceled ? Colors.grey : color,
                    ),
                  ),
                  title: Text(t.title, style: TextStyle(
                    decoration: isCanceled ? TextDecoration.lineThrough : null,
                    color: isCanceled ? Colors.grey : Colors.black87,
                  )),
                  subtitle: Text(
                    '${DateFormat('dd/MM/yyyy').format(DateTime.parse(t.transactionDate))}${cat != null ? ' • ${cat.name}' : ''}'
                  ),
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
                              color: isCanceled ? Colors.grey : (t.type == 'income' ? Colors.green : Colors.red),
                              fontWeight: FontWeight.bold,
                              decoration: isCanceled ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          Text(
                            isCanceled ? 'Cancelado' : (t.status == 'paid' ? 'Efetuado' : (t.status == 'overdue' ? 'Atrasado' : 'Pendente')), 
                            style: TextStyle(
                              color: isCanceled ? Colors.grey : (t.status == 'paid' ? Colors.green : (t.status == 'overdue' ? Colors.red : Colors.orange)), 
                              fontSize: 12
                            )
                          ),
                        ]
                      ),
                      Checkbox(
                        value: isPaid,
                        onChanged: isCanceled ? null : (val) {
                          if (val != null) {
                            final newStatus = val ? 'paid' : 'pending';
                            ref.read(transactionsProvider.notifier).updateTransaction(
                              t.copyWith(
                                status: newStatus,
                                paidDate: val ? DateTime.now().toIso8601String() : null,
                                updatedAt: DateTime.now().toIso8601String(),
                              )
                            );
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
