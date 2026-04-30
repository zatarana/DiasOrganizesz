import 'dart:io';

void main() {
  _fixHome();
  _fixReports();
  _fixQuickTransaction();
  _fixTasksEntry();
  _fixSavePatcher();
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
