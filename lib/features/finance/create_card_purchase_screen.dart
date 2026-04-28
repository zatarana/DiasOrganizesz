import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/credit_card_store.dart';
import '../../data/database/finance_planning_store.dart';
import '../../data/models/credit_card_model.dart';
import '../../data/models/financial_subcategory_model.dart';
import '../../domain/providers.dart';

class CreateCardPurchaseScreen extends ConsumerStatefulWidget {
  final CreditCard? initialCard;

  const CreateCardPurchaseScreen({super.key, this.initialCard});

  @override
  ConsumerState<CreateCardPurchaseScreen> createState() => _CreateCardPurchaseScreenState();
}

class _CreateCardPurchaseScreenState extends ConsumerState<CreateCardPurchaseScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _tagsController = TextEditingController();

  bool _loading = true;
  List<CreditCard> _cards = [];
  List<FinancialSubcategory> _subcategories = [];
  int? _cardId;
  int? _categoryId;
  int? _subcategoryId;
  DateTime _purchaseDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _cardId = widget.initialCard?.id;
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final db = await ref.read(dbProvider).database;
    final cards = await CreditCardStore.getCards(db, includeArchived: false);
    final subcategories = await FinancePlanningStore.getSubcategories(db, includeArchived: true);
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _subcategories = subcategories;
      if (_cardId != null && !_cards.any((card) => card.id == _cardId)) _cardId = null;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  List<FinancialSubcategory> _selectableSubcategories(int? categoryId) {
    if (categoryId == null) return [];
    return _subcategories.where((item) => item.categoryId == categoryId && !item.isArchived).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _purchaseDate = picked);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    final categories = ref.read(financialCategoriesProvider).where((category) => category.type == 'expense' || category.type == 'both').toList();
    final safeCategoryId = categories.any((category) => category.id == _categoryId) ? _categoryId : null;
    final safeSubcategoryId = _selectableSubcategories(safeCategoryId).any((subcategory) => subcategory.id == _subcategoryId) ? _subcategoryId : null;

    if (_cardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione um cartão.')));
      return;
    }
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o título da compra.')));
      return;
    }
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O valor deve ser maior que zero.')));
      return;
    }

    final db = await ref.read(dbProvider).database;
    await CreditCardStore.createCardPurchase(
      db,
      cardId: _cardId!,
      title: title,
      description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
      amount: amount,
      purchaseDate: _purchaseDate,
      categoryId: safeCategoryId,
      subcategoryId: safeSubcategoryId,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      tags: _tagsController.text.trim().isEmpty ? null : _tagsController.text.trim(),
    );
    await ref.read(transactionsProvider.notifier).loadTransactions();
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(financialCategoriesProvider).where((category) => category.type == 'expense' || category.type == 'both').toList();
    final selectableSubcategories = _selectableSubcategories(_categoryId);
    final safeSubcategoryId = selectableSubcategories.any((subcategory) => subcategory.id == _subcategoryId) ? _subcategoryId : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Nova compra no cartão')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _cards.any((card) => card.id == _cardId) ? _cardId : null,
                  items: _cards.map((card) => DropdownMenuItem<int>(value: card.id, child: Text(card.name))).toList(),
                  onChanged: (value) => setState(() => _cardId = value),
                  decoration: const InputDecoration(labelText: 'Cartão', border: OutlineInputBorder()),
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
                  decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ ', border: OutlineInputBorder()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text('Data da compra: ${DateFormat('dd/MM/yyyy').format(_purchaseDate)}'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: categories.any((category) => category.id == _categoryId) ? _categoryId : null,
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('Sem categoria')),
                    ...categories.map((category) => DropdownMenuItem<int>(value: category.id, child: Text(category.name))),
                  ],
                  onChanged: (value) => setState(() {
                    _categoryId = value;
                    if (!_selectableSubcategories(value).any((subcategory) => subcategory.id == _subcategoryId)) {
                      _subcategoryId = null;
                    }
                  }),
                  decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: safeSubcategoryId,
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('Sem subcategoria')),
                    ...selectableSubcategories.map((subcategory) => DropdownMenuItem<int>(value: subcategory.id, child: Text(subcategory.name))),
                  ],
                  onChanged: _categoryId == null ? null : (value) => setState(() => _subcategoryId = value),
                  decoration: InputDecoration(
                    labelText: 'Subcategoria',
                    border: const OutlineInputBorder(),
                    helperText: _categoryId == null ? 'Escolha uma categoria para usar subcategoria.' : null,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    hintText: 'Ex: casa, mercado, online',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'Observações', border: OutlineInputBorder()),
                  maxLines: 3,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  onPressed: _save,
                  child: const Text('Salvar compra'),
                ),
              ],
            ),
    );
  }
}
