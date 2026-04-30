import 'dart:io';

void main() {
  _fixHome();
  _fixReports();
  _fixQuickTransaction();
  _fixTasksEntry();
  _fixSavePatcher();
  _fixTransactionSchema();
  _fixPlanningCards();
  stdout.writeln('Correções finais pré-analyzer aplicadas.');
}

void _fixHome() {
  final file = File('lib/features/dashboard/home_screen.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();
  text = text.replaceAll("import 'package:intl/intl.dart';\n", '');
  text = text.replaceAll(
    'floatingActionButton: const UniversalQuickActionButton(),',
    'floatingActionButton: _currentIndex == 0 ? const UniversalQuickActionButton() : null,',
  );
  final lines = text.split('\n');
  text = lines.where((line) => !line.trim().startsWith('onLongPress: () => _showUniversalActions(context),')).join('\n');
  if (text.contains('onLongPress: () => _showUniversalActions(context),')) {
    stderr.writeln('ERRO: onLongPress inválido no FloatingActionButton.');
    exit(1);
  }
  file.writeAsStringSync(text);
}

void _fixReports() {
  final file = File('lib/features/finance/finance_reports_screen.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();
  if (!text.contains("import 'dart:ui' as ui;")) {
    text = "import 'dart:ui' as ui;\n$text";
  }
  text = text.replaceAll('TextDirection.ltr', 'ui.TextDirection.ltr');
  while (text.contains('ui.ui.TextDirection.ltr')) {
    text = text.replaceAll('ui.ui.TextDirection.ltr', 'ui.TextDirection.ltr');
  }
  file.writeAsStringSync(text);
}

void _fixQuickTransaction() {
  final file = File('lib/features/finance/widgets/quick_transaction_bottom_sheet.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();
  text = text.replaceAll('inputFormatters: const [', 'inputFormatters: [');
  text = text.replaceAll('children: const [', 'children: [');
  file.writeAsStringSync(text);
}

void _fixTasksEntry() {
  final file = File('lib/features/tasks/tasks_entry_screen.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();
  final slashN = String.fromCharCode(92) + 'n';

  // Evita que o Dart interprete "$slashNclass" como uma única variável
  // inexistente durante a execução do patch no GitHub Actions.
  text = text.replaceAll('}' + slashN + slashN + 'class _CompactSmartLists', '}\n\nclass _CompactSmartLists');
  text = text.replaceAll('}' + slashN + 'class _CompactSmartLists', '}\n\nclass _CompactSmartLists');
  text = text.replaceAll(slashN + 'class _CompactSmartLists', '\nclass _CompactSmartLists');
  file.writeAsStringSync(text);
}

void _fixSavePatcher() {
  final file = File('tool/patch_input_save_reliability.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();
  final marker = String.fromCharCode(36) + 'check';
  if (text.contains(marker)) {
    text = text.replaceAll(marker, 'requisito obrigatório');
  }
  file.writeAsStringSync(text);
}

void _fixTransactionSchema() {
  final file = File('lib/data/database/db_helper.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();

  text = text.replaceAll('static const int schemaVersion = 18;', 'static const int schemaVersion = 19;');

  const upgrade18 = '''    if (oldVersion < 18) {
      await _ensureTaskColumns(db);
    }
''';
  const upgrade19 = '''    if (oldVersion < 18) {
      await _ensureTaskColumns(db);
    }
    if (oldVersion < 19) {
      await _ensureFinancialTransactionColumns(db);
    }
''';
  if (!text.contains('if (oldVersion < 19)')) {
    text = text.replaceFirst(upgrade18, upgrade19);
  }

  const ensureAnchor = "    await _addColumnIfMissing(db, 'transactions', 'accountId INTEGER');\n";
  const ensureExtra = "    await _addColumnIfMissing(db, 'transactions', 'subcategoryId INTEGER');\n"
      "    await _addColumnIfMissing(db, 'transactions', 'creditCardId INTEGER');\n"
      "    await _addColumnIfMissing(db, 'transactions', 'creditCardInvoiceId INTEGER');\n"
      "    await _addColumnIfMissing(db, 'transactions', 'creditCardPaymentInvoiceId INTEGER');\n";
  if (!text.contains("_addColumnIfMissing(db, 'transactions', 'subcategoryId INTEGER')")) {
    text = text.replaceFirst(ensureAnchor, '$ensureAnchor$ensureExtra');
  }

  if (!text.contains('        subcategoryId INTEGER,')) {
    text = text.replaceFirst('        categoryId INTEGER,\n', '        categoryId INTEGER,\n        subcategoryId INTEGER,\n');
  }
  if (!text.contains('        creditCardId INTEGER,')) {
    text = text.replaceFirst(
      '        debtId INTEGER,\n        installmentNumber INTEGER,\n',
      '        debtId INTEGER,\n        creditCardId INTEGER,\n        creditCardInvoiceId INTEGER,\n        creditCardPaymentInvoiceId INTEGER,\n        installmentNumber INTEGER,\n',
    );
  }

  for (final check in [
    'static const int schemaVersion = 19;',
    "_addColumnIfMissing(db, 'transactions', 'subcategoryId INTEGER')",
    "_addColumnIfMissing(db, 'transactions', 'creditCardId INTEGER')",
    "_addColumnIfMissing(db, 'transactions', 'creditCardInvoiceId INTEGER')",
    "_addColumnIfMissing(db, 'transactions', 'creditCardPaymentInvoiceId INTEGER')",
    '        subcategoryId INTEGER,',
    '        creditCardId INTEGER,',
    '        creditCardInvoiceId INTEGER,',
    '        creditCardPaymentInvoiceId INTEGER,',
  ]) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO: schema de transações incompleto. Faltou: $check');
      exit(1);
    }
  }

  file.writeAsStringSync(text);
}

void _fixPlanningCards() {
  final file = File('lib/features/finance/finance_dashboard_planning.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();

  text = text.replaceAll('          height: 126,', '          height: 146,');
  text = text.replaceAll('        width: 205,', '        width: 198,');
  text = text.replaceAll('          child: Card(\n          elevation: 0,', '          child: Card(\n          margin: EdgeInsets.zero,\n          elevation: 0,');
  text = text.replaceAll('              padding: const EdgeInsets.all(14),\n              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n                CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(Icons.account_balance_wallet_outlined, color: color)),\n                const Spacer(),', '              padding: const EdgeInsets.all(12),\n              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n                CircleAvatar(radius: 18, backgroundColor: color.withValues(alpha: 0.12), child: Icon(Icons.account_balance_wallet_outlined, color: color, size: 20)),\n                const SizedBox(height: 8),');
  text = text.replaceAll('style: TextStyle(color: color, fontWeight: FontWeight.w900)),\n              ])', 'style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),\n              ])');

  for (final check in [
    'height: 146',
    'margin: EdgeInsets.zero',
    'CircleAvatar(radius: 18',
    'fontSize: 16',
  ]) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO: cards de contas ainda podem gerar overflow. Faltou: $check');
      exit(1);
    }
  }

  file.writeAsStringSync(text);
}
