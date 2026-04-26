import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../data/database/finance_planning_store.dart';
import '../../data/models/financial_account_model.dart';
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
  int? _accountId;
  bool _reminderEnabled = false;
  bool _loadingAccounts = true;
  List<FinancialAccount> _accounts = [];

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
    _loadAccounts();
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
      _accountId = template.accountId;
    }
  }

  Future<void> _loadAccounts() async {
    final db = await ref.read(dbProvider).database;
    final accounts = await FinancePlanningStore.getAccounts(db);
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _loadingAccounts = false;
      if (_accountId != null && !_accounts.any((account) => account.id == _accountId)) _accountId = null;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  bool _canUseReminder() => _status != 'paid' && _status != 'canceled' && (_dueDate != null || _type == 'income');

  void _setType(String value) {
    setState(() {
      _type = value;
      final validCategories = ref.read(financialCategoriesProvider).where((c) => c.type == _type || c.type == 'both').toList();
      if (_categoryId != null && !validCategories.any((category) => category.id == _categoryId)) {
        _categoryId = null;
      }
      if (!_canUseReminder()) _reminderEnabled = false;
    });
  }

  String _statusAfterSave(String currentStatus) {
    if (currentStatus == 'paid' || currentStatus == 'canceled') return currentStatus;
    final expected = _dueDate ?? _transactionDate;
    final due = DateTime(expected.year, expected.month, expected.day);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return due.isBefore(today) ? 'overdue' : 'pending';
  }

  Future<void> _confirmDelete() async {
    if (!_isEditing || widget.transaction?.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir movimentação?'),
        content: Text('Deseja excluir "${widget.transaction!.title}"? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await ref.read(transactionsProvider.notifier).removeTransaction(widget.transaction!.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(financialCategoriesProvider).where((c) => c.type == _type || c.type == 'both').toList();
    final safeCategoryId = categories.any((category) => category.id == _categoryId) ? _categoryId : null;
    final safeAccountId = _accounts.any((account) => account.id == _accountId) ? _accountId : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar Movimentação' : 'Nova Movimentação'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDelete,
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
                onSelectionChanged: (set) => _setType(set.first),
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
                  if (_dueDate != null)
                    IconButton(
                      tooltip: 'Limpar vencimento',
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        _dueDate = null;
                        if (!_canUseReminder()) _reminderEnabled = false;
                      }),
                    ),
                ],
              ),
              SwitchListTile(
                title: const Text('Ativar lembrete local'),
                subtitle: const Text('Para vencimento/receita prevista'),
                value: _canUseReminder() && _reminderEnabled,
                onChanged: _canUseReminder() ? (v) => setState(() => _reminderEnabled = v) : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: safeCategoryId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sem Categoria')),
                  ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
                decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: safeAccountId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sem conta')),
                  ..._accounts.map((account) => DropdownMenuItem(value: account.id, child: Text('${account.name}${account.isArchived ? ' (arquivada)' : ''}'))),
                ],
                onChanged: _loadingAccounts ? null : (v) => setState(() => _accountId = v),
                decoration: InputDecoration(
                  labelText: _status == 'paid' ? 'Conta utilizada (obrigatória)' : 'Conta vinculada',
                  border: const OutlineInputBorder(),
                  helperText: _status == 'paid' ? 'Transações pagas alteram o saldo da conta.' : 'Será usada quando a transação for paga.',
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedPaymentMethod,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Forma de Pagamento (Nenhuma)')),
                  ..._paymentMethods.map((m) => DropdownMenuItem(value: m, child: Text(m.toUpperCase()))),
                ],
                onChanged: (v) => setState(() => _selectedPaymentMethod = v),
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
                      _discountController.clear();
                    }
                    if (!_canUseReminder()) _reminderEnabled = false;
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

  Future<void> _save() async {
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
    if (discount < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O desconto não pode ser negativo.')));
      return;
    }
    if (_status == 'paid' && _accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma conta para marcar a movimentação como paga/efetuada.')));
      return;
    }

    final categories = ref.read(financialCategoriesProvider).where((c) => c.type == _type || c.type == 'both').toList();
    final safeCategoryId = categories.any((category) => category.id == _categoryId) ? _categoryId : null;
    final safeAccountId = _accounts.any((account) => account.id == _accountId) ? _accountId : null;
    final normalizedStatus = _statusAfterSave(_status);
    final canReminder = normalizedStatus != 'paid' && normalizedStatus != 'canceled' && (_dueDate != null || _type == 'income');

    if (normalizedStatus == 'paid' && safeAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A conta selecionada não existe mais. Escolha uma conta válida.')));
      return;
    }

    final transaction = FinancialTransaction(
      id: _isEditing ? template?.id : null,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      amount: amount,
      type: _type,
      transactionDate: _transactionDate.toIso8601String(),
      dueDate: _dueDate?.toIso8601String(),
      paidDate: normalizedStatus == 'paid' ? (_paidDate ?? DateTime.now()).toIso8601String() : null,
      categoryId: safeCategoryId,
      accountId: safeAccountId,
      paymentMethod: _selectedPaymentMethod,
      status: normalizedStatus,
      reminderEnabled: canReminder && _reminderEnabled,
      isFixed: _isFixed,
      recurrenceType: _recurrenceType,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      debtId: template?.debtId,
      installmentNumber: template?.installmentNumber,
      totalInstallments: template?.totalInstallments,
      discountAmount: normalizedStatus == 'paid' && discount > 0 ? discount : null,
      createdAt: _isEditing ? template!.createdAt : DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    if (_isEditing) {
      await ref.read(transactionsProvider.notifier).updateTransaction(transaction);
    } else {
      await ref.read(transactionsProvider.notifier).addTransaction(transaction);
    }
    if (mounted) Navigator.pop(context);
  }
}
