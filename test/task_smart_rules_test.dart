import 'package:diasorganize/data/models/task_model.dart';
import 'package:diasorganize/features/tasks/task_smart_rules.dart';
import 'package:flutter_test/flutter_test.dart';

Task task({
  int? id,
  String title = 'Tarefa',
  String? date,
  String? time,
  String priority = 'media',
  String status = 'pendente',
  int? projectId,
  int? projectStepId,
  int? parentTaskId,
}) {
  return Task(
    id: id,
    title: title,
    date: date,
    time: time,
    priority: priority,
    status: status,
    projectId: projectId,
    projectStepId: projectStepId,
    parentTaskId: parentTaskId,
    reminderEnabled: false,
    createdAt: '2026-04-01T00:00:00.000',
    updatedAt: '2026-04-01T00:00:00.000',
  );
}

void main() {
  group('TaskSmartRules', () {
    final now = DateTime(2026, 4, 28, 12);

    test('identifica tarefas de hoje incluindo atrasadas ativas', () {
      final today = task(date: '2026-04-28');
      final overdue = task(date: '2026-04-27');
      final future = task(date: '2026-04-29');
      final doneYesterday = task(date: '2026-04-27', status: 'concluida');

      expect(TaskSmartRules.isToday(today, now: now), true);
      expect(TaskSmartRules.isToday(overdue, now: now), true);
      expect(TaskSmartRules.isToday(future, now: now), false);
      expect(TaskSmartRules.isToday(doneYesterday, now: now), false);
    });

    test('identifica atraso considerando hora quando existir', () {
      final beforeNow = task(date: '2026-04-28', time: '08:00');
      final afterNow = task(date: '2026-04-28', time: '18:00');
      final yesterday = task(date: '2026-04-27');
      final completed = task(date: '2026-04-27', status: 'concluida');

      expect(TaskSmartRules.isOverdue(beforeNow, now: now), true);
      expect(TaskSmartRules.isOverdue(afterNow, now: now), false);
      expect(TaskSmartRules.isOverdue(yesterday, now: now), true);
      expect(TaskSmartRules.isOverdue(completed, now: now), false);
    });

    test('identifica Inbox como tarefa ativa sem data e sem vínculo de projeto', () {
      expect(TaskSmartRules.isInbox(task()), true);
      expect(TaskSmartRules.isInbox(task(date: '2026-04-28')), false);
      expect(TaskSmartRules.isInbox(task(projectId: 1)), false);
      expect(TaskSmartRules.isInbox(task(status: 'concluida')), false);
    });

    test('identifica próximos 7 dias sem incluir tarefas vencidas', () {
      expect(TaskSmartRules.isNextSevenDays(task(date: '2026-04-28'), now: now), true);
      expect(TaskSmartRules.isNextSevenDays(task(date: '2026-05-04'), now: now), true);
      expect(TaskSmartRules.isNextSevenDays(task(date: '2026-05-05'), now: now), false);
      expect(TaskSmartRules.isNextSevenDays(task(date: '2026-04-27'), now: now), false);
    });

    test('agrupa subtarefas por tarefa pai e ignora canceladas', () {
      final grouped = TaskSmartRules.subtasksByParent([
        task(id: 1, title: 'Pai'),
        task(id: 2, parentTaskId: 1, title: 'Sub 1'),
        task(id: 3, parentTaskId: 1, title: 'Sub 2', status: 'canceled'),
        task(id: 4, parentTaskId: 9, title: 'Sub órfã'),
      ]);

      expect(grouped[1]!.length, 1);
      expect(grouped[1]!.first.title, 'Sub 1');
      expect(grouped[9]!.length, 1);
    });

    test('calcula progresso do dia usando apenas tarefas pai exatamente de hoje', () {
      final progress = TaskSmartRules.dayProgress([
        task(id: 1, date: '2026-04-28', status: 'concluida'),
        task(id: 2, date: '2026-04-28'),
        task(id: 3, date: '2026-04-28', parentTaskId: 1, status: 'concluida'),
        task(id: 4, date: '2026-04-27', status: 'concluida'),
        task(id: 5, date: '2026-04-28', status: 'canceled'),
      ], now: now);

      expect(progress.total, 2);
      expect(progress.completed, 1);
      expect(progress.percent, 50);
      expect(progress.allDone, false);
    });

    test('sugere para hoje tarefas vencidas e sem data ordenadas por prioridade', () {
      final suggestions = TaskSmartRules.suggestedForToday([
        task(id: 1, title: 'Baixa sem data', priority: 'baixa'),
        task(id: 2, title: 'Alta vencida', priority: 'alta', date: '2026-04-20'),
        task(id: 3, title: 'Hoje não entra', priority: 'alta', date: '2026-04-28'),
        task(id: 4, title: 'Concluída sem data', priority: 'alta', status: 'concluida'),
      ], now: now);

      expect(suggestions.map((item) => item.title).toList(), ['Alta vencida', 'Baixa sem data']);
    });
  });
}
