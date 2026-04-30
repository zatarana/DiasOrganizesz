import 'dart:io';

void main() {
  final file = File('lib/features/tasks/today_tasks_screen.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }

  var text = file.readAsStringSync();

  text = text.replaceFirst(
    '''    final noDateSuggestions = TaskSmartRules.suggestedForToday(tasks, now: now)
        .where((task) => !TaskSmartRules.hasDate(task) && TaskSmartRules.isParentTask(task))
        .take(5)
        .toList();

    final allEmpty = overdueTasks.isEmpty && exactTodayTasks.isEmpty && noDateSuggestions.isEmpty;
''',
    '''    final noDateSuggestions = TaskSmartRules.suggestedForToday(tasks, now: now)
        .where((task) => !TaskSmartRules.hasDate(task) && TaskSmartRules.isParentTask(task))
        .take(5)
        .toList();
    final suggestionTasks = <Task>[
      ...overdueTasks,
      ...noDateSuggestions.where((candidate) => !overdueTasks.any((task) => task.id == candidate.id)),
    ];

    final allEmpty = overdueTasks.isEmpty && exactTodayTasks.isEmpty && noDateSuggestions.isEmpty;
''',
  );

  text = text.replaceFirst(
    '''          IconButton(
            tooltip: 'Criação completa para hoje',
            icon: const Icon(Icons.edit_note),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(selectedDate: now))),
          ),
''',
    '''          IconButton(
            tooltip: 'Sugestões para hoje',
            icon: const Icon(Icons.lightbulb_outline),
            onPressed: () => _openSuggestionsSheet(context, ref, suggestionTasks),
          ),
''',
  );

  text = text.replaceFirst(
    '''  static void _openTask(BuildContext context, Task task) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: task)));
  }
''',
    '''  static void _openSuggestionsSheet(BuildContext context, WidgetRef ref, List<Task> suggestions) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        if (suggestions.isEmpty) {
          return const Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: _TodayEmptyState(),
          );
        }
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              const Text('Sugestões para hoje', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(
                'Tarefas atrasadas e sem data que merecem atenção agora.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 12),
              ...suggestions.map((task) => Card(
                    child: ListTile(
                      leading: Icon(TaskSmartRules.isOverdue(task) ? Icons.warning_amber : Icons.lightbulb_outline, color: TaskSmartRules.isOverdue(task) ? Colors.red : Colors.orange),
                      title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(TaskSmartRules.isOverdue(task) ? 'Atrasada' : 'Sem data'),
                      trailing: Wrap(
                        spacing: 4,
                        children: [
                          TextButton(
                            onPressed: () {
                              _moveToToday(ref, task);
                              Navigator.pop(sheetContext);
                            },
                            child: const Text('Hoje'),
                          ),
                          TextButton(
                            onPressed: () {
                              _moveToTomorrow(ref, task);
                              Navigator.pop(sheetContext);
                            },
                            child: const Text('Amanhã'),
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _openTask(context, task);
                      },
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }

  static void _openTask(BuildContext context, Task task) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: task)));
  }
''',
  );

  final checks = <String>[
    'Sugestões para hoje',
    '_openSuggestionsSheet',
    'Icons.lightbulb_outline',
    'suggestionTasks',
  ];
  for (final check in checks) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO: patch Today incompleto. Faltou: $check');
      exit(1);
    }
  }
  if (text.contains("tooltip: 'Criação completa para hoje'")) {
    stderr.writeln('ERRO: ação duplicada de criação completa ainda existe na AppBar do Today.');
    exit(1);
  }

  file.writeAsStringSync(text);
  stdout.writeln('today_tasks_screen.dart refinado com sugestões no AppBar.');
}
