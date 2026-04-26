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
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _creditorController = TextEditingController();
  
  bool _generateInstallments = false;
  final _installmentsController = TextEditingController(text: '1');
  DateTime _firstDueDate = DateTime.now().add(const Duration(days: 30));

  @override
  void initState() {
    super.initState();
    if (widget.debt != null) {
      _titleController.text = widget.debt!.title;
      _descriptionController.text = widget.debt!.description ?? '';
      _amountController.text = widget.debt!.totalAmount.toStringAsFixed(2);
      _creditorController.text = widget.debt!.creditor ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                 controller: _titleController,
                 decoration: const InputDecoration(labelText: 'Qual é a dívida? (Ex: Empréstimo, Carro)', border: OutlineInputBorder()),
               ),
               const SizedBox(height: 16),
               TextField(
                 controller: _amountController,
                 decoration: const InputDecoration(labelText: 'Valor Total (R\$)', border: OutlineInputBorder()),
                 keyboardType: const TextInputType.numberWithOptions(decimal: true),
               ),
               const SizedBox(height: 16),
               TextField(
                 controller: _creditorController,
                 decoration: const InputDecoration(labelText: 'Credor (A quem você deve?)', border: OutlineInputBorder()),
               ),
               const SizedBox(height: 16),
               TextField(
                 controller: _descriptionController,
                 decoration: const InputDecoration(labelText: 'Descrição ou anotações (Opcional)', border: OutlineInputBorder()),
                 maxLines: 2,
               ),
               
               if (widget.debt == null) ...[
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
                 ]
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
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0.0;
    
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O título é obrigatório.')));
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O valor deve ser maior que zero.')));
      return;
    }

    final debt = Debt(
      id: widget.debt?.id,
      title: title,
      totalAmount: amount,
      description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
      creditor: _creditorController.text.isNotEmpty ? _creditorController.text : null,
      status: 'active',
      createdAt: widget.debt?.createdAt ?? DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    if (widget.debt == null) {
      // First we add debt, but to link transactions we need the generated ID.
      // Our provider addDebt is async, but it updates state. We need to do this carefully.
      final helper = ref.read(dbProvider);
      final id = await helper.createDebt(debt.toMap());
      ref.read(debtsProvider.notifier).loadDebts(); // reload to get new one

      if (_generateInstallments) {
        int parcelas = int.tryParse(_installmentsController.text) ?? 1;
        if (parcelas > 0) {
          final valParcela = amount / parcelas;
          for (int i = 0; i < parcelas; i++) {
             // Simple monthly increment logic for due dates
             DateTime due = DateTime(_firstDueDate.year, _firstDueDate.month + i, _firstDueDate.day);
             
             final t = FinancialTransaction(
                title: '${title} (Parcela ${i+1}/$parcelas)',
                amount: valParcela,
                type: 'expense',
                transactionDate: due.toIso8601String(),
                dueDate: due.toIso8601String(),
                status: 'pending',
                isFixed: false,
                recurrenceType: 'none',
                debtId: id,
                installmentNumber: i + 1,
                totalInstallments: parcelas,
                createdAt: DateTime.now().toIso8601String(),
                updatedAt: DateTime.now().toIso8601String(),
             );
             await helper.createTransaction(t);
          }
          ref.read(transactionsProvider.notifier).loadTransactions(); // refresh
        }
      }
    } else {
       ref.read(debtsProvider.notifier).updateDebt(debt);
    }
    
    if (mounted) Navigator.pop(context);
  }
}
