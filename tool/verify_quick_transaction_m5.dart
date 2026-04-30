import 'dart:io';

void main() {
  final sheet = File('lib/features/finance/widgets/quick_transaction_bottom_sheet.dart');
  final entry = File('lib/features/finance/finance_entry_screen.dart');
  final list = File('lib/features/finance/finance_screen.dart');

  if (!sheet.existsSync() || !entry.existsSync() || !list.existsSync()) {
    stderr.writeln('ERRO Etapa 5: arquivos esperados não encontrados.');
    exit(1);
  }

  final sheetText = sheet.readAsStringSync();
  final entryText = entry.readAsStringSync();
  final listText = list.readAsStringSync();

  final sheetChecks = [
    'Future<bool?> showQuickTransactionBottomSheet',
    'class QuickTransactionBottomSheet extends ConsumerStatefulWidget',
    'MoneyInputFormatter',
    'MoneyFormatter.parse',
    'SegmentedButton<String>',
    'FinancialTransaction(',
    'transactionsProvider.notifier).addTransaction',
    "paymentMethod: 'Lançamento rápido'",
    'CreateTransactionScreen',
    'Mais detalhes',
    'Salvar lançamento',
  ];

  final screenChecks = [
    "import 'widgets/quick_transaction_bottom_sheet.dart';",
    'Future<void> _openQuickTransaction() async',
    'showQuickTransactionBottomSheet(context)',
    "label: const Text('Lançamento rápido')",
  ];

  for (final check in sheetChecks) {
    if (!sheetText.contains(check)) {
      stderr.writeln('ERRO Etapa 5: Bottom Sheet incompleto. Faltou: $check');
      exit(1);
    }
  }

  for (final check in screenChecks) {
    if (!entryText.contains(check)) {
      stderr.writeln('ERRO Etapa 5: FinanceEntryScreen não integrada. Faltou: $check');
      exit(1);
    }
    if (!listText.contains(check)) {
      stderr.writeln('ERRO Etapa 5: FinanceScreen não integrada. Faltou: $check');
      exit(1);
    }
  }

  if (entryText.contains("onPressed: () => _open(context, const CreateTransactionScreen())")) {
    stderr.writeln('ERRO Etapa 5: FAB da entrada ainda abre formulário completo diretamente.');
    exit(1);
  }

  stdout.writeln('Etapa 5 OK: lançamento rápido integrado ao dashboard e à lista financeira.');
}
