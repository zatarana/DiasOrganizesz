// ignore_for_file: prefer_const_declarations, prefer_const_constructors, prefer_interpolation_to_compose_strings

import 'dart:io';

void main() {
  _cleanFinanceScreen();
  _cleanFinanceEntryScreen();
  _cleanDebtsScreen();
  _replaceDeprecatedOpacity([
    'lib/features/tasks/quick_add_task_sheet.dart',
    'lib/features/tasks/task_timeline_screen.dart',
    'lib/features/tasks/tasks_entry_screen.dart',
  ]);
  _fixConstInfoHints();
  _fixAnalyzerCompileErrors();
  _fixFinanceMobileOverflows();
  _applySmartTaskCapture();
  _fixTasksEntrySyntax();
  _fixHomeDashboardCompatibility();
  _fixHomeGlobalFabOverlap();
  stdout.writeln('Analyzer cleanup aplicado.');
}

void _cleanFinanceScreen() {
  final file = File('lib/features/finance/finance_screen.dart');
  if (!file.existsSync()) return;

  var text = file.readAsStringSync();
  for (final method in [
    '_paidExpensesByCategory',
    '_buildTypeFilters',
    '_buildStatusFilters',
    '_buildCategoryFilters',
    '_gap',
    '_filterChip',
  ]) {
    text = _removeMethodByName(text, method);
  }

  if (text.contains('_paidExpensesByCategory(') ||
      text.contains('Widget _buildTypeFilters(') ||
      text.contains('Widget _buildStatusFilters(') ||
      text.contains('Widget _buildCategoryFilters(') ||
      text.contains('Widget _gap(') ||
      text.contains('Widget _filterChip(')) {
    stderr.writeln('ERRO: não foi possível remover funções antigas da FinanceScreen.');
    exit(1);
  }

  file.writeAsStringSync(text);
}

void _cleanFinanceEntryScreen() {
  final file = File('lib/features/finance/finance_entry_screen.dart');
  if (!file.existsSync()) return;

  var text = file.readAsStringSync();
  for (final className in ['_QuickChartsCard', '_CategoryHighlightRow', '_MiniPiePainter']) {
    text = _removeClassByName(text, className);
  }
  for (final method in ['_categoryHighlights', '_categoryColor']) {
    text = _removeMethodByName(text, method);
  }

  if (text.contains('class _QuickChartsCard') ||
      text.contains('class _CategoryHighlightRow') ||
      text.contains('class _MiniPiePainter') ||
      text.contains('List<_CategoryHighlight> _categoryHighlights(') ||
      text.contains('Color _categoryColor(')) {
    stderr.writeln('ERRO: não foi possível remover restos antigos da entrada financeira.');
    exit(1);
  }

  file.writeAsStringSync(text);
}

void _cleanDebtsScreen() {
  final file = File('lib/features/debts/debts_screen.dart');
  if (!file.existsSync()) return;

  var text = file.readAsStringSync();
  text = text.replaceAll(RegExp(r"\n\s*String _money\(num value\) => MoneyFormatter\.format\(value\);\s*\n"), '\n');

  if (!text.contains('void _openCreateDebt()')) {
    const marker = '  String _currentFilterLabel() {';
    if (!text.contains(marker)) {
      stderr.writeln('ERRO: marcador _currentFilterLabel não encontrado em debts_screen.dart.');
      exit(1);
    }
    text = text.replaceFirst(
      marker,
      "  void _openCreateDebt() {\n    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateDebtScreen()));\n  }\n\n$marker",
    );
  }

  if (text.contains('String _money(') || !text.contains('void _openCreateDebt()')) {
    stderr.writeln('ERRO: debts_screen.dart ficou inconsistente após limpeza.');
    exit(1);
  }

  file.writeAsStringSync(text);
}

void _replaceDeprecatedOpacity(List<String> paths) {
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    file.writeAsStringSync(file.readAsStringSync().replaceAll('.withOpacity(', '.withValues(alpha: '));
  }
}

