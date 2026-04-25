import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../data/models/transaction_model.dart';

class FinanceScreen extends ConsumerWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsProvider);
    
    double totalReceitas = 0;
    double totalDespesas = 0;
    
    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;

    for (var t in transactions) {
      final tDate = DateTime.tryParse(t.date);
      if (tDate != null && tDate.month == currentMonth && tDate.year == currentYear) {
        if (t.type == 'receita') {
          totalReceitas += t.amount;
        } else if (t.type == 'despesa') {
          totalDespesas += t.amount;
        }
      }
    }

    final saldo = totalReceitas - totalDespesas;

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
                  _buildSummaryCard(saldo, totalReceitas, totalDespesas),
                  const SizedBox(height: 24),
                  const Text('Movimentações Recentes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index >= transactions.length) return null;
                final t = transactions[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: t.type == 'receita' ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    child: Icon(
                      t.type == 'receita' ? Icons.arrow_upward : Icons.arrow_downward,
                      color: t.type == 'receita' ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(t.title),
                  subtitle: Text(t.date.split('T')[0]),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${t.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: t.type == 'receita' ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (!t.isPaid)
                        const Text('Pendente', style: TextStyle(color: Colors.orange, fontSize: 12)),
                    ],
                  ),
                  onTap: () {
                    // TODO: open edit
                  },
                );
              },
              childCount: transactions.length,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: open add transaction
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTransactionScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryCard(double saldo, double receitas, double despesas) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const Text('Saldo Atual', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(
              '\$${saldo.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: saldo >= 0 ? Colors.green : Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStat('Receitas', receitas, Colors.green),
                _buildStat('Despesas', despesas, Colors.red),
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
        Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

class CreateTransactionScreen extends ConsumerStatefulWidget {
  const CreateTransactionScreen({super.key});

  @override
  ConsumerState<CreateTransactionScreen> createState() => _CreateTransactionScreenState();
}

class _CreateTransactionScreenState extends ConsumerState<CreateTransactionScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _type = 'despesa';
  DateTime _date = DateTime.now();
  bool _isPaid = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nova Movimentação')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'receita', label: Text('Receita')),
                ButtonSegment(value: 'despesa', label: Text('Despesa')),
              ],
              selected: {_type},
              onSelectionChanged: (set) {
                setState(() => _type = set.first);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              decoration: const InputDecoration(labelText: 'Valor'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Pago / Recebido'),
              value: _isPaid,
              onChanged: (val) => setState(() => _isPaid = val),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(_amountController.text) ?? 0.0;
                if (_titleController.text.isNotEmpty && amount > 0) {
                  final t = FinancialTransaction(
                    title: _titleController.text,
                    amount: amount,
                    type: _type,
                    date: _date.toIso8601String(),
                    isPaid: _isPaid,
                    createdAt: DateTime.now().toIso8601String(),
                  );
                  ref.read(transactionsProvider.notifier).addTransaction(t);
                  Navigator.pop(context);
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }
}
