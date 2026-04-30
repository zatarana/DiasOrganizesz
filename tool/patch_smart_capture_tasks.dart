import 'dart:io';

void main() {
  final entry = File('lib/features/tasks/tasks_entry_screen.dart');
  final button = File('lib/features/tasks/quick_add_task_button.dart');
  final sheet = File('lib/features/tasks/quick_add_task_sheet.dart');

  if (!entry.existsSync() || !button.existsSync() || !sheet.existsSync()) {
    stderr.writeln('Arquivos de tarefas não encontrados para Captura Inteligente.');
    exit(1);
  }

  var entryText = entry.readAsStringSync();
  entryText = entryText.replaceAll(
    "floatingActionButton: const QuickAddTaskButton(label: 'Nova tarefa'),",
    "floatingActionButton: const SmartTaskActionButton(label: 'Capturar tarefa'),",
  );
  entry.writeAsStringSync(entryText);

  final buttonText = button.readAsStringSync();
  final sheetText = sheet.readAsStringSync();

  final checks = <String, String>{
    'TasksEntryScreen': entryText,
    'QuickAddTaskButton': buttonText,
    'QuickAddTaskSheet': sheetText,
  };

  final requiredChecks = <String>[
    'SmartTaskActionButton',
    "label: 'Capturar tarefa'",
    'Captura inteligente',
    '_SmartShortcutBar',
    'Mais opções',
    'CreateTaskScreen(',
    'recurrenceType: _recurrenceType',
    'tags: _tags.isEmpty ? null : _tags.join',
    'reminderEnabled: parsed.time != null',
  ];

  final allText = checks.values.join('\n');
  for (final check in requiredChecks) {
    if (!allText.contains(check)) {
      stderr.writeln('ERRO Captura Inteligente: faltou "$check".');
      exit(1);
    }
  }

  if (entryText.contains("QuickAddTaskButton(label: 'Nova tarefa')")) {
    stderr.writeln('ERRO Captura Inteligente: TasksEntryScreen ainda usa o botão antigo Nova tarefa.');
    exit(1);
  }

  stdout.writeln('Captura Inteligente de tarefas aplicada.');
}