void _fixConstInfoHints() {
  _replaceInFile('lib/core/notifications/notification_service.dart', '    final details = AndroidNotificationDetails(', '    const details = AndroidNotificationDetails(');
  _replaceInFile('lib/features/finance/finance_entry_screen.dart', '            FinanceHubScreen(),', '            const FinanceHubScreen(),');
  _replaceInFile('lib/features/finance/finance_hub_screen.dart', '            FinanceEntryScreen(),', '            const FinanceEntryScreen(),');
  _replaceInFile('lib/features/finance/finance_reports_screen.dart', '            FinanceScreen(),', '            const FinanceScreen(),');
}

void _fixAnalyzerCompileErrors() {
  _replaceInFile('lib/features/finance/finance_dashboard_planning.dart', 'MoneyFormatter.format(usage.plannedSpent)', 'MoneyFormatter.format(usage.plannedAmount)');

  final reports = File('lib/features/finance/finance_reports_screen.dart');
  if (reports.existsSync()) {
    var text = reports.readAsStringSync();
    if (!text.contains("import 'dart:ui' as ui;")) {
      text = text.replaceFirst("import 'dart:math' as math;\n", "import 'dart:math' as math;\nimport 'dart:ui' as ui;\n");
    }
    text = text.replaceAll('TextDirection.ltr', 'ui.TextDirection.ltr');
    reports.writeAsStringSync(text);
  }

  final quick = File('lib/features/finance/widgets/quick_transaction_bottom_sheet.dart');
  if (quick.existsSync()) {
    var text = quick.readAsStringSync();
    text = text.replaceAll(
      'inputFormatters: const [MoneyInputFormatter(), LengthLimitingTextInputFormatter(18)],',
      'inputFormatters: [MoneyInputFormatter(), LengthLimitingTextInputFormatter(18)],',
    );
    text = text.replaceAll('value: _categoryId,', 'initialValue: _categoryId,');
    quick.writeAsStringSync(text);
  }
}

void _fixFinanceMobileOverflows() {
  final entry = File('lib/features/finance/finance_entry_screen.dart');
  if (entry.existsSync()) {
    var text = entry.readAsStringSync();
    text = text.replaceAll('expandedHeight: 245,', 'expandedHeight: 316,');
    text = text.replaceAll('padding: const EdgeInsets.fromLTRB(20, 66, 20, 18),', 'padding: const EdgeInsets.fromLTRB(20, 76, 20, 16),');
    text = text.replaceAll('style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: realColor)', 'style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: realColor)');
    text = text.replaceAll('const SizedBox(height: 6),\n          Text(_money(value)', 'const SizedBox(height: 4),\n          Text(_money(value)');
    text = text.replaceAll('const SizedBox(height: 8),\n          ClipRRect(', 'const SizedBox(height: 6),\n          ClipRRect(');
    text = text.replaceAll('padding: const EdgeInsets.all(12),\n      decoration: BoxDecoration', 'padding: const EdgeInsets.all(10),\n      decoration: BoxDecoration');
    entry.writeAsStringSync(text);
  }

  final transaction = File('lib/features/finance/create_transaction_screen.dart');
  if (transaction.existsSync()) {
    var text = transaction.readAsStringSync();
    text = _addIsExpandedToDropdowns(text);
    text = text.replaceAll("child: Text('Forma de Pagamento (Nenhuma)')", "child: Text('Nenhuma', overflow: TextOverflow.ellipsis)");
    text = text.replaceAll("child: Text('Sem Categoria')", "child: Text('Sem Categoria', overflow: TextOverflow.ellipsis)");
    text = text.replaceAll("child: Text('Sem Subcategoria')", "child: Text('Sem Subcategoria', overflow: TextOverflow.ellipsis)");
    text = text.replaceAll("child: Text('Sem conta')", "child: Text('Sem conta', overflow: TextOverflow.ellipsis)");
    text = text.replaceAll('child: Text(account.name)', 'child: Text(account.name, overflow: TextOverflow.ellipsis)');
    text = text.replaceAll('child: Text(category.name)', 'child: Text(category.name, overflow: TextOverflow.ellipsis)');
    text = text.replaceAll('child: Text(subcategory.name)', 'child: Text(subcategory.name, overflow: TextOverflow.ellipsis)');
    text = text.replaceAll('child: Text(method)', 'child: Text(method, overflow: TextOverflow.ellipsis)');
    transaction.writeAsStringSync(text);
  }
}

