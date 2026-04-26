import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/providers.dart';
import '../../data/models/debt_model.dart';
import '../../data/models/transaction_model.dart';
import '../../data/models/financial_category_model.dart';

class CreateDebtScreen extends ConsumerStatefulWidget {
  final Debt? debt;
  const CreateDebtScreen({super.key, this.debt});

  @override
  ConsumerState<CreateDebtScreen> createState() => _CreateDebtScreenState();
}

class _CreateDebtScreenState extends ConsumerState<CreateDebtScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _creditorController = TextEditingController();
  
  bool _calculateByInstallment = false;
  final _installmentValueController = TextEditingController();

  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    if (widget.debt != null) {
      _titleController.text = widget.debt!.title;
      _descriptionController.text = widget.debt!.description ?? '';
      _creditorController.text = widget.debt!.creditor ?? '';
      _selectedCategoryId = widget.debt!.categoryId;
      
      if (widget.debt!.installmentsCount != null && widget.debt!.installmentsCount! > 0 && widget.debt!.installmentValue != null) {
         _calculateByInstallment = true;
         _installmentValueController.text = widget.debt!.installmentValue!.toStringAsFixed(2);
         _installmentsController.text = widget.debt!.installmentsCount!.toString();
         if (widget.debt!.firstDueDate != null) {
           _firstDueDate = DateTime.parse(widget.debt!.firstDueDate!);
         }
      } else {
        _amountController.text = widget.debt!.totalAmount.toStringAsFixed(2);
      }
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
               TextField(
                 controller: _nameController,
                 decoration: const InputDecoration(labelText: 'Qual é a dívida? (Ex: Cartão Nubank, Empréstimo)', border: OutlineInputBorder()),
               ),
               const SizedBox(height: 16),
               
               Row(
                 children: [
                   Expanded(
                     child: RadioListTile<bool>(
                       title: const Text('Valor Total'),
                       value: false,
                       groupValue: _calculateByInstallment,
                       onChanged: (v) => setState(() => _calculateByInstallment = v!),
                     ),
                   ),
                   Expanded(
                     child: RadioListTile<bool>(
                       title: const Text('Por Parcelas'),
                       value: true,
                       groupValue: _calculateByInstallment,
                       onChanged: (v) => setState(() => _calculateByInstallment = v!),
                     ),
                   ),
                 ],
               ),
               const SizedBox(height: 16),

               if (!_calculateByInstallment)
                 TextField(
                   controller: _amountController,
                   decoration: const InputDecoration(labelText: 'Valor Total (R\$)', border: OutlineInputBorder()),
                   keyboardType: const TextInputType.numberWithOptions(decimal: true),
                 )
               else
                 Row(
                   children: [
                     Expanded(
                       child: TextField(
                         controller: _installmentValueController,
                         decoration: const InputDecoration(labelText: 'Valor da Parcela', border: OutlineInputBorder()),
                         keyboardType: const TextInputType.numberWithOptions(decimal: true),
                       ),
                     ),
                     const SizedBox(width: 16),
                     Expanded(
                       child: TextField(
                         controller: _installmentsController,
                         decoration: const InputDecoration(labelText: 'Qtde Parcelas', border: OutlineInputBorder()),
                         keyboardType: TextInputType.number,
                       ),
                     ),
                   ],
                 ),

               const SizedBox(height: 16),
               DropdownButtonFormField<int>(
                  decoration: const InputDecoration(labelText: 'Categoria (Opcional)', border: OutlineInputBorder()),
                  value: _selectedCategoryId,
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('Nenhuma')),
                    ...categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  ],
                  onChanged: (val) => setState(() => _selectedCategoryId = val),
               ),
               const SizedBox(height: 16),
               OutlinedButton.icon(
                 onPressed: () async {
                   final dt = await showDatePicker(
                     context: context, 
                     initialDate: _startDate, 
                     firstDate: DateTime(2000), 
                     lastDate: DateTime(2100)
                   );
                   if (dt != null) setState(()=> _startDate = dt);
                 }, 
                 icon: const Icon(Icons.calendar_today),
                 label: Text('Data Inicial (Contratação): ${DateFormat('dd/MM/yyyy').format(_startDate)}')
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
               
               if (widget.debt == null && !_calculateByInstallment) ...[
                 const SizedBox(height: 32),
                 const Divider(),
                 SwitchListTile(
                   title: const Text('Gerar parcelas em Finanças?'),
                   subtitle: const Text('Isso criará despesas mensais atreladas a esta dívida.'),
                   value: _generateInstallments,
                   onChanged: (v) => setState(() => _generateInstallments = v),
                 ),
                 if (_generateInstallments) ...[
                   const SizedBox(height: 16),
                   TextField(
                     controller: _installmentsController,
                     decoration: const InputDecoration(labelText: 'Número de Parcelas', border: OutlineInputBorder()),
                     keyboardType: TextInputType.number,
                   ),
                 ]
               ],

               if (widget.debt == null && (_calculateByInstallment || _generateInstallments)) ...[
                 const SizedBox(height: 16),
                 OutlinedButton.icon(
                   onPressed: () async {
                     final dt = await showDatePicker(
                       context: context, 
                       initialDate: _firstDueDate, 
                       firstDate: DateTime.now(), 
                       lastDate: DateTime(2100)
                     );
                     if (dt != null) setState(()=> _firstDueDate = dt);
                   }, 
                   icon: const Icon(Icons.calendar_month),
                   label: Text('1º Vencimento: ${DateFormat('dd/MM/yyyy').format(_firstDueDate)}')
                 )
               ],
               
               const SizedBox(height: 32),
               ElevatedButton(
                 style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                 onPressed: _saveDebt,
                 child: const Text('Salvar'),
               )
            ],
          ),
        ),
      ),
    );
  }

  void _saveDebt() async {
    final name = _nameController.text.trim();
    
    double amount = 0;
    int installments = 0;
    double instAmount = 0;

    if (_calculateByInstallment) {
       instAmount = double.tryParse(_installmentValueController.text.replaceAll(',', '.')) ?? 0;
       installments = int.tryParse(_installmentsController.text) ?? 0;
       amount = instAmount * installments;
    } else {
       amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
       if (_generateInstallments) {
          installments = int.tryParse(_installmentsController.text) ?? 0;
          if (installments > 0) instAmount = amount / installments;
       }
    }
    
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O nome é obrigatório.')));
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O valor total/parcela deve ser maior que zero.')));
      return;
    }

    final debt = Debt(
      id: widget.debt?.id,
      name: name,
      totalAmount: amount,
      installmentCount: (installments > 0 ? installments : null),
      installmentAmount: (instAmount > 0 ? instAmount : null),
      startDate: _startDate.toIso8601String(),
      firstDueDate: (_calculateByInstallment || _generateInstallments) ? _firstDueDate.toIso8601String() : null,
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

      if (_generateInstallments || _calculateByInstallment) {
        if (installments > 0) {
          for (int i = 0; i < installments; i++) {
             DateTime due = DateTime(_firstDueDate.year, _firstDueDate.month + i, _firstDueDate.day);
             
             final t = FinancialTransaction(
                title: '${name} (Parcela ${i+1}/$installments)',
                amount: instAmount,
                type: 'expense',
                categoryId: _selectedCategoryId,
                transactionDate: due.toIso8601String(),
                dueDate: due.toIso8601String(),
                status: 'pending',
                isFixed: false,
                recurrenceType: 'none',
                debtId: id,
                installmentNumber: i + 1,
                totalInstallments: installments,
                createdAt: DateTime.now().toIso8601String(),
                updatedAt: DateTime.now().toIso8601String(),
             );
             await helper.createTransaction(t);
          }
          ref.read(transactionsProvider.notifier).loadTransactions();
        }
      }
    } else {
       ref.read(debtsProvider.notifier).updateDebt(debt);
    }
    
    if (mounted) Navigator.pop(context);
  }
}
