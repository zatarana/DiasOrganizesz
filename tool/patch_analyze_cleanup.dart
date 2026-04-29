import 'dart:io';

void main() {
  _cleanFinanceScreen();
  _replaceDeprecatedOpacity([
    'lib/features/tasks/quick_add_task_sheet.dart',
    'lib/features/tasks/task_timeline_screen.dart',
    'lib/features/tasks/tasks_entry_screen.dart',
  ]);
  _fixConstInfoHints();
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

  if (text.contains('_paidExpensesByCategory(') ||
      text.contains('Widget _buildTypeFilters(') ||
      text.contains('Widget _buildStatusFilters(') ||
      text.contains('Widget _buildCategoryFilters(')) {
    stderr.writeln('ERRO: não foi possível remover todas as funções antigas de filtros/análise.');
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

  _replaceInFile(
    'lib/features/finance/create_transaction_screen.dart',
    '            _TransactionFormSection(\n              title: \'Observações\'',
    '            const _TransactionFormSection(\n              title: \'Observações\'',
  );

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

void _replaceInFile(String path, String from, String to) {
  final file = File(path);
  if (!file.existsSync()) return;
  final text = file.readAsStringSync();
  if (text.contains(from)) {
    file.writeAsStringSync(text.replaceFirst(from, to));
  }
}
