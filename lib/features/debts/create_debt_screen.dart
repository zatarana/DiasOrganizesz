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
      if (widget.debt!.startDate != null) _startDate = DateTime.parse(widget.debt!.startDate!);
      if (widget.debt!.firstDueDate != null) _firstDueDate = DateTime.parse(widget.debt!.firstDueDate!);
    }

    _amountController.addListener(_recalculateAuto);
    _installmentsController.addListener(_recalculateAuto);
  }

  void _recalculateAuto() {
    if (_isAutoCalculating) return;

    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    final instCount = int.tryParse(_installmentsController.text) ?? 0;

    if (amount > 0 && instCount > 0 && _installmentAmountController.text.isEmpty) {
      _isAutoCalculating = true;
      _installmentAmountController.text = (amount / instCount).toStringAsFixed(2);
      _isAutoCalculating = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(financialCategoriesProvider).where((c) => c.type == 'expense').toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.debt == null ? 'Nova Dívida' : 'Detalhes/Editar Dívida'),
        actions: [
          if (widget.debt != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                ref.read(debtsProvider.notifier).removeDebt(widget.debt!.id!);
                Navigator.pop(context);
              },
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
                initialValue: _selectedCategoryId,
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
                  subtitle: const Text('Cria automaticamente despesas no módulo Financeiro para esta dívida. Você pode fazer isso depois ou pagar manualmente.'),
                  value: _generateInstallments,
                  onChanged: (v) => setState(() => _generateInstallments = v),
                ),
                SwitchListTile(
                  title: const Text('Lembrar parcelas automaticamente?'),
                  subtitle: const Text('Agenda lembrete local para vencimento de cada parcela'),
                  value: _remindInstallments,
                  onChanged: (v) => setState(() => _remindInstallments = v),
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

  void _saveDebt() async {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    final installments = int.tryParse(_installmentsController.text) ?? 0;
    final instAmount = double.tryParse(_installmentAmountController.text.replaceAll(',', '.')) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O nome é obrigatório.')));
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O valor total deve ser maior que zero.')));
      return;
    }
    if (_generateInstallments) {
      if (installments <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O número de parcelas deve ser maior que zero para gerar no financeiro.')));
        return;
      }
      if (instAmount <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O valor da parcela deve ser maior que zero para gerar no financeiro.')));
        return;
      }
    }
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A categoria financeira é obrigatória.')));
      return;
    }

    final expectedTotal = instAmount * installments;
    if (installments > 0 && instAmount > 0 && (expectedTotal - amount).abs() > 0.05) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Atenção aos Valores'),
          content: Text('O valor total (R\$ ${amount.toStringAsFixed(2)}) não bate com o valor das parcelas (R\$ ${expectedTotal.toStringAsFixed(2)}). Deseja continuar assim mesmo?'),
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
      categoryId: _selectedCategoryId,
      description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
      notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      creditorName: _creditorController.text.isNotEmpty ? _creditorController.text : null,
      status: widget.debt?.status ?? 'active',
      createdAt: widget.debt?.createdAt ?? DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    if (widget.debt == null) {
      final helper = ref.read(dbProvider);
      final id = await helper.createDebt(debt.toMap());
      ref.read(debtsProvider.notifier).loadDebts();

      if (_generateInstallments && installments > 0) {
        for (int i = 0; i < installments; i++) {
          final due = DateTime(_firstDueDate.year, _firstDueDate.month + i, _firstDueDate.day);

          final transaction = FinancialTransaction(
            title: '$name (Parcela ${i + 1}/$installments)',
            amount: instAmount,
            type: 'expense',
            categoryId: _selectedCategoryId,
            transactionDate: due.toIso8601String(),
            dueDate: due.toIso8601String(),
            status: 'pending',
            reminderEnabled: _remindInstallments,
            isFixed: false,
            recurrenceType: 'none',
            debtId: id,
            installmentNumber: i + 1,
            totalInstallments: installments,
            createdAt: DateTime.now().toIso8601String(),
            updatedAt: DateTime.now().toIso8601String(),
          );
          await helper.createTransaction(transaction);
        }
        ref.read(transactionsProvider.notifier).loadTransactions();
      }
    } else {
      ref.read(debtsProvider.notifier).updateDebt(debt);
    }

    if (mounted) Navigator.pop(context);
  }
}
