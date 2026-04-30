import 'dart:io';

void main() {
  final debtsScreen = File('lib/features/debts/debts_screen.dart');
  final detailsScreen = File('lib/features/debts/debt_details_screen.dart');

  if (!debtsScreen.existsSync() || !detailsScreen.existsSync()) {
    stderr.writeln('Arquivos de dívidas não encontrados.');
    exit(1);
  }

  var debtsText = debtsScreen.readAsStringSync();
  var detailsText = detailsScreen.readAsStringSync();

  debtsText = _patchDebtsScreen(debtsText);
  detailsText = _patchDebtDetailsScreen(detailsText);

  debtsScreen.writeAsStringSync(debtsText);
  detailsScreen.writeAsStringSync(detailsText);

  stdout.writeln('F-M4 aplicado: CTA de cadastro e tela de detalhes de dívida refinados.');
}

String _patchDebtsScreen(String text) {
  text = _ensureImport(text, "import 'package:intl/intl.dart';", "import '../../core/utils/money_formatter.dart';");

  text = text.replaceFirst(
    "      appBar: AppBar(title: const Text('Minhas Dívidas')),",
    "      appBar: AppBar(\n        title: const Text('Minhas Dívidas'),\n        actions: [\n          IconButton(\n            tooltip: 'Cadastrar dívida',\n            icon: const Icon(Icons.add_card_outlined),\n            onPressed: _openCreateDebt,\n          ),\n        ],\n      ),",
  );

  text = text.replaceFirst(
    "child: Text('Nenhuma dívida encontrada para este filtro.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),",
    "child: _buildEmptyDebtState(),",
  );

  text = text.replaceFirst(
    "      floatingActionButton: FloatingActionButton(\n        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateDebtScreen())),\n        child: const Icon(Icons.add),\n      ),",
    "      floatingActionButton: FloatingActionButton.extended(\n        onPressed: _openCreateDebt,\n        icon: const Icon(Icons.add),\n        label: const Text('Nova dívida'),\n      ),",
  );

  final insertBefore = "  String _currentFilterLabel() {";
  if (!text.contains("void _openCreateDebt()")) {
    if (!text.contains(insertBefore)) {
      stderr.writeln('F-M4 DebtsScreen: marcador _currentFilterLabel não encontrado.');
      exit(1);
    }
    text = text.replaceFirst(insertBefore, _debtsScreenHelpers + insertBefore);
  }

  final checks = [
    "import '../../core/utils/money_formatter.dart';",
    "tooltip: 'Cadastrar dívida'",
    "FloatingActionButton.extended",
    "label: const Text('Nova dívida')",
    "_buildEmptyDebtState",
    "_openCreateDebt",
    "MoneyFormatter.format",
  ];
  for (final check in checks) {
    if (!text.contains(check)) {
      stderr.writeln('F-M4 DebtsScreen incompleto. Faltou: $check');
      exit(1);
    }
  }

  return text;
}

const _debtsScreenHelpers = r'''
  String _money(num value) => MoneyFormatter.format(value);

  void _openCreateDebt() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateDebtScreen()));
  }

  Widget _buildEmptyDebtState() {
    final isFiltered = _currentFilter != 'todas';
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7), shape: BoxShape.circle),
              child: Icon(isFiltered ? Icons.manage_search_outlined : Icons.payments_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 16),
            Text(
              isFiltered ? 'Nenhuma dívida neste filtro' : 'Nenhuma dívida cadastrada',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              isFiltered
                  ? 'Troque o filtro para visualizar outras dívidas ou cadastre uma nova dívida.'
                  : 'Cadastre empréstimos, parcelamentos, acordos ou qualquer dívida que você deseja acompanhar.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.35),
            ),
            const SizedBox(height: 18),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 8,
              children: [
                if (isFiltered)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _currentFilter = 'todas'),
                    icon: const Icon(Icons.filter_alt_off),
                    label: const Text('Ver todas'),
                  ),
                FilledButton.icon(
                  onPressed: _openCreateDebt,
                  icon: const Icon(Icons.add),
                  label: const Text('Cadastrar dívida'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

''';

