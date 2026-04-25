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
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  String _type = 'expense';
  DateTime _transactionDate = DateTime.now();
  DateTime? _dueDate;
  DateTime? _paidDate;
  String _status = 'pending';
  bool _isFixed = false;
  String _recurrenceType = 'none';
  int? _categoryId;

  // Available Payment Methods
  final List<String> _paymentMethods = [
    'dinheiro', 'pix', 'cartão de débito', 'cartão de crédito', 'boleto', 'transferência', 'outro'
  ];
  String? _selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _titleController.text = widget.transaction!.title;
      _descriptionController.text = widget.transaction!.description ?? '';
      _notesController.text = widget.transaction!.notes ?? '';
      _amountController.text = widget.transaction!.amount.toStringAsFixed(2);
      
      if (_paymentMethods.contains(widget.transaction!.paymentMethod?.toLowerCase())) {
        _selectedPaymentMethod = widget.transaction!.paymentMethod?.toLowerCase();
      } else if (widget.transaction!.paymentMethod != null && widget.transaction!.paymentMethod!.isNotEmpty) {
        _selectedPaymentMethod = 'outro'; // Map unknown to outro
      }

      _type = widget.transaction!.type;
      _transactionDate = DateTime.parse(widget.transaction!.transactionDate);
      if (widget.transaction!.dueDate != null) {
        _dueDate = DateTime.parse(widget.transaction!.dueDate!);
      }
      if (widget.transaction!.paidDate != null) {
        _paidDate = DateTime.parse(widget.transaction!.paidDate!);
      }
      _status = widget.transaction!.status;
      _isFixed = widget.transaction!.isFixed;
      _recurrenceType = widget.transaction!.recurrenceType;
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
                  ButtonSegment(value: 'income', label: Text('Receita', style: TextStyle(color: Colors.green))),
                  ButtonSegment(value: 'expense', label: Text('Despesa', style: TextStyle(color: Colors.red))),
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
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder()),
                maxLines: 2,
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
                        final dt = await showDatePicker(context: context, initialDate: _transactionDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if(dt != null) setState(() => _transactionDate = dt);
                      },
                      child: Text('Data: ${DateFormat('dd/MM/yyyy').format(_transactionDate)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final dt = await showDatePicker(context: context, initialDate: _dueDate ?? _transactionDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
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
              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Forma de Pagamento (Nenhuma)')),
                  ..._paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m.toUpperCase()))),
                ],
                onChanged: (v) => setState( ()=> _selectedPaymentMethod = v),
                decoration: const InputDecoration(labelText: 'Forma de Pagamento', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _status,
                items: const [
                  DropdownMenuItem(value: 'pending', child: Text('Pendente')),
                  DropdownMenuItem(value: 'paid', child: Text('Efetuado / Pago')),
                  DropdownMenuItem(value: 'overdue', child: Text('Em Atraso')),
                  DropdownMenuItem(value: 'canceled', child: Text('Cancelado')),
                ],
                onChanged: (v) {
                  setState(() {
                     _status = v!;
                     if (_status == 'paid') {
                       _paidDate ??= DateTime.now();
                     } else {
                       _paidDate = null;
                     }
                  });
                },
                decoration: const InputDecoration(labelText: 'Status Atual', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Lançamento fixo mensal?'),
                subtitle: Text(_isFixed ? 'Sim' : 'Não'),
                value: _isFixed,
                onChanged: (val) {
                  setState(() {
                    _isFixed = val;
                    _recurrenceType = val ? 'monthly' : 'none';
                  });
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Observações (Opcional)', border: OutlineInputBorder()),
                maxLines: 3,
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
                      description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
                      amount: amount,
                      type: _type,
                      transactionDate: _transactionDate.toIso8601String(),
                      dueDate: _dueDate?.toIso8601String(),
                      paidDate: _paidDate?.toIso8601String(),
                      categoryId: _categoryId,
                      paymentMethod: _selectedPaymentMethod,
                      status: _status,
                      isFixed: _isFixed,
                      recurrenceType: _recurrenceType,
                      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
                      createdAt: widget.transaction?.createdAt ?? DateTime.now().toIso8601String(),
                      updatedAt: DateTime.now().toIso8601String(),
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
