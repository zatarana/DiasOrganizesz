import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/credit_card_store.dart';
import '../../data/database/finance_planning_store.dart';
import '../../data/models/credit_card_invoice_model.dart';
import '../../data/models/credit_card_model.dart';
import '../../data/models/financial_account_model.dart';
import '../../domain/providers.dart';

class CreditCardsScreen extends ConsumerStatefulWidget {
  const CreditCardsScreen({super.key});

  @override
  ConsumerState<CreditCardsScreen> createState() => _CreditCardsScreenState();
}

class _CreditCardsScreenState extends ConsumerState<CreditCardsScreen> {
  bool _loading = true;
  List<CreditCard> _cards = [];
  List<CreditCardInvoice> _invoices = [];
  List<FinancialAccount> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final db = await ref.read(dbProvider).database;
    final cards = await CreditCardStore.getCards(db);
    final invoices = await CreditCardStore.getInvoices(db);
    final accounts = await FinancePlanningStore.getAccounts(db, recalculateBeforeRead: true);
    if (!mounted) return;
    setState(() {
      _cards = cards;
      _invoices = invoices;
      _accounts = accounts;
      _loading = false;
    });
  }

  String _money(num value) => 'R\$ ${value.toDouble().toStringAsFixed(2)}';

  String _dateLabel(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return 'Data inválida';
    return DateFormat('dd/MM/yyyy').format(parsed);
  }

  String _monthLabel(String month) {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    return '${parts[1]}/${parts[0]}';
  }

  List<CreditCardInvoice> _invoicesForCard(int? cardId) {
    if (cardId == null) return [];
    return _invoices.where((invoice) => invoice.cardId == cardId).toList();
  }

  double _remainingInvoiceAmount(CreditCardInvoice invoice) {
    final remaining = invoice.amount - invoice.paidAmount;
    return remaining < 0 ? 0 : remaining;
  }

  Future<void> _createCurrentInvoice(CreditCard card) async {
    if (card.id == null) return;
    final db = await ref.read(dbProvider).database;
    final now = DateTime.now();
    await CreditCardStore.getOrCreateInvoice(db, card: card, month: DateTime(now.year, now.month, 1));
    await _loadAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fatura do mês criada ou localizada.')));
  }

  Future<void> _showCardDialog({CreditCard? card}) async {
    final nameController = TextEditingController(text: card?.name ?? '');
    final issuerController = TextEditingController(text: card?.issuer ?? '');
    final limitController = TextEditingController(text: card == null ? '' : card.creditLimit.toStringAsFixed(2));
    final closingController = TextEditingController(text: '${card?.closingDay ?? 10}');
    final dueController = TextEditingController(text: '${card?.dueDay ?? 20}');
    int? paymentAccountId = card?.paymentAccountId;
    bool isArchived = card?.isArchived ?? false;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final selectableAccounts = _accounts.where((account) => !account.isArchived || account.id == paymentAccountId).toList();
          final safePaymentAccountId = selectableAccounts.any((account) => account.id == paymentAccountId) ? paymentAccountId : null;

          return AlertDialog(
            title: Text(card == null ? 'Novo cartão' : 'Editar cartão'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome do cartão')),
                  TextField(controller: issuerController, decoration: const InputDecoration(labelText: 'Emissor / banco')),
                  TextField(
                    controller: limitController,
                    decoration: const InputDecoration(labelText: 'Limite', prefixText: 'R\$ '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  TextField(
                    controller: closingController,
                    decoration: const InputDecoration(labelText: 'Dia de fechamento', helperText: 'Use de 1 a 28 para evitar datas inválidas.'),
                    keyboardType: TextInputType.number,
                  ),
                  TextField(
                    controller: dueController,
                    decoration: const InputDecoration(labelText: 'Dia de vencimento', helperText: 'Use de 1 a 28 para evitar datas inválidas.'),
                    keyboardType: TextInputType.number,
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: safePaymentAccountId,
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('Sem conta padrão')),
                      ...selectableAccounts.map((account) => DropdownMenuItem<int>(value: account.id, child: Text('${account.name}${account.isArchived ? ' (arquivada)' : ''}'))),
                    ],
                    onChanged: (value) => setLocal(() => paymentAccountId = value),
                    decoration: const InputDecoration(labelText: 'Conta padrão para pagamento'),
                  ),
                  if (card != null)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Arquivar cartão'),
                      value: isArchived,
                      onChanged: (value) => setLocal(() => isArchived = value),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              TextButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final limit = double.tryParse(limitController.text.replaceAll(',', '.')) ?? 0;
                  final closingDay = int.tryParse(closingController.text.trim()) ?? 0;
                  final dueDay = int.tryParse(dueController.text.trim()) ?? 0;

                  if (name.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe o nome do cartão.')));
                    return;
                  }
                  if (limit < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O limite não pode ser negativo.')));
                    return;
                  }
                  if (closingDay < 1 || closingDay > 28 || dueDay < 1 || dueDay > 28) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fechamento e vencimento devem estar entre 1 e 28.')));
                    return;
                  }

                  final now = DateTime.now().toIso8601String();
                  final data = CreditCard(
                    id: card?.id,
                    name: name,
                    issuer: issuerController.text.trim().isEmpty ? null : issuerController.text.trim(),
                    creditLimit: limit,
                    closingDay: closingDay,
                    dueDay: dueDay,
                    paymentAccountId: paymentAccountId,
                    isArchived: isArchived,
                    createdAt: card?.createdAt ?? now,
                    updatedAt: now,
                  );
                  await CreditCardStore.upsertCard(await ref.read(dbProvider).database, data);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );

    nameController.dispose();
    issuerController.dispose();
    limitController.dispose();
    closingController.dispose();
    dueController.dispose();
    if (saved == true) await _loadAll();
  }

  Future<void> _showPayInvoiceDialog(CreditCardInvoice invoice) async {
    final remaining = _remainingInvoiceAmount(invoice);
    if (remaining <= 0 || invoice.status == 'paid') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Esta fatura já está quitada.')));
      return;
    }

    final amountController = TextEditingController(text: remaining.toStringAsFixed(2));
    final notesController = TextEditingController();
    final invoiceCard = _cards.cast<CreditCard?>().firstWhere((card) => card?.id == invoice.cardId, orElse: () => null);
    int? paymentAccountId = invoice.paymentAccountId ?? invoiceCard?.paymentAccountId;

    final paid = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final selectableAccounts = _accounts.where((account) => !account.isArchived || account.id == paymentAccountId).toList();
          final safeAccountId = selectableAccounts.any((account) => account.id == paymentAccountId) ? paymentAccountId : null;

          return AlertDialog(
            title: Text('Pagar fatura ${_monthLabel(invoice.referenceMonth)}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Valor da fatura: ${_money(invoice.amount)}'),
                  Text('Já pago: ${_money(invoice.paidAmount)}'),
                  Text('Restante: ${_money(remaining)}'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(labelText: 'Valor do pagamento', prefixText: 'R\$ '),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  DropdownButtonFormField<int>(
                    initialValue: safeAccountId,
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('Selecione uma conta')),
                      ...selectableAccounts.map((account) => DropdownMenuItem<int>(value: account.id, child: Text('${account.name}${account.isArchived ? ' (arquivada)' : ''}'))),
                    ],
                    onChanged: (value) => setLocal(() => paymentAccountId = value),
                    decoration: const InputDecoration(labelText: 'Conta de pagamento'),
                  ),
                  TextField(controller: notesController, decoration: const InputDecoration(labelText: 'Observações'), maxLines: 2),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              TextButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;
                  if (safeAccountId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma conta de pagamento.')));
                    return;
                  }
                  if (amount <= 0 || amount > remaining) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um valor válido, até o restante da fatura.')));
                    return;
                  }
                  final db = await ref.read(dbProvider).database;
                  await CreditCardStore.payInvoice(
                    db,
                    invoiceId: invoice.id!,
                    paymentAccountId: safeAccountId,
                    amount: amount,
                    notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  );
                  await FinancePlanningStore.recalculateAccountBalance(db, safeAccountId);
                  await ref.read(transactionsProvider.notifier).loadTransactions();
                  if (ctx.mounted) Navigator.pop(ctx, true);
                },
                child: const Text('Pagar'),
              ),
            ],
          );
        },
      ),
    );

    amountController.dispose();
    notesController.dispose();
    if (paid == true) await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cartões e Faturas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCardDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Cartão'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _HeaderCard(cards: _cards, invoices: _invoices, money: _money),
                  const SizedBox(height: 12),
                  if (_cards.isEmpty)
                    const _EmptyCardsState()
                  else
                    ..._cards.map((card) => _CreditCardPanel(
                          card: card,
                          invoices: _invoicesForCard(card.id),
                          money: _money,
                          dateLabel: _dateLabel,
                          monthLabel: _monthLabel,
                          onEdit: () => _showCardDialog(card: card),
                          onCreateInvoice: () => _createCurrentInvoice(card),
                          onPayInvoice: _showPayInvoiceDialog,
                        )),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final List<CreditCard> cards;
  final List<CreditCardInvoice> invoices;
  final String Function(num value) money;

  const _HeaderCard({required this.cards, required this.invoices, required this.money});

  @override
  Widget build(BuildContext context) {
    final openInvoices = invoices.where((invoice) => invoice.status != 'paid').toList();
    final openAmount = openInvoices.fold<double>(0, (sum, invoice) => sum + (invoice.amount - invoice.paidAmount));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Resumo de cartões', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _HeaderMetric(label: 'Cartões', value: '${cards.where((card) => !card.isArchived).length}', icon: Icons.credit_card)),
                const SizedBox(width: 12),
                Expanded(child: _HeaderMetric(label: 'Faturas abertas', value: '${openInvoices.length}', icon: Icons.receipt_long)),
              ],
            ),
            const SizedBox(height: 8),
            _HeaderMetric(label: 'Total em aberto', value: money(openAmount), icon: Icons.payments_outlined),
          ],
        ),
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeaderMetric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(radius: 18, child: Icon(icon, size: 20)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _CreditCardPanel extends StatelessWidget {
  final CreditCard card;
  final List<CreditCardInvoice> invoices;
  final String Function(num value) money;
  final String Function(String raw) dateLabel;
  final String Function(String month) monthLabel;
  final VoidCallback onEdit;
  final VoidCallback onCreateInvoice;
  final Future<void> Function(CreditCardInvoice invoice) onPayInvoice;

  const _CreditCardPanel({required this.card, required this.invoices, required this.money, required this.dateLabel, required this.monthLabel, required this.onEdit, required this.onCreateInvoice, required this.onPayInvoice});

  @override
  Widget build(BuildContext context) {
    final openAmount = invoices.where((invoice) => invoice.status != 'paid').fold<double>(0, (sum, invoice) => sum + (invoice.amount - invoice.paidAmount));
    return Card(
      child: ExpansionTile(
        initiallyExpanded: invoices.isNotEmpty,
        leading: CircleAvatar(backgroundColor: Colors.deepPurple.withValues(alpha: 0.12), child: const Icon(Icons.credit_card, color: Colors.deepPurple)),
        title: Text(card.name),
        subtitle: Text([if (card.issuer != null && card.issuer!.isNotEmpty) card.issuer!, 'Fecha dia ${card.closingDay} • vence dia ${card.dueDay}', if (card.isArchived) 'arquivado'].join(' • ')),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') onEdit();
            if (value == 'invoice') onCreateInvoice();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Editar cartão')),
            PopupMenuItem(value: 'invoice', child: Text('Gerar fatura do mês')),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                Expanded(child: Text('Limite: ${money(card.creditLimit)}')),
                Text('Aberto: ${money(openAmount)}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          if (invoices.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('Nenhuma fatura criada para este cartão.', style: TextStyle(color: Colors.grey)))
          else
            ...invoices.map((invoice) => _InvoiceTile(invoice: invoice, money: money, dateLabel: dateLabel, monthLabel: monthLabel, onPay: () => onPayInvoice(invoice))),
        ],
      ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  final CreditCardInvoice invoice;
  final String Function(num value) money;
  final String Function(String raw) dateLabel;
  final String Function(String month) monthLabel;
  final VoidCallback onPay;

  const _InvoiceTile({required this.invoice, required this.money, required this.dateLabel, required this.monthLabel, required this.onPay});

  @override
  Widget build(BuildContext context) {
    final remaining = (invoice.amount - invoice.paidAmount).clamp(0, double.infinity).toDouble();
    final paid = invoice.status == 'paid';
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(backgroundColor: (paid ? Colors.green : Colors.orange).withValues(alpha: 0.12), child: Icon(paid ? Icons.check : Icons.receipt_long, color: paid ? Colors.green : Colors.orange)),
      title: Text('Fatura ${monthLabel(invoice.referenceMonth)}'),
      subtitle: Text(['Vence: ${dateLabel(invoice.dueDate)}', 'Status: ${_statusLabel(invoice.status)}', 'Pago: ${money(invoice.paidAmount)}'].join(' • ')),
      trailing: SizedBox(
        width: 120,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(money(remaining), style: const TextStyle(fontWeight: FontWeight.bold)),
            if (!paid) TextButton(onPressed: onPay, child: const Text('Pagar')),
          ],
        ),
      ),
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'paga';
      case 'partial':
        return 'parcial';
      case 'closed':
        return 'fechada';
      default:
        return 'aberta';
    }
  }
}

class _EmptyCardsState extends StatelessWidget {
  const _EmptyCardsState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: Text('Nenhum cartão cadastrado ainda.', style: TextStyle(color: Colors.grey))),
    );
  }
}
