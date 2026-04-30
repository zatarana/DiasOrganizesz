import 'dart:io';

String _asSource(String text) => text.replaceAll(r'\n', '\n');

void main() {
  final file = File('lib/features/tasks/today_tasks_screen.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }

  var text = file.readAsStringSync();

  final headerStart = text.indexOf('class _TodayHeader extends StatelessWidget {');
  final headerEnd = text.indexOf('class _TodaySection extends StatelessWidget {', headerStart);
  if (headerStart == -1 || headerEnd == -1) {
    stderr.writeln('ERRO: não foi possível localizar _TodayHeader para aplicar T-M1.');
    exit(1);
  }
  text = text.replaceRange(headerStart, headerEnd, _asSource(_todayHeaderSource));

  final tileStart = text.indexOf('class _TodayTaskTile extends StatelessWidget {');
  final tileEnd = text.indexOf('class _TodayBadge extends StatelessWidget {', tileStart);
  if (tileStart == -1 || tileEnd == -1) {
    stderr.writeln('ERRO: não foi possível localizar _TodayTaskTile para aplicar T-M1.');
    exit(1);
  }
  text = text.replaceRange(tileStart, tileEnd, _asSource(_todayTaskTileSource));

  final checks = <String>[
    'TweenAnimationBuilder<double>',
    'Celebração do dia',
    'Dismissible(',
    'Adiar para amanhã',
    "label: 'Atrasada'",
    'confirmDismiss:',
  ];
  for (final check in checks) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO: patch T-M1 incompleto. Faltou: $check');
      exit(1);
    }
  }

  file.writeAsStringSync(text);
  stdout.writeln('today_tasks_screen.dart T-M1 aplicado: progresso visual, celebração, badge vermelho e swipe para adiar.');
}

const _todayHeaderSource = r'''class _TodayHeader extends StatelessWidget {
  final TaskDayProgress progress;
  final DateTime now;

  const _TodayHeader({required this.progress, required this.now});

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('EEEE, dd/MM', 'pt_BR').format(now);
    final percentText = '${progress.percent}%';
    final progressColor = progress.allDone && progress.total > 0 ? Colors.green : Theme.of(context).colorScheme.primary;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: progressColor.withValues(alpha: 0.14),
                  child: Icon(progress.allDone && progress.total > 0 ? Icons.celebration : Icons.today, color: progressColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(progress.allDone && progress.total > 0 ? 'Dia fechado' : 'Plano de hoje', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(label, style: TextStyle(color: Colors.grey.shade700)),
                    ],
                  ),
                ),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress.ratio),
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 58,
                          height: 58,
                          child: CircularProgressIndicator(
                            value: value.clamp(0.0, 1.0),
                            strokeWidth: 7,
                            backgroundColor: Colors.grey.shade200,
                            color: progressColor,
                          ),
                        ),
                        Text(percentText, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress.ratio),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(value: value.clamp(0.0, 1.0), minHeight: 9, color: progressColor),
            ),
            const SizedBox(height: 10),
            Text(
              progress.total == 0
                  ? 'Nenhuma tarefa exatamente marcada para hoje.'
                  : '${progress.completed}/${progress.total} tarefas de hoje concluídas.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (progress.allDone && progress.total > 0) ...[
              const SizedBox(height: 14),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.92, end: 1),
                duration: const Duration(milliseconds: 420),
                curve: Curves.elasticOut,
                builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
                  ),
                  child: const Row(
                    children: [
                      Text('🎉', style: TextStyle(fontSize: 24)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Celebração do dia', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                            SizedBox(height: 2),
                            Text('100% das tarefas de hoje concluídas. Excelente fechamento.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

''';

const _todayTaskTileSource = r'''class _TodayTaskTile extends StatelessWidget {
  final Task task;
  final Color accentColor;
  final VoidCallback onToggle;
  final VoidCallback onOpen;
  final VoidCallback onTomorrow;
  final VoidCallback onRemoveDate;
  final String? primaryActionLabel;
  final VoidCallback? onPrimaryAction;

  const _TodayTaskTile({
    required this.task,
    required this.accentColor,
    required this.onToggle,
    required this.onOpen,
    required this.onTomorrow,
    required this.onRemoveDate,
    this.primaryActionLabel,
    this.onPrimaryAction,
  });

  @override
  Widget build(BuildContext context) {
    final done = TaskSmartRules.isCompleted(task);
    final overdue = TaskSmartRules.isOverdue(task);
    final scheduled = TaskSmartRules.scheduledDateTime(task);
    final dateText = scheduled == null
        ? 'Sem data'
        : '${scheduled.day.toString().padLeft(2, '0')}/${scheduled.month.toString().padLeft(2, '0')}${TaskSmartRules.hasTime(task) ? ' ${task.time}' : ''}';

    final card = Card(
      color: overdue && !done ? Colors.red.withValues(alpha: 0.035) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: overdue && !done ? Colors.red.withValues(alpha: 0.35) : Colors.transparent),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: IconButton(
            onPressed: onToggle,
            icon: Icon(done ? Icons.check_circle : Icons.radio_button_unchecked, color: done ? Colors.green : accentColor),
          ),
          title: Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(decoration: done ? TextDecoration.lineThrough : null, fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (overdue && !done) const _TodayBadge(icon: Icons.warning_amber, label: 'Atrasada', color: Colors.red),
                  _TodayBadge(icon: Icons.event, label: dateText, color: overdue ? Colors.red : Colors.blueGrey),
                  _TodayBadge(icon: Icons.flag, label: task.priority, color: _priorityColor(task.priority)),
                  if (task.projectId != null) const _TodayBadge(icon: Icons.rocket_launch, label: 'Projeto', color: Colors.purple),
                  if (task.recurrenceType != 'none') const _TodayBadge(icon: Icons.repeat, label: 'Recorrente', color: Colors.indigo),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (primaryActionLabel != null && onPrimaryAction != null)
                    OutlinedButton.icon(
                      onPressed: onPrimaryAction,
                      icon: const Icon(Icons.today, size: 16),
                      label: Text(primaryActionLabel!),
                    ),
                  OutlinedButton.icon(
                    onPressed: onTomorrow,
                    icon: const Icon(Icons.event_available, size: 16),
                    label: const Text('Amanhã'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onRemoveDate,
                    icon: const Icon(Icons.event_busy, size: 16),
                    label: const Text('Sem data'),
                  ),
                ],
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: onOpen,
        ),
      ),
    );

    return Dismissible(
      key: ValueKey('today_task_${task.id ?? task.createdAt}_quick_postpone'),
      direction: done ? DismissDirection.none : DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Adiar para amanhã', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
            SizedBox(width: 8),
            Icon(Icons.event_available, color: Colors.orange),
          ],
        ),
      ),
      confirmDismiss: (_) async {
        onTomorrow();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('"${task.title}" adiada para amanhã.')));
        return false;
      },
      child: card,
    );
  }

  static Color _priorityColor(String priority) {
    switch (priority) {
      case 'alta':
        return Colors.red;
      case 'media':
        return Colors.orange;
      case 'baixa':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}

''';