void _applySmartTaskCapture() {
  final entry = File('lib/features/tasks/tasks_entry_screen.dart');
  final button = File('lib/features/tasks/quick_add_task_button.dart');
  final sheet = File('lib/features/tasks/quick_add_task_sheet.dart');
  if (!entry.existsSync() || !button.existsSync() || !sheet.existsSync()) return;

  var entryText = entry.readAsStringSync();
  entryText = entryText.replaceAll(
    "floatingActionButton: const QuickAddTaskButton(label: 'Nova tarefa'),",
    "floatingActionButton: const SmartTaskActionButton(label: 'Capturar tarefa'),",
  );
  entry.writeAsStringSync(entryText);

  final combined = '${entry.readAsStringSync()}\n${button.readAsStringSync()}\n${sheet.readAsStringSync()}';
  for (final check in [
    'SmartTaskActionButton',
    "label: 'Capturar tarefa'",
    'Captura inteligente',
    '_SmartShortcutBar',
    'Mais opções',
    'CreateTaskScreen(',
    'recurrenceType: _recurrenceType',
    'tags: _tags.isEmpty ? null : _tags.join',
    'reminderEnabled: parsed.time != null',
  ]) {
    if (!combined.contains(check)) {
      stderr.writeln('ERRO Captura Inteligente: faltou "$check".');
      exit(1);
    }
  }
}

void _fixTasksEntrySyntax() {
  final file = File('lib/features/tasks/tasks_entry_screen.dart');
  if (!file.existsSync()) return;

  var text = file.readAsStringSync();
  text = text.replaceAll('}\\n\nclass _CompactSmartLists', '}\n\nclass _CompactSmartLists');
  text = text.replaceAll('}\\nclass _CompactSmartLists', '}\nclass _CompactSmartLists');
  if (text.contains('}\\n\nclass _CompactSmartLists') || text.contains('}\\nclass _CompactSmartLists')) {
    stderr.writeln('ERRO: literal \\n ainda aparece antes de _CompactSmartLists.');
    exit(1);
  }
  file.writeAsStringSync(text);
}

void _fixHomeDashboardCompatibility() {
  final home = File('lib/features/dashboard/home_screen.dart');
  if (home.existsSync()) {
    var text = home.readAsStringSync();
    text = text.replaceAll("import 'package:intl/intl.dart';\n", '');
    home.writeAsStringSync(text);
  }

  final transaction = File('lib/features/finance/create_transaction_screen.dart');
  if (!transaction.existsSync()) return;
  var text = transaction.readAsStringSync();

  if (text.contains('class CreateTransactionScreen extends ConsumerStatefulWidget') && !text.contains('final FinancialTransaction? transaction;')) {
    text = text.replaceFirst(
      'class CreateTransactionScreen extends ConsumerStatefulWidget {\n  const CreateTransactionScreen({super.key});',
      'class CreateTransactionScreen extends ConsumerStatefulWidget {\n  final FinancialTransaction? transaction;\n  const CreateTransactionScreen({super.key, this.transaction});',
    );
  }

  if (text.contains('class CreateTransactionScreen extends ConsumerStatefulWidget') && !text.contains('widget.transaction')) {
    text = text.replaceFirst('  bool get _isEditing =>', '  bool get _isEditing => widget.transaction?.id != null ||');
  }

  if (!text.contains('final FinancialTransaction? transaction;')) {
    stderr.writeln('ERRO: CreateTransactionScreen não aceita transaction para edição pela Home.');
    exit(1);
  }

  transaction.writeAsStringSync(text);
}

