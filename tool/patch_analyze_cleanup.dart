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
  _fixDeprecatedFlutterApis();
  _fixFinanceMobileOverflows();
  stdout.writeln('Analyzer cleanup aplicado.');
}

void _cleanFinanceScreen() {
  final file = File('lib/features/finance/finance_screen.dart');
  if (!file.existsSync()) return;

  var text = file.readAsStringSync();
  text = _removeMethodByName(text, '_paidExpensesByCategory');
  text = _removeMethodByName(text, '_buildTypeFilters');
  text = _removeMethodByName(text, '_buildStatusFilters');
  text = _removeMethodByName(text, '_buildCategoryFilters');
  text = _removeMethodByName(text, '_gap');
  text = _removeMethodByName(text, '_filterChip');

  if (text.contains('_paidExpensesByCategory(') ||
      text.contains('Widget _buildTypeFilters(') ||
      text.contains('Widget _buildStatusFilters(') ||
      text.contains('Widget _buildCategoryFilters(') ||
      text.contains('Widget _gap(') ||
      text.contains('Widget _filterChip(')) {
    stderr.writeln('ERRO: não foi possível remover todas as funções antigas de filtros/análise.');
    exit(1);
  }

  file.writeAsStringSync(text);
}

void _cleanFinanceEntryScreen() {
  final file = File('lib/features/finance/finance_entry_screen.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();
  text = _removeClassByName(text, '_QuickChartsCard');
  text = _removeMethodByName(text, '_categoryHighlights');
  if (text.contains('class _QuickChartsCard') || text.contains('List<_CategoryHighlight> _categoryHighlights(')) {
    stderr.writeln('ERRO: não foi possível remover gráficos antigos não utilizados da entrada financeira.');
    exit(1);
  }
  file.writeAsStringSync(text);
}

void _cleanDebtsScreen() {
  final file = File('lib/features/debts/debts_screen.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();
  text = _removeMethodByName(text, '_money');
  if (text.contains('String _money(')) {
    stderr.writeln('ERRO: não foi possível remover _money não utilizado de debts_screen.dart.');
    exit(1);
  }
  file.writeAsStringSync(text);
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
      final char = text[i];
      if (char == '{') depth++;
      if (char == '}') {
        depth--;
        if (depth == 0) {
          end = i + 1;
          break;
        }
      }
    }

    if (end == -1) return text;
    while (end < text.length && (text[end] == '\n' || text[end] == '\r')) {
      end++;
    }
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
      final char = text[i];
      if (char == '{') depth++;
      if (char == '}') {
        depth--;
        if (depth == 0) {
          end = i + 1;
          break;
        }
      }
    }
    if (end == -1) return text;
    while (end < text.length && (text[end] == '\n' || text[end] == '\r')) {
      end++;
    }
    text = text.replaceRange(start, end, '');
  }
}

void _replaceDeprecatedOpacity(List<String> paths) {
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final text = file.readAsStringSync().replaceAll('.withOpacity(', '.withValues(alpha: ');
    file.writeAsStringSync(text);
  }
}

void _fixConstInfoHints() {
  _replaceInFile(
    'lib/core/notifications/notification_service.dart',
    '    final details = AndroidNotificationDetails(',
    '    const details = AndroidNotificationDetails(',
  );

  // Não torna a seção de Observações const: ela contém TextField com controller dinâmico.

  _replaceInFile(
    'lib/features/finance/finance_entry_screen.dart',
    '            FinanceHubScreen(),',
    '            const FinanceHubScreen(),',
  );
  _replaceInFile(
    'lib/features/finance/finance_hub_screen.dart',
    '            FinanceEntryScreen(),',
    '            const FinanceEntryScreen(),',
  );
  _replaceInFile(
    'lib/features/finance/finance_reports_screen.dart',
    '            FinanceScreen(),',
    '            const FinanceScreen(),',
  );
}

void _fixAnalyzerCompileErrors() {
  _replaceInFile(
    'lib/features/finance/finance_dashboard_planning.dart',
    'MoneyFormatter.format(usage.plannedSpent)',
    'MoneyFormatter.format(usage.plannedAmount)',
  );

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
    text = text.replaceAll(
      'value: _categoryId,',
      'initialValue: _categoryId,',
    );
    quick.writeAsStringSync(text);
  }
}

void _fixDeprecatedFlutterApis() {
  final kanban = File('lib/features/tasks/task_kanban_screen.dart');
  if (kanban.existsSync()) {
    var text = kanban.readAsStringSync();
    text = text.replaceAll(
      'onWillAccept: (task) => task != null && _taskForColumn(task) != column.type,',
      'onWillAcceptWithDetails: (details) => _taskForColumn(details.data) != column.type,',
    );
    text = text.replaceAll(
      'onAccept: (task) => onTaskMoved(task, column.type),',
      'onAcceptWithDetails: (details) => onTaskMoved(details.data, column.type),',
    );
    kanban.writeAsStringSync(text);
  }
}

void _fixFinanceMobileOverflows() {
  _fixFinanceEntryHeaderOverflow();
  _fixCreateTransactionDropdownOverflow();
}

void _fixFinanceEntryHeaderOverflow() {
  final file = File('lib/features/finance/finance_entry_screen.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();

  text = text.replaceAll('expandedHeight: 245,', 'expandedHeight: 316,');
  text = text.replaceAll('padding: const EdgeInsets.fromLTRB(20, 66, 20, 18),', 'padding: const EdgeInsets.fromLTRB(20, 76, 20, 16),');
  text = text.replaceAll('style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: realColor)', 'style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: realColor)');
  text = text.replaceAll('const SizedBox(height: 6),\n          Text(_money(value)', 'const SizedBox(height: 4),\n          Text(_money(value)');
  text = text.replaceAll('const SizedBox(height: 8),\n          ClipRRect(', 'const SizedBox(height: 6),\n          ClipRRect(');
  text = text.replaceAll('padding: const EdgeInsets.all(12),\n      decoration: BoxDecoration', 'padding: const EdgeInsets.all(10),\n      decoration: BoxDecoration');

  file.writeAsStringSync(text);
}

void _fixCreateTransactionDropdownOverflow() {
  final file = File('lib/features/finance/create_transaction_screen.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();

  text = _addIsExpandedToDropdowns(text);
  text = text.replaceAll("child: Text('Forma de Pagamento (Nenhuma)')", "child: Text('Nenhuma', overflow: TextOverflow.ellipsis)");
  text = text.replaceAll("child: Text('Sem Categoria')", "child: Text('Sem Categoria', overflow: TextOverflow.ellipsis)");
  text = text.replaceAll("child: Text('Sem Subcategoria')", "child: Text('Sem Subcategoria', overflow: TextOverflow.ellipsis)");
  text = text.replaceAll("child: Text('Sem conta')", "child: Text('Sem conta', overflow: TextOverflow.ellipsis)");
  text = text.replaceAll('child: Text(account.name)', 'child: Text(account.name, overflow: TextOverflow.ellipsis)');
  text = text.replaceAll('child: Text(category.name)', 'child: Text(category.name, overflow: TextOverflow.ellipsis)');
  text = text.replaceAll('child: Text(subcategory.name)', 'child: Text(subcategory.name, overflow: TextOverflow.ellipsis)');
  text = text.replaceAll('child: Text(method)', 'child: Text(method, overflow: TextOverflow.ellipsis)');

  file.writeAsStringSync(text);
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
    final char = text[i];
    if (char == '(') depth++;
    if (char == ')') {
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
  if (text.contains(from)) {
    file.writeAsStringSync(text.replaceFirst(from, to));
  }
}