String _patchDebtDetailsScreen(String text) {
  text = _ensureImport(text, "import 'package:intl/intl.dart';", "import '../../core/utils/money_formatter.dart';");

  text = text.replaceFirst(
    r"  String _money(num value) => 'R\$ ${value.toDouble().toStringAsFixed(2)}';",
    "  String _money(num value) => MoneyFormatter.format(value);",
  );
  text = text.replaceFirst(
    "  double _parseMoney(String text) => double.tryParse(text.replaceAll(',', '.')) ?? 0.0;",
    "  double _parseMoney(String text) => MoneyFormatter.parse(text) ?? 0.0;",
  );

  if (!text.contains('_buildDebtInfoCard(currentDebt, installments, remaining)')) {
    text = text.replaceFirst(
      "          _buildHeader(currentDebt, paidAmount, discounts, abatido, remaining, progress, valueDiff),\n          Padding(",
      "          _buildHeader(currentDebt, paidAmount, discounts, abatido, remaining, progress, valueDiff),\n          _buildDebtInfoCard(currentDebt, installments, remaining),\n          Padding(",
    );
  }

  text = text.replaceFirst(
    "                ? const Center(child: Text('Nenhuma parcela ou pagamento lançado. Use “Iniciar pagamento” para criar os lançamentos no Financeiro.'))",
    "                ? _buildEmptyInstallmentsState(currentDebt)",
  );

  final insertBefore = "  Widget _buildHeader(Debt debt, double paidAmount, double discounts, double abatido, double remaining, double progress, double valueDiff) {";
  if (!text.contains("Widget _buildDebtInfoCard")) {
    if (!text.contains(insertBefore)) {
      stderr.writeln('F-M4 DebtDetails: marcador _buildHeader não encontrado.');
      exit(1);
    }
    text = text.replaceFirst(insertBefore, _detailsHelpers + insertBefore);
  }

  final checks = [
    "import '../../core/utils/money_formatter.dart';",
    "MoneyFormatter.format(value)",
    "MoneyFormatter.parse(text)",
    "_buildDebtInfoCard",
    "_buildEmptyInstallmentsState",
    "Dados da dívida",
    "Nenhuma parcela criada",
  ];
  for (final check in checks) {
    if (!text.contains(check)) {
      stderr.writeln('F-M4 DebtDetails incompleto. Faltou: $check');
      exit(1);
    }
  }

  if (text.contains("String _money(num value) => 'R\\$ ") || text.contains("replaceAll(',', '.')")) {
    stderr.writeln('F-M4 DebtDetails ainda contém moeda/parsing antigo.');
    exit(1);
  }

  return text;
}

const _detailsHelpers = r'''
  Widget _buildDebtInfoCard(Debt debt, List<FinancialTransaction> installments, double remaining) {
    final nextPending = installments.where((transaction) => transaction.status != 'paid' && transaction.status != 'canceled').toList()
      ..sort((a, b) {
        final ad = _transactionDate(a) ?? DateTime(2100);
        final bd = _transactionDate(b) ?? DateTime(2100);
        return ad.compareTo(bd);
      });
    final nextDue = nextPending.isEmpty ? null : _transactionDate(nextPending.first);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: Colors.grey.shade300)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 8),
                  Text('Dados da dívida', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 12),
              _detailInfoRow('Credor', debt.creditorName?.isNotEmpty == true ? debt.creditorName! : 'Não informado'),
              _detailInfoRow('Contratação', _formatDate(debt.startDate)),
              _detailInfoRow('Primeiro vencimento', _formatDate(debt.firstDueDate)),
              _detailInfoRow('Parcelas previstas', debt.installmentCount == null ? 'Não informado' : '${debt.installmentCount}'),
              _detailInfoRow('Próximo vencimento', nextDue == null ? 'Sem parcela pendente' : DateFormat('dd/MM/yyyy').format(nextDue)),
              _detailInfoRow('Saldo restante', _money(remaining)),
              if (debt.description?.isNotEmpty == true) _detailInfoRow('Descrição', debt.description!),
              if (debt.notes?.isNotEmpty == true) _detailInfoRow('Observações', debt.notes!),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 132, child: Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildEmptyInstallmentsState(Debt debt) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: BorderSide(color: Colors.grey.shade300)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.7), shape: BoxShape.circle),
                  child: Icon(Icons.receipt_long_outlined, size: 42, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 14),
                const Text('Nenhuma parcela criada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  'Use “Iniciar pagamento” para criar parcelas no Financeiro ou registre um pagamento manual.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.35),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: debt.status == 'canceled' || debt.status == 'paid' ? null : () => _startPayment(debt, const []),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Iniciar pagamento'),
                    ),
                    OutlinedButton.icon(
                      onPressed: debt.status == 'canceled' ? null : () => _openManualPayment(debt, debt.totalAmount, 0),
                      icon: const Icon(Icons.add),
                      label: const Text('Pagamento manual'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

''';

String _ensureImport(String text, String after, String importLine) {
  if (text.contains(importLine)) return text;
  return text.replaceFirst(after, '$after\n$importLine');
}
