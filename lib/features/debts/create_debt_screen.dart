import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/providers.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/transaction_model.dart';

enum DebtEntryMode { total, installments }

class CreateDebtScreen extends ConsumerStatefulWidget {
  final Debt? debt;
  const CreateDebtScreen({super.key, this.debt});

  @override
  ConsumerState<CreateDebtScreen> createState() => _CreateDebtScreenState();
}

class _CreateDebtScreenState extends ConsumerState<CreateDebtScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _installmentsController = TextEditingController();
  final _installmentAmountController = TextEditingController();
  final _creditorController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _startDate = DateTime.now();
  DateTime _firstDueDate = DateTime.now().add(const Duration(days: 30));
  int? _selectedCategoryId;

  DebtEntryMode _entryMode = DebtEntryMode.total;
  bool _generateInstallments = false;
  bool _remindInstallments = false;
  bool _isAutoCalculating = false;
  bool _installmentWasAutoCalculated = true;

  @override
  void initState() {
    super.initState();
    if (widget.debt == null) {
      final settings = ref.read(appSettingsProvider);
      _remindInstallments = (settings[AppSettingKeys.debtsRemindersDefault] ?? 'false') == 'true';
    }
    if (widget.debt != null) {
      _nameController.text = widget.debt!.name;
      _descriptionController.text = widget.debt!.description ?? '';
      _creditorController.text = widget.debt!.creditorName ?? '';
      _notesController.text = widget.debt!.notes ?? '';
      _selectedCategoryId = widget.debt!.categoryId;
      _amountController.text = widget.debt!.totalAmount.toStringAsFixed(2);
      if (widget.debt!.installmentCount != null) _installmentsController.text = widget.debt!.installmentCount!.toString();
      if (widget.debt!.installmentAmount != null) _installmentAmountController.text = widget.debt!.installmentAmount!.toStringAsFixed(2);
      if (widget.debt!.startDate != null) _startDate = DateTime.tryParse(widget.debt!.startDate!) ?? DateTime.now();
      if (widget.debt!.firstDueDate != null) _firstDueDate = DateTime.tryParse(widget.debt!.firstDueDate!) ?? DateTime.now().add(const Duration(days: 30));
      _installmentWasAutoCalculated = false;
    }

    _amountController.addListener(_recalculateAuto);
    _installmentsController.addListener(_recalculateAuto);
    _installmentAmountController.addListener(() {
      if (!_isAutoCalculating) {
        _installmentWasAutoCalculated = false;
        if (_entryMode == DebtEntryMode.installments) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _installmentsController.dispose();
    _installmentAmountController.dispose();
    _creditorController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _recalculateAuto() {
    if (_isAutoCalculating) return;

    final amount = _parseMoney(_amountController.text);
    final instCount = int.tryParse(_installmentsController.text) ?? 0;
    final instAmount = _parseMoney(_installmentAmountController.text);

    if (_entryMode == DebtEntryMode.total) {
      if (amount > 0 && instCount > 0 && (_installmentAmountController.text.isEmpty || _installmentWasAutoCalculated)) {
        _isAutoCalculating = true;
        _installmentAmountController.text = (amount / instCount).toStringAsFixed(2);
        _installmentWasAutoCalculated = true;
        _isAutoCalculating = false;
      }
    } else if (_entryMode == DebtEntryMode.installments && instCount > 0 && instAmount > 0) {
      _isAutoCalculating = true;
      _amountController.text = _roundCents(instCount * instAmount).toStringAsFixed(2);
      _isAutoCalculating = false;
    }

    if (mounted) setState(() {});
  }

  void _setEntryMode(DebtEntryMode mode) {
    if (_entryMode == mode) return;
    setState(() {
      _entryMode = mode;
      _installmentWasAutoCalculated = true;
      if (mode == DebtEntryMode.installments) {
        final installments = int.tryParse(_installmentsController.text) ?? 0;
        final installmentAmount = _parseMoney(_installmentAmountController.text);
        if (installments > 0 && installmentAmount > 0) {
          _amountController.text = _roundCents(installments * installmentAmount).toStringAsFixed(2);
        } else {
          _amountController.clear();
        }
      } else {
        _recalculateAuto();
      }
    });
  }

  double _parseMoney(String text) => double.tryParse(text.replaceAll(',', '.')) ?? 0.0;

  double _roundCents(double value) => double.parse(value.toStringAsFixed(2));

  double _calculatedTotal() {
    if (_entryMode == DebtEntryMode.installments) {
      final installments = int.tryParse(_installmentsController.text) ?? 0;
      final installmentAmount = _parseMoney(_installmentAmountController.text);
      return _roundCents(installments * installmentAmount);
    }
    return _roundCents(_parseMoney(_amountController.text));
  }

  DateTime _safeMonthlyDueDate(DateTime firstDate, int monthOffset) {
    final targetMonth = firstDate.month + monthOffset;
    final base = DateTime(firstDate.year, targetMonth, 1);
    final lastDay = DateUtils.getDaysInMonth(base.year, base.month);
    final day = firstDate.day > lastDay ? lastDay : firstDate.day;
    return DateTime(base.year, base.month, day);
  }

  List<double> _buildInstallmentAmounts(double total, int count, double typedAmount) {
    if (count <= 0) return const [];
    final amounts = <double>[];
    double accumulated = 0;
    final baseAmount = typedAmount > 0 ? typedAmount : _roundCents(total / count);

    for (int i = 0; i < count; i++) {
      final isLast = i == count - 1;
      final value = isLast ? _roundCents(total - accumulated) : _roundCents(baseAmount);
      amounts.add(value < 0 ? 0 : value);
      accumulated += value;
    }

    return amounts;
  }

  Future<void> _confirmDeleteDebt() async {
    final debt = widget.debt;
    if (debt?.id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir dívida?'),
        content: const Text('As parcelas vinculadas serão desvinculadas no financeiro. Esta ação não pode ser desfeita.'),
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
    await ref.read(debtsProvider.notifier).removeDebt(debt!.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(financialCategoriesProvider).where((c) => c.type == 'expense' || c.type == 'both').toList();
    final safeCategoryId = categories.any((category) => category.id == _selectedCategoryId) ? _selectedCategoryId : null;
    final totalPreview = _calculatedTotal();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.debt == null ? 'Nova Dívida' : 'Detalhes/Editar Dívida'),
        actions: [
          if (widget.debt != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _confirmDeleteDebt,
            )
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Obrigatórios', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nome da dívida (Ex: Cartão, Empréstimo)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              SegmentedButton<DebtEntryMode>(
                segments: const [
                  ButtonSegment(value: DebtEntryMode.total, label: Text('Valor total'), icon: Icon(Icons.payments_outlined)),
                  ButtonSegment(value: DebtEntryMode.installments, label: Text('Parcelas'), icon: Icon(Icons.format_list_numbered)),
                ],
                selected: {_entryMode},
                onSelectionChanged: (selection) => _setEntryMode(selection.first),
              ),
              const SizedBox(height: 8),
              Text(
                _entryMode == DebtEntryMode.total
                    ? 'Cadastre a dívida informando o valor total. Se gerar parcelas, o app calcula o valor aproximado de cada uma.'
                    : 'Cadastre a dívida pela quantidade de parcelas e pelo valor de cada parcela. O total será calculado automaticamente.',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              const SizedBox(height: 16),
              if (_entryMode == DebtEntryMode.total) ...[
                TextField(
                  controller: _amountController,
                  decoration: const InputDecoration(labelText: 'Valor Total (R\$)', border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _installmentsController,
                  decoration: const InputDecoration(
                    labelText: 'Qtde Parcelas (opcional)',
                    helperText: 'Obrigatória apenas se você gerar parcelas no Financeiro.',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                if (_installmentsController.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _installmentAmountController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Valor estimado da parcela',
                      helperText: 'Calculado a partir do valor total informado.',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _installmentsController,
                        decoration: const InputDecoration(labelText: 'Qtde Parcelas', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _installmentAmountController,
                        decoration: const InputDecoration(labelText: 'Valor da Parcela', border: OutlineInputBorder()),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Valor total calculado (R\$)',
                    helperText: 'Quantidade de parcelas × valor da parcela.',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
              const SizedBox(height: 12),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.calculate_outlined, color: Theme.of(context).colorScheme.onPrimaryContainer),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Valor total da dívida: R\$ ${totalPreview.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimaryContainer),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Categoria Financeira', border: OutlineInputBorder()),
                initialValue: safeCategoryId,
                items: [
                  const DropdownMenuItem<int>(value: null, child: Text('Selecione uma categoria (Obrigatório)')),
                  ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (val) => setState(() => _selectedCategoryId = val),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final dt = await showDatePicker(
                    context: context,
                    initialDate: _firstDueDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (dt != null) setState(() => _firstDueDate = dt);
                },
                icon: const Icon(Icons.calendar_month),
                label: Text('Data da 1ª Parcela: ${DateFormat('dd/MM/yyyy').format(_firstDueDate)}'),
              ),
              const SizedBox(height: 32),
              const Text('Opcionais', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (widget.debt == null) ...[
                SwitchListTile(
                  title: const Text('Gerar parcelas no Financeiro?'),
                  subtitle: const Text('Cria automaticamente despesas no módulo Financeiro para esta dívida.'),
                  value: _generateInstallments,
                  onChanged: (v) => setState(() => _generateInstallments = v),
                ),
                SwitchListTile(
                  title: const Text('Lembrar parcelas automaticamente?'),
                  subtitle: const Text('Agenda lembrete local para vencimento de cada parcela'),
                  value: _generateInstallments && _remindInstallments,
                  onChanged: _generateInstallments ? (v) => setState(() => _remindInstallments = v) : null,
                ),
                const SizedBox(height: 16),
              ],
              OutlinedButton.icon(
                onPressed: () async {
                  final dt = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (dt != null) setState(() => _startDate = dt);
                },
                icon: const Icon(Icons.calendar_today),
                label: Text('Data de Início/Contratação: ${DateFormat('dd/MM/yyyy').format(_startDate)}'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _creditorController,
                decoration: const InputDecoration(labelText: 'Credor (Banco, Loja, Pessoa)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descrição rápida', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Observações avançadas (Opcional)', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: _saveDebt,
                child: const Text('Salvar Dívida'),
              )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveDebt() async {
    final name = _nameController.text.trim();
    final amount = _calculatedTotal();
    final installments = int.tryParse(_installmentsController.text) ?? 0;
    final instAmount = _roundCents(_parseMoney(_installmentAmountController.text));
    final categories = ref.read(financialCategoriesProvider).where((c) => c.type == 'expense' || c.type == 'both').toList();
    final safeCategoryId = categories.any((category) => category.id == _selectedCategoryId) ? _selectedCategoryId : null;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O nome é obrigatório.')));
      return;
    }
    if (safeCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A categoria financeira é obrigatória.')));
      return;
    }
    if (_entryMode == DebtEntryMode.total) {
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O valor total deve ser maior que zero.')));
        return;
      }
      if (_generateInstallments && installments <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe a quantidade de parcelas para gerar no Financeiro.')));
        return;
      }
    } else {
      if (installments <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe a quantidade de parcelas.')));
        return;
      }
      if (instAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o valor da parcela.')));
        return;
      }
      if (amount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O valor total calculado deve ser maior que zero.')));
        return;
      }
    }

    final normalizedInstallmentCount = installments > 0 ? installments : null;
    final normalizedInstallmentAmount = normalizedInstallmentCount == null ? null : _roundCents(amount / normalizedInstallmentCount);

    final debt = Debt(
      id: widget.debt?.id,
      name: name,
      totalAmount: amount,
      installmentCount: normalizedInstallmentCount,
      installmentAmount: normalizedInstallmentAmount,
      startDate: _startDate.toIso8601String(),
      firstDueDate: _firstDueDate.toIso8601String(),
      categoryId: safeCategoryId,
      description: _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
      notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      creditorName: _creditorController.text.trim().isNotEmpty ? _creditorController.text.trim() : null,
      status: widget.debt?.status ?? 'active',
      createdAt: widget.debt?.createdAt ?? DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    if (widget.debt == null) {
      await ref.read(debtsProvider.notifier).addDebt(debt);
      final createdDebt = ref.read(debtsProvider).firstWhere((d) => d.name == name && d.createdAt == debt.createdAt);

      if (_generateInstallments && normalizedInstallmentCount != null) {
        final amounts = _buildInstallmentAmounts(amount, normalizedInstallmentCount, normalizedInstallmentAmount ?? 0);
        for (int i = 0; i < normalizedInstallmentCount; i++) {
          final due = _safeMonthlyDueDate(_firstDueDate, i);
          final now = DateTime.now().toIso8601String();
          final transaction = FinancialTransaction(
            title: '$name (Parcela ${i + 1}/$normalizedInstallmentCount)',
            amount: amounts[i],
            type: 'expense',
            categoryId: safeCategoryId,
            transactionDate: due.toIso8601String(),
            dueDate: due.toIso8601String(),
            status: 'pending',
            reminderEnabled: _generateInstallments && _remindInstallments,
            isFixed: false,
            recurrenceType: 'none',
            debtId: createdDebt.id,
            installmentNumber: i + 1,
            totalInstallments: normalizedInstallmentCount,
            createdAt: now,
            updatedAt: now,
          );
          await ref.read(transactionsProvider.notifier).addTransaction(transaction);
        }
      }
    } else {
      await ref.read(debtsProvider.notifier).updateDebt(debt);
    }

    if (mounted) Navigator.pop(context);
  }
}
