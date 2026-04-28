import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/finance_planning_store.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/financial_account_model.dart';
import '../../data/models/transaction_model.dart';
import '../../domain/providers.dart';

const String defaultFinancialAccountSettingKey = 'default_financial_account_id';

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
  bool get _isDebtInstallment => widget.transaction?.debtId != null;

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

      _type = template.debtId != null ? 'expense' : template.type;
      _transactionDate = DateTime.tryParse(template.transactionDate) ?? DateTime.now();
      if (template.dueDate != null) _dueDate = DateTime.tryParse(template.dueDate!);
      if (template.paidDate != null) _paidDate = DateTime.tryParse(template.paidDate!);
      _status = template.status;
      _reminderEnabled = template.reminderEnabled;
      _isFixed = template.debtId != null ? false : template.isFixed;
      _recurrenceType = template.debtId != null ? 'none' : template.recurrenceType;
      _categoryId = template.categoryId;
      _accountId = template.accountId;
    }
  }

  Future<void> _loadAccounts() async {
    final dbHelper = ref.read(dbProvider);
    final db = await dbHelper.database;
    final accounts = await FinancePlanningStore.getAccounts(db);
    final defaultAccountSetting = await dbHelper.getSetting(defaultFinancialAccountSettingKey);
    final defaultAccountId = int.tryParse(defaultAccountSetting?.value ?? '');

    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _loadingAccounts = false;
      if (_accountId != null && !_accounts.any((account) => account.id == _accountId)) _accountId = null;
      if (_accountId == null && defaultAccountId != null && _accounts.any((account) => account.id == defaultAccountId && !account.isArchived)) {
        _accountId = defaultAccountId;
      }
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

  List<FinancialAccount> _selectableAccounts() {
    return _accounts.where((account) => !account.isArchived || account.id == widget.transaction?.accountId).toList();
  }

  Debt? _linkedDebt(List<Debt> debts) {
    final debtId = widget.transaction?.debtId;
    if (debtId == null) return null;
    for (final debt in debts) {
      if (debt.id == debtId) return debt;
    }
    return null;
  }

  void _setType(String value) {
    if (_isDebtInstallment) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parcelas de dívida permanecem como despesa.')));
      return;
    }

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
        title: Text(_isDebtInstallment ? 'Excluir parcela da dívida?' : 'Excluir movimentação?'),
        content: Text(
          _isDebtInstallment
              ? 'Deseja excluir esta parcela? A dívida vinculada será recalculada com base nas parcelas restantes.'
              : 'Deseja excluir "${widget.transaction!.title}"? Esta ação não pode ser desfeita.',
        ),
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
    final linkedDebt = _linkedDebt(ref.watch(debtsProvider));
    final categories = ref.watch(financialCategoriesProvider).where((c) => c.type == _type || c.type == 'both').toList();
    final selectableAccounts = _selectableAccounts();
    final safeCategoryId = categories.any((category) => category.id == _categoryId) ? _categoryId : null;
    final safeAccountId = selectableAccounts.any((account) => account.id == _accountId) ? _accountId : null;

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
              Opacity(
                opacity: _isDebtInstallment ? 0.65 : 1,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'income', label: Text('Receita', style: TextStyle(color: Colors.green))),
                    ButtonSegment(value: 'expense', label: Text('Despesa', style: TextStyle(color: Colors.red))),
                  ],
                  selected: {_type},
                  onSelectionChanged: (set) => _setType(set.first),
                ),
              ),
              if (_isDebtInstallment) ...[
                const SizedBox(height: 12),
                _DebtInstallmentInfoCard(transaction: widget.transaction!, debt: linkedDebt),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Título',
                  border: const OutlineInputBorder(),
                  helperText: _isDebtInstallment ? 'Esta movimentação é uma parcela vinculada à aba Dívidas.' : null,
                ),
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
                decoration: InputDecoration(
                  labelText: 'Valor (R\$)',
                  border: const OutlineInputBorder(),
                  helperText: _isDebtInstallment ? 'Alterar o valor afeta o abatimento e o saldo restante da dívida.' : null,
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              if (_status == 'paid') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _discountController,
                  decoration: InputDecoration(
                    labelText: _isDebtInstallment ? 'Desconto / Abatimento extra (R\$)' : 'Desconto / Economia gerada (R\$)',
                    border: const OutlineInputBorder(),
                    hintText: _isDebtInstallment ? 'Ex: desconto por antecipar parcela' : (_type == 'expense' ? 'Desconto por pagar antecipado' : 'Desconto concedido'),
                    helperText: _isDebtInstallment ? 'O desconto também abate o saldo restante da dívida.' : null,
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
                subtitle: Text(_isDebtInstallment ? 'Lembrete da parcela vinculada à dívida' : 'Para vencimento/receita prevista'),
                value: _canUseReminder() && _reminderEnabled,
                onChanged: _canUseReminder() ? (v) => setState(() => _reminderEnabled = v) : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: safeCategoryId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sem Categoria')),
                  ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
                decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: safeAccountId,
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sem conta')),
                  ...selectableAccounts.map((account) => DropdownMenuItem(value: account.id, child: Text('${account.name}${account.isArchived ? ' (arquivada)' : ''}'))),
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
                subtitle: Text(_isDebtInstallment ? 'Parcelas de dívida não usam recorrência fixa manual' : (_isFixed ? 'Sim' : 'Não')),
                value: !_isDebtInstallment && _isFixed,
                onChanged: _isDebtInstallment
                    ? null
                    : (val) {
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
    final selectableAccounts = _selectableAccounts();
    final effectiveType = _isDebtInstallment ? 'expense' : _type;

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

    final categories = ref.read(financialCategoriesProvider).where((c) => c.type == effectiveType || c.type == 'both').toList();
    final safeCategoryId = categories.any((category) => category.id == _categoryId) ? _categoryId : null;
    final safeAccountId = selectableAccounts.any((account) => account.id == _accountId) ? _accountId : null;
    final normalizedStatus = _statusAfterSave(_status);
    final canReminder = normalizedStatus != 'paid' && normalizedStatus != 'canceled' && (_dueDate != null || effectiveType == 'income');

    if (normalizedStatus == 'paid' && safeAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A conta selecionada não está disponível. Escolha uma conta ativa.')));
      return;
    }

    final transaction = FinancialTransaction(
      id: _isEditing ? template?.id : null,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      amount: amount,
      type: effectiveType,
      transactionDate: _transactionDate.toIso8601String(),
      dueDate: _dueDate?.toIso8601String(),
      paidDate: normalizedStatus == 'paid' ? (_paidDate ?? DateTime.now()).toIso8601String() : null,
      categoryId: safeCategoryId,
      accountId: safeAccountId,
      paymentMethod: _selectedPaymentMethod,
      status: normalizedStatus,
      reminderEnabled: canReminder && _reminderEnabled,
      isFixed: _isDebtInstallment ? false : _isFixed,
      recurrenceType: _isDebtInstallment ? 'none' : _recurrenceType,
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

class _DebtInstallmentInfoCard extends StatelessWidget {
  final FinancialTransaction transaction;
  final Debt? debt;

  const _DebtInstallmentInfoCard({required this.transaction, required this.debt});

  @override
  Widget build(BuildContext context) {
    final installment = transaction.installmentNumber == null
        ? 'Parcela vinculada'
        : 'Parcela ${transaction.installmentNumber}/${transaction.totalInstallments ?? '-'}';

    return Card(
      color: Colors.deepOrange.withOpacity(0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.money_off, color: Colors.deepOrange),
                SizedBox(width: 8),
                Expanded(child: Text('Parcela de dívida', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
            const SizedBox(height: 8),
            Text(debt == null ? 'Dívida vinculada não encontrada. A parcela será mantida como despesa.' : 'Dívida: ${debt!.name}'),
            if (debt?.creditorName != null && debt!.creditorName!.isNotEmpty) Text('Credor: ${debt!.creditorName}'),
            Text(installment),
            const SizedBox(height: 8),
            Text(
              'Ao marcar como paga, o valor e eventual desconto serão usados para abater o saldo restante da dívida.',
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
