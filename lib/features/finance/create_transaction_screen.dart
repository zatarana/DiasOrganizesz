import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/providers.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/category_model.dart';

class CreateTransactionScreen extends ConsumerStatefulWidget {
  final FinancialTransaction? transaction;
  const CreateTransactionScreen({super.key, this.transaction});

  @override
  ConsumerState<CreateTransactionScreen> createState() => _CreateTransactionScreenState();
}

class _CreateTransactionScreenState extends ConsumerState<CreateTransactionScreen> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _paymentMethodController = TextEditingController();
  String _type = 'despesa';
  DateTime _date = DateTime.now();
  DateTime? _dueDate;
  bool _isPaid = false;
  bool _isFixed = false;
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _titleController.text = widget.transaction!.title;
      _amountController.text = widget.transaction!.amount.toString();
      _paymentMethodController.text = widget.transaction!.paymentMethod ?? '';
      _type = widget.transaction!.type;
      _date = DateTime.parse(widget.transaction!.date);
      if (widget.transaction!.dueDate != null) {
        _dueDate = DateTime.parse(widget.transaction!.dueDate!);
      }
      _isPaid = widget.transaction!.isPaid;
      _isFixed = widget.transaction!.isFixed;
      _categoryId = widget.transaction!.categoryId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transaction == null ? 'Nova Movimentação' : 'Editar Movimentação'),
        actions: [
          if (widget.transaction != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Excluir?'),
                    content: const Text('Deseja realmente excluir esta movimentação?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                      TextButton(
                        onPressed: () {
                          ref.read(transactionsProvider.notifier).removeTransaction(widget.transaction!.id!);
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                        },
                        child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  )
                );
              },
            )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'receita', label: Text('Receita', style: TextStyle(color: Colors.green))),
                  ButtonSegment(value: 'despesa', label: Text('Despesa', style: TextStyle(color: Colors.red))),
                ],
                selected: {_type},
                onSelectionChanged: (set) {
                  setState(() => _type = set.first);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Valor (R\$)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final dt = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if(dt != null) setState(() => _date = dt);
                      },
                      child: Text('Data: ${DateFormat('dd/MM/yyyy').format(_date)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final dt = await showDatePicker(context: context, initialDate: _dueDate ?? _date, firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if(dt != null) setState(() => _dueDate = dt);
                      },
                      child: Text(_dueDate == null ? 'Vencimento: -' : 'Venc. ${DateFormat('dd/MM/yyyy').format(_dueDate!)}'),
                    ),
                  )
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: _categoryId,
                items: [
                   const DropdownMenuItem(value: null, child: Text('Sem Categoria')),
                   ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState( ()=> _categoryId = v),
                decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _paymentMethodController,
                decoration: const InputDecoration(labelText: 'Forma de Pagamento (ex: PIX, Cartão)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: Text(_type == 'receita' ? 'Foi recebido?' : 'Foi pago?'),
                subtitle: Text(_isPaid ? 'Sim' : 'Não (Pendente)'),
                value: _isPaid,
                onChanged: (val) => setState(() => _isPaid = val),
              ),
              SwitchListTile(
                title: const Text('Lançamento fixo?'),
                subtitle: Text(_isFixed ? 'Mensal' : 'Avulso'),
                value: _isFixed,
                onChanged: (val) => setState(() => _isFixed = val),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () {
                  final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
                  if (_titleController.text.isNotEmpty && amount > 0) {
                    final t = FinancialTransaction(
                      id: widget.transaction?.id,
                      title: _titleController.text,
                      amount: amount,
                      type: _type,
                      date: _date.toIso8601String(),
                      dueDate: _dueDate?.toIso8601String(),
                      categoryId: _categoryId,
                      paymentMethod: _paymentMethodController.text,
                      isPaid: _isPaid,
                      isFixed: _isFixed,
                      createdAt: widget.transaction?.createdAt ?? DateTime.now().toIso8601String(),
                    );
                    if (widget.transaction == null) {
                      ref.read(transactionsProvider.notifier).addTransaction(t);
                    } else {
                      ref.read(transactionsProvider.notifier).updateTransaction(t);
                    }
                    Navigator.pop(context);
                  }
                },
                child: Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
