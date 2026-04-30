import 'dart:io';

void main() {
  final entry = File('lib/features/finance/finance_entry_screen.dart');
  final list = File('lib/features/finance/finance_screen.dart');
  if (!entry.existsSync() || !list.existsSync()) {
    stderr.writeln('Arquivos financeiros não encontrados.');
    exit(1);
  }

  var entryText = entry.readAsStringSync();
  var listText = list.readAsStringSync();

  entryText = _patchEntry(entryText);
  listText = _patchFinanceList(listText);

  entry.writeAsStringSync(entryText);
  list.writeAsStringSync(listText);

  stdout.writeln('Etapa 5 aplicada: FABs financeiros abrem o lançamento rápido.');
}

String _patchEntry(String text) {
  if (!text.contains("import 'widgets/quick_transaction_bottom_sheet.dart';")) {
    text = text.replaceFirst(
      "import 'financial_goals_screen.dart';\n",
      "import 'financial_goals_screen.dart';\nimport 'widgets/quick_transaction_bottom_sheet.dart';\n",
    );
  }

  text = text.replaceFirst(
    "_FinanceToolCard(icon: Icons.add_card_outlined, title: 'Lançar', subtitle: 'Receita ou despesa', color: Colors.green, onTap: () => _open(context, const CreateTransactionScreen()))",
    "_FinanceToolCard(icon: Icons.add_card_outlined, title: 'Lançar', subtitle: 'Receita ou despesa', color: Colors.green, onTap: _openQuickTransaction)",
  );

  text = text.replaceFirst(
    "floatingActionButton: FloatingActionButton.extended(\n        onPressed: () => _open(context, const CreateTransactionScreen()),\n        icon: const Icon(Icons.add),\n        label: const Text('Novo lançamento'),\n      ),",
    "floatingActionButton: FloatingActionButton.extended(\n        onPressed: _openQuickTransaction,\n        icon: const Icon(Icons.flash_on),\n        label: const Text('Lançamento rápido'),\n      ),",
  );

  if (!text.contains('Future<void> _openQuickTransaction() async')) {
    text = text.replaceFirst(
      '  static void _open(BuildContext context, Widget screen) {\n',
      "  Future<void> _openQuickTransaction() async {\n    final saved = await showQuickTransactionBottomSheet(context);\n    if (saved == true && mounted) {\n      await _refreshData();\n      setState(() {});\n    }\n  }\n\n  static void _open(BuildContext context, Widget screen) {\n",
    );
  }

  for (final check in [
    "import 'widgets/quick_transaction_bottom_sheet.dart';",
    'showQuickTransactionBottomSheet(context)',
    'Future<void> _openQuickTransaction() async',
    "label: const Text('Lançamento rápido')",
    'onTap: _openQuickTransaction',
  ]) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO Etapa 5 na FinanceEntryScreen. Faltou: $check');
      exit(1);
    }
  }

  return text;
}

String _patchFinanceList(String text) {
  if (!text.contains("import 'widgets/quick_transaction_bottom_sheet.dart';")) {
    text = text.replaceFirst(
      "import 'finance_planning_screen.dart';\n",
      "import 'finance_planning_screen.dart';\nimport 'widgets/quick_transaction_bottom_sheet.dart';\n",
    );
  }

  if (!text.contains('Future<void> _openQuickTransaction() async')) {
    text = text.replaceFirst(
      '  Future<void> _openTransactionForm({FinancialTransaction? transaction}) async {\n',
      "  Future<void> _openQuickTransaction() async {\n    final saved = await showQuickTransactionBottomSheet(context);\n    if (saved == true && mounted) setState(() {});\n  }\n\n  Future<void> _openTransactionForm({FinancialTransaction? transaction}) async {\n",
    );
  }

  text = text.replaceFirst(
    "floatingActionButton: FloatingActionButton(onPressed: () => _openTransactionForm(), child: const Icon(Icons.add)),",
    "floatingActionButton: FloatingActionButton.extended(\n        onPressed: _openQuickTransaction,\n        icon: const Icon(Icons.flash_on),\n        label: const Text('Lançamento rápido'),\n      ),",
  );

  text = text.replaceFirst(
    "onPressed: () => _openTransactionForm(),\n                      icon: const Icon(Icons.add),\n                      label: const Text('Nova movimentação'),",
    "onPressed: _openQuickTransaction,\n                      icon: const Icon(Icons.flash_on),\n                      label: const Text('Lançamento rápido'),",
  );

  for (final check in [
    "import 'widgets/quick_transaction_bottom_sheet.dart';",
    'showQuickTransactionBottomSheet(context)',
    'Future<void> _openQuickTransaction() async',
    "label: const Text('Lançamento rápido')",
  ]) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO Etapa 5 na FinanceScreen. Faltou: $check');
      exit(1);
    }
  }

  return text;
}
