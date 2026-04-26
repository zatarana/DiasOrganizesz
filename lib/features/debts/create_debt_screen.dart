import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/providers.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/transaction_model.dart';

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
      if (!_isAutoCalculating) _installmentWasAutoCalculated = false;
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

    if (amount > 0 && instCount > 0 && (_installmentAmountController.text.isEmpty || _installmentWasAutoCalculated)) {
      _isAutoCalculating = true;
      _installmentAmountController.text = (amount / instCount).toStringAsFixed(2);
      _installmentWasAutoCalculated = true;
      _isAutoCalculating = false;
    }
  }

  double _parseMoney(String text) => double.tryParse(text.replaceAll(',', '.')) ?? 0.0;

  double _roundCents(double value) => double.parse(value.toStringAsFixed(2));

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

    for (int i = 0; i < count; i++) {
      final isLast = i == count - 1;
      final value = isLast ? _roundCents(total - accumulated) : _roundCents(typedAmount);
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
              TextField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Valor Total (R\$)', border: OutlineInputBorder()),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
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
    final amount = _roundCents(_parseMoney(_amountController.text));
    final installments = int.tryParse(_installmentsController.text) ?? 0;
    final instAmount = _roundCents(_parseMoney(_installmentAmountController.text));
    final categories = ref.read(financialCategoriesProvider).where((c) => c.type == 'expense' || c.type == 'both').toList();
    final safeCategoryId = categories.any((category) => category.id == _selectedCategoryId) ? _selectedCategoryId : null;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O nome é obrigatório.')));
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O valor total deve ser maior que zero.')));
      return;
    }
    if (safeCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A categoria financeira é obrigatória.')));
      return;
    }
    if (_generateInstallments || installments > 0 || instAmount > 0) {
      if (installments <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe a quantidade de parcelas.')));
        return;
      }
      if (instAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o valor da parcela.')));
        return;
      }
    }

    final expectedTotal = _roundCents(instAmount * installments);
    if (installments > 0 && instAmount > 0 && (expectedTotal - amount).abs() > 0.05) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Atenção aos Valores'),
          content: Text(
            'O valor total (R\$ ${amount.toStringAsFixed(2)}) não bate com o valor das parcelas (R\$ ${expectedTotal.toStringAsFixed(2)}). A última parcela será ajustada automaticamente para fechar o total. Deseja continuar?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Corrigir')),
            ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Continuar')),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final debt = Debt(
      id: widget.debt?.id,
      name: name,
      totalAmount: amount,
      installmentCount: installments > 0 ? installments : null,
      installmentAmount: instAmount > 0 ? instAmount : null,
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

      if (_generateInstallments && installments > 0) {
        final amounts = _buildInstallmentAmounts(amount, installments, instAmount);
        for (int i = 0; i < installments; i++) {
          final due = _safeMonthlyDueDate(_firstDueDate, i);
          final now = DateTime.now().toIso8601String();
          final transaction = FinancialTransaction(
            title: '$name (Parcela ${i + 1}/$installments)',
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
            totalInstallments: installments,
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
