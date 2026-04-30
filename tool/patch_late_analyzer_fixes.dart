import 'dart:io';

void main() {
  _fixHomeFab();
  _fixFinanceReportsTextDirection();
  _fixTasksEntryLiteralNewline();
  _fixInputSavePatcherInterpolation();
  stdout.writeln('Correções finais pré-analyzer aplicadas.');
}

void _fixHomeFab() {
  final file = File('lib/features/dashboard/home_screen.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();

  text = text.replaceAll("import 'package:intl/intl.dart';\n", '');
  text = text.replaceAll(
    'floatingActionButton: const UniversalQuickActionButton(),',
    'floatingActionButton: _currentIndex == 0 ? const UniversalQuickActionButton() : null,',
  );

  text = text.replaceAll(
    '''    return FloatingActionButton(
      tooltip: 'Capturar rapidamente',
      onPressed: () => QuickAddTaskSheet.show(context),
      onLongPress: () => _showUniversalActions(context),
      child: const Icon(Icons.add),
    );''',
    '''    return GestureDetector(
      onLongPress: () => _showUniversalActions(context),
      child: FloatingActionButton(
        tooltip: 'Capturar rapidamente',
        onPressed: () => QuickAddTaskSheet.show(context),
        child: const Icon(Icons.add),
      ),
    );''',
  );

  if (text.contains('onLongPress: () => _showUniversalActions(context),\n      child: const Icon(Icons.add),')) {
    stderr.writeln('ERRO late analyzer: onLongPress ainda está dentro do FloatingActionButton.');
    exit(1);
  }
  if (!text.contains('floatingActionButton: _currentIndex == 0 ? const UniversalQuickActionButton() : null,')) {
    stderr.writeln('ERRO late analyzer: FAB universal ainda não está limitado à aba Início.');
    exit(1);
  }

  file.writeAsStringSync(text);
}

void _fixFinanceReportsTextDirection() {
  final file = File('lib/features/finance/finance_reports_screen.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();

  if (!text.contains("import 'dart:ui' as ui;")) {
    text = text.replaceFirst("import 'dart:math' as math;\n", "import 'dart:math' as math;\nimport 'dart:ui' as ui;\n");
  }
  text = text.replaceAll('TextDirection.ltr', 'ui.TextDirection.ltr');

  if (!text.contains('ui.TextDirection.ltr')) {
    stderr.writeln('ERRO late analyzer: TextDirection.ltr não foi qualificado com ui.');
    exit(1);
  }

  file.writeAsStringSync(text);
}

void _fixTasksEntryLiteralNewline() {
  final file = File('lib/features/tasks/tasks_entry_screen.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();

  text = text.replaceAll('}\\n\nclass _CompactSmartLists', '}\n\nclass _CompactSmartLists');
  text = text.replaceAll('}\\nclass _CompactSmartLists', '}\nclass _CompactSmartLists');

  if (text.contains('}\\n\nclass _CompactSmartLists') || text.contains('}\\nclass _CompactSmartLists')) {
    stderr.writeln('ERRO late analyzer: literal \\n ainda aparece antes de _CompactSmartLists.');
    exit(1);
  }

  file.writeAsStringSync(text);
}

void _fixInputSavePatcherInterpolation() {
  final file = File('tool/patch_input_save_reliability.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();

  text = text.replaceAll(
    "stderr.writeln('ERRO salvamento inputs: faltou \"$check\".');",
    "stderr.writeln('ERRO salvamento inputs: faltou requisito obrigatório.');",
  );

  if (text.contains('faltou \"$check\"')) {
    stderr.writeln('ERRO late analyzer: patch_input_save_reliability ainda referencia check em interpolação problemática.');
    exit(1);
  }

  file.writeAsStringSync(text);
}
