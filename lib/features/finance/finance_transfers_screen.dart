import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/database/finance_planning_store.dart';
import '../../data/models/financial_account_model.dart';
import '../../data/models/financial_transfer_model.dart';
import '../../domain/providers.dart';

class FinanceTransfersScreen extends ConsumerStatefulWidget {
  const FinanceTransfersScreen({super.key});

  @override
  ConsumerState<FinanceTransfersScreen> createState() => _FinanceTransfersScreenState();
}

class _FinanceTransfersScreenState extends ConsumerState<FinanceTransfersScreen> {
  bool _loading = true;
  List<FinancialAccount> _accounts = [];
  List<FinancialTransfer> _transfers = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final db = await ref.read(dbProvider).database;
    final accounts = await FinancePlanningStore.getAccounts(db, recalculateBeforeRead: true);
    final transfers = await FinancePlanningStore.getTransfers(db);
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _transfers = transfers;
      _loading = false;
    });
  }

  String _money(num value) => 'R\$ ${value.toDouble().toStringAsFixed(2)}';

  FinancialAccount? _accountById(int? id) {
    if (id == null) return null;
    for (final account in _accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  List<FinancialAccount> get _activeAccounts => _accounts.where((account) => !account.isArchived && account.id != null).toList();

  Future<void> _showTransferDialog({FinancialTransfer? transfer}) async {
    if (_activeAccounts.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cadastre ao menos duas contas ativas para transferir.')));
      return;
    }

    int fromAccountId = transfer?.fromAccountId ?? _activeAccounts.first.id!;
    int toAccountId = transfer?.toAccountId ?? _activeAccounts.firstWhere((account) => account.id != fromAccountId).id!;
    DateTime transferDate = DateTime.tryParse(transfer?.transferDate ?? '') ?? DateTime.now();
    bool ignoreInReports = transfer?.ignoreInReports ?? false;
    final amountController = TextEditingController(text: transfer == null ? '' : transfer.amount.toStringAsFixed(2));
    final descriptionController = TextEditingController(text: transfer?.description ?? '');
    final notesController = TextEditingController(text: transfer?.notes ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(transfer == null ? 'Nova transferência' : 'Editar transferência'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: fromAccountId,
                  decoration: const InputDecoration(labelText: 'Conta de origem'),
                  items: _activeAccounts.map((account) => DropdownMenuItem<int>(value: account.id, child: Text(account.name))).toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setLocal(() {
                      fromAccountId = value;
                      if (toAccountId == fromAccountId) {
                        toAccountId = _activeAccounts.firstWhere((account) => account.id != fromAccountId).id!;
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  initialValue: toAccountId,
                  decoration: const InputDecoration(labelText: 'Conta de destino'),
                  items: _activeAccounts.where((account) => account.id != fromAccountId).map((account) => DropdownMenuItem<int>(value: account.id, child: Text(account.name))).toList(),
                  onChanged: (value) {
                    if (value != null) setLocal(() => toAccountId = value);
                  },
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: 'Valor', prefixText: 'R\$ '),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(context: context, initialDate: transferDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setLocal(() => transferDate = picked);
                  },
                  icon: const Icon(Icons.event),
                  label: Text('Data: ${DateFormat('dd/MM/yyyy').format(transferDate)}'),
                ),
                const SizedBox(height: 8),
                TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Descrição')),
                TextField(controller: notesController, decoration: const InputDecoration(labelText: 'Observações'), maxLines: 2),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ignorar em relatórios'),
                  subtitle: const Text('A transferência ainda afeta saldos das contas.'),
                  value: ignoreInReports,
                  onChanged: (value) => setLocal(() => ignoreInReports = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe um valor maior que zero.')));
                  return;
                }
                if (fromAccountId == toAccountId) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Origem e destino precisam ser diferentes.')));
                  return;
                }

                final now = DateTime.now().toIso8601String();
                final data = FinancialTransfer(
                  id: transfer?.id,
                  fromAccountId: fromAccountId,
                  toAccountId: toAccountId,
                  amount: amount,
                  transferDate: transferDate.toIso8601String(),
                  description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  ignoreInReports: ignoreInReports,
                  createdAt: transfer?.createdAt ?? now,
                  updatedAt: now,
                );

                try {
                  await FinancePlanningStore.upsertTransfer(await ref.read(dbProvider).database, data);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    amountController.dispose();
    descriptionController.dispose();
    notesController.dispose();
    if (saved == true) await _loadAll();
  }

  Future<void> _confirmDelete(FinancialTransfer transfer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir transferência?'),
        content: const Text('Os saldos das contas de origem e destino serão recalculados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true) return;
    await FinancePlanningStore.deleteTransfer(await ref.read(dbProvider).database, transfer);
    await _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final totalBalance = _accounts.where((account) => !account.isArchived).fold<double>(0, (sum, account) => sum + account.currentBalance);
    return Scaffold(
      appBar: AppBar(title: const Text('Transferências entre contas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.swap_horiz)),
                    title: const Text('Saldo total em contas ativas'),
                    trailing: Text(_money(totalBalance), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(onPressed: () => _showTransferDialog(), icon: const Icon(Icons.add), label: const Text('Nova transferência')),
                const SizedBox(height: 12),
                if (_transfers.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('Nenhuma transferência cadastrada ainda.', style: TextStyle(color: Colors.grey))),
                  )
                else
                  ..._transfers.map((transfer) {
                    final from = _accountById(transfer.fromAccountId);
                    final to = _accountById(transfer.toAccountId);
                    final date = DateTime.tryParse(transfer.transferDate);
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.blue.withOpacity(0.12), child: const Icon(Icons.swap_horiz, color: Colors.blue)),
                        title: Text('${from?.name ?? 'Origem removida'} → ${to?.name ?? 'Destino removido'}'),
                        subtitle: Text([
                          if (date != null) DateFormat('dd/MM/yyyy').format(date),
                          if (transfer.description != null && transfer.description!.isNotEmpty) transfer.description!,
                          if (transfer.ignoreInReports) 'fora dos relatórios',
                        ].join(' • ')),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(_money(transfer.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                            InkWell(onTap: () => _confirmDelete(transfer), child: const Icon(Icons.delete_outline, size: 18, color: Colors.red)),
                          ],
                        ),
                        onTap: () => _showTransferDialog(transfer: transfer),
                      ),
                    );
                  }),
              ],
            ),
    );
  }
}
