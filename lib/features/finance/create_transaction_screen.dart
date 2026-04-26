import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/providers.dart';
import '../../data/models/transaction_model.dart';

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
  final _discountController = TextEditingController();
  String _type = 'expense';
  DateTime _transactionDate = DateTime.now();
  DateTime? _dueDate;
  DateTime? _paidDate;
  String _status = 'pending';
  bool _isFixed = false;
  String _recurrenceType = 'none';
  int? _categoryId;
  bool _reminderEnabled = false;

  bool get _isEditing => widget.transaction?.id != null;

  final List<String> _paymentMethods = [
    'dinheiro',
    'pix',
    'cartão de débito',
    'cartão de crédito',
    'boleto',
    'transferência',
    'outro',
  ];
  String? _selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    final template = widget.transaction;
    if (template != null) {
      _titleController.text = template.title;
      _descriptionController.text = template.description ?? '';
      _notesController.text = template.notes ?? '';
      if (template.discountAmount != null && template.discountAmount! > 0) {
        _discountController.text = template.discountAmount!.toStringAsFixed(2);
      }
      _amountController.text = template.amount > 0 ? template.amount.toStringAsFixed(2) : '';

      if (_paymentMethods.contains(template.paymentMethod?.toLowerCase())) {
        _selectedPaymentMethod = template.paymentMethod?.toLowerCase();
      } else if (template.paymentMethod != null && template.paymentMethod!.isNotEmpty) {
        _selectedPaymentMethod = 'outro';
      }

      _type = template.type;
      _transactionDate = DateTime.tryParse(template.transactionDate) ?? DateTime.now();
      if (template.dueDate != null) _dueDate = DateTime.tryParse(template.dueDate!);
      if (template.paidDate != null) _paidDate = DateTime.tryParse(template.paidDate!);
      _status = template.status;
      _reminderEnabled = template.reminderEnabled;
      _isFixed = template.isFixed;
      _recurrenceType = template.recurrenceType;
      _categoryId = template.categoryId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(financialCategoriesProvider).where((c) => c.type == _type || c.type == 'both').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Movimentação' : 'Nova Movimentação'),
        actions: [
          if (_isEditing)
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
                        onPressed: () async {
                          await ref.read(transactionsProvider.notifier).removeTransaction(widget.transaction!.id!);
                          if (context.mounted) {
                            Navigator.pop(ctx);
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
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
                onSelectionChanged: (set) => setState(() => _type = set.first),
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
              if (_status == 'paid') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _discountController,
                  decoration: InputDecoration(
                    labelText: 'Desconto / Economia gerada (R\$)',
                    border: const OutlineInputBorder(),
                    hintText: _type == 'expense' ? 'Desconto por pagar antecipado' : 'Desconto concedido',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final dt = await showDatePicker(context: context, initialDate: _transactionDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (dt != null) setState(() => _transactionDate = dt);
                      },
                      child: Text('Data: ${DateFormat('dd/MM/yyyy').format(_transactionDate)}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        final dt = await showDatePicker(context: context, initialDate: _dueDate ?? _transactionDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                        if (dt != null) setState(() => _dueDate = dt);
                      },
                      child: Text(_dueDate == null ? 'Vencimento: -' : 'Venc. ${DateFormat('dd/MM/yyyy').format(_dueDate!)}'),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                title: const Text('Ativar lembrete local'),
                subtitle: const Text('Para vencimento/receita prevista'),
                value: _reminderEnabled,
                onChanged: (_dueDate != null || _type == 'income') ? (v) => setState(() => _reminderEnabled = v) : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _categoryId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sem Categoria')),
                  ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
                decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedPaymentMethod,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Forma de Pagamento (Nenhuma)')),
                  ..._paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m.toUpperCase()))),
                ],
                onChanged: (v) => setState(() => _selectedPaymentMethod = v),
                decoration: const InputDecoration(labelText: 'Forma de Pagamento', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
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
                onPressed: _save,
                child: const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    final discount = double.tryParse(_discountController.text.replaceAll(',', '.')) ?? 0.0;
    final template = widget.transaction;

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O título é obrigatório.')));
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O valor deve ser maior que zero.')));
      return;
    }

    final transaction = FinancialTransaction(
      id: _isEditing ? template?.id : null,
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
      reminderEnabled: _reminderEnabled,
      isFixed: _isFixed,
      recurrenceType: _recurrenceType,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      debtId: template?.debtId,
      installmentNumber: template?.installmentNumber,
      totalInstallments: template?.totalInstallments,
      discountAmount: discount > 0 ? discount : null,
      createdAt: _isEditing ? template!.createdAt : DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    if (_isEditing) {
      ref.read(transactionsProvider.notifier).updateTransaction(transaction);
    } else {
      ref.read(transactionsProvider.notifier).addTransaction(transaction);
    }
    Navigator.pop(context);
  }
}
