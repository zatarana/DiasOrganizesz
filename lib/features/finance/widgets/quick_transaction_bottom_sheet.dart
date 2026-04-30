import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/money_formatter.dart';
import '../../../data/models/financial_category_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../domain/providers.dart';
import '../create_transaction_screen.dart';

Future<bool?> showQuickTransactionBottomSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => const QuickTransactionBottomSheet(),
  );
}

class QuickTransactionBottomSheet extends ConsumerStatefulWidget {
  const QuickTransactionBottomSheet({super.key});

  @override
  ConsumerState<QuickTransactionBottomSheet> createState() => _QuickTransactionBottomSheetState();
}

class _QuickTransactionBottomSheetState extends ConsumerState<QuickTransactionBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  String _type = 'expense';
  int? _categoryId;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  List<FinancialCategory> _categoriesForType(List<FinancialCategory> categories) {
    return categories.where((c) => c.type == 'both' || c.type == _type).toList();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = MoneyFormatter.parse(_amountController.text);
    if (amount == null || amount <= 0) return;
    setState(() => _isSaving = true);
    final now = DateTime.now().toIso8601String();
    final transaction = FinancialTransaction(
      title: _titleController.text.trim(),
      amount: amount,
      type: _type,
      transactionDate: now,
      dueDate: now,
      paidDate: now,
      categoryId: _categoryId,
      status: 'paid',
      paymentMethod: 'Lançamento rápido',
      createdAt: now,
      updatedAt: now,
    );
    await ref.read(transactionsProvider.notifier).addTransaction(transaction);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lançamento rápido salvo.')));
    Navigator.pop(context, true);
  }

  void _openFullForm() {
    Navigator.pop(context, false);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTransactionScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final categories = _categoriesForType(ref.watch(financialCategoriesProvider));
    if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) _categoryId = null;

    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Lançamento rápido', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Valor, título e categoria. Para parcelas, contas e recorrência, use Mais detalhes.', style: TextStyle(color: Colors.grey.shade700)),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                selected: {_type},
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Despesa'), icon: Icon(Icons.arrow_downward)),
                  ButtonSegment(value: 'income', label: Text('Receita'), icon: Icon(Icons.arrow_upward)),
                ],
                onSelectionChanged: _isSaving ? null : (value) => setState(() { _type = value.first; _categoryId = null; }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountController,
                enabled: !_isSaving,
                keyboardType: TextInputType.number,
                inputFormatters: const [MoneyInputFormatter(), LengthLimitingTextInputFormatter(18)],
                decoration: const InputDecoration(labelText: 'Valor', prefixIcon: Icon(Icons.payments_outlined), border: OutlineInputBorder()),
                validator: (value) {
                  final amount = MoneyFormatter.parse(value ?? '');
                  if (amount == null || amount <= 0) return 'Informe um valor válido.';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _titleController,
                enabled: !_isSaving,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Título', prefixIcon: Icon(Icons.edit_note), border: OutlineInputBorder()),
                validator: (value) => (value ?? '').trim().isEmpty ? 'Informe um título.' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.category_outlined), border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Sem categoria')),
                  ...categories.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                ],
                onChanged: _isSaving ? null : (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
                label: Text(_isSaving ? 'Salvando...' : 'Salvar lançamento'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: _isSaving ? null : _openFullForm, icon: const Icon(Icons.tune), label: const Text('Mais detalhes')),
            ],
          ),
        ),
      ),
    );
  }
}