void _fixHomeGlobalFabOverlap() {
  final home = File('lib/features/dashboard/home_screen.dart');
  if (!home.existsSync()) return;

  var text = home.readAsStringSync();
  text = text.replaceAll(
    'floatingActionButton: const UniversalQuickActionButton(),',
    'floatingActionButton: _currentIndex == 0 ? const UniversalQuickActionButton() : null,',
  );

  if (text.contains('floatingActionButton: const UniversalQuickActionButton(),')) {
    stderr.writeln('ERRO: FAB universal global ainda aparece em todas as abas.');
    exit(1);
  }
  if (!text.contains('floatingActionButton: _currentIndex == 0 ? const UniversalQuickActionButton() : null,')) {
    stderr.writeln('ERRO: regra de FAB universal apenas na Home não foi aplicada.');
    exit(1);
  }

  home.writeAsStringSync(text);
}

String _removeMethodByName(String source, String methodName) {
  var text = source;
  while (true) {
    final nameIndex = text.indexOf(methodName);
    if (nameIndex == -1) return text;
    final openParenIndex = text.indexOf('(', nameIndex);
    if (openParenIndex == -1) return text;
    final openBraceIndex = text.indexOf('{', openParenIndex);
    if (openBraceIndex == -1) return text;

    var start = text.lastIndexOf('\n', nameIndex);
    start = start == -1 ? 0 : start + 1;
    var depth = 0;
    var end = -1;
    for (var i = openBraceIndex; i < text.length; i++) {
      if (text[i] == '{') depth++;
      if (text[i] == '}') {
        depth--;
        if (depth == 0) {
          end = i + 1;
          break;
        }
      }
    }
    if (end == -1) return text;
    while (end < text.length && (text[end] == '\n' || text[end] == '\r')) end++;
    text = text.replaceRange(start, end, '');
  }
}

String _removeClassByName(String source, String className) {
  var text = source;
  while (true) {
    final classIndex = text.indexOf('class $className');
    if (classIndex == -1) return text;
    final openBraceIndex = text.indexOf('{', classIndex);
    if (openBraceIndex == -1) return text;

    var start = text.lastIndexOf('\n', classIndex);
    start = start == -1 ? 0 : start + 1;
    var depth = 0;
    var end = -1;
    for (var i = openBraceIndex; i < text.length; i++) {
      if (text[i] == '{') depth++;
      if (text[i] == '}') {
        depth--;
        if (depth == 0) {
          end = i + 1;
          break;
        }
      }
    }
    if (end == -1) return text;
    while (end < text.length && (text[end] == '\n' || text[end] == '\r')) end++;
    text = text.replaceRange(start, end, '');
  }
}

String _addIsExpandedToDropdowns(String text) {
  final buffer = StringBuffer();
  var cursor = 0;
  while (true) {
    final start = text.indexOf('DropdownButtonFormField', cursor);
    if (start == -1) {
      buffer.write(text.substring(cursor));
      break;
    }
    final openParen = text.indexOf('(', start);
    if (openParen == -1) {
      buffer.write(text.substring(cursor));
      break;
    }
    final end = _findCallEnd(text, openParen);
    if (end == -1) {
      buffer.write(text.substring(cursor));
      break;
    }
    buffer.write(text.substring(cursor, start));
    var block = text.substring(start, end);
    if (!block.contains('isExpanded: true,')) {
      final insertAt = block.indexOf('(') + 1;
      block = block.replaceRange(insertAt, insertAt, '\n                isExpanded: true,');
    }
    buffer.write(block);
    cursor = end;
  }
  return buffer.toString();
}

int _findCallEnd(String text, int openParenIndex) {
  var depth = 0;
  for (var i = openParenIndex; i < text.length; i++) {
    if (text[i] == '(') depth++;
    if (text[i] == ')') {
      depth--;
      if (depth == 0) {
        var end = i + 1;
        if (end < text.length && text[end] == ',') end++;
        return end;
      }
    }
  }
  return -1;
}

void _replaceInFile(String path, String from, String to) {
  final file = File(path);
  if (!file.existsSync()) return;
  final text = file.readAsStringSync();
  if (text.contains(from)) file.writeAsStringSync(text.replaceFirst(from, to));
}
