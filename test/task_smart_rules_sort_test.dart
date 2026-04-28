import 'package:diasorganize/data/models/task_model.dart';
import 'package:diasorganize/features/tasks/task_smart_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TaskSmartRules.sortTasks', () {
    Task task({
      required String title,
      required String priority,
      String? date,
      String? time,
      String createdAt = '2026-04-28T10:00:00',
    }) {
      return Task(
        title: title,
        priority: priority,
        status: 'pendente',
        date: date,
        time: time,
        reminderEnabled: false,
        createdAt: createdAt,
        updatedAt: createdAt,
      );
    }

    test('schedule_priority ordena por data, prioridade e título', () {
      final tasks = [
        task(title: 'B sem data', priority: 'alta'),
        task(title: 'C amanhã', priority: 'baixa', date: '2026-04-29'),
        task(title: 'A hoje alta', priority: 'alta', date: '2026-04-28'),
        task(title: 'A hoje baixa', priority: 'baixa', date: '2026-04-28'),
      ];

      TaskSmartRules.sortTasks(tasks, sortKey: 'schedule_priority');

      expect(tasks.map((t) => t.title), [
        'A hoje alta',
        'A hoje baixa',
        'C amanhã',
        'B sem data',
      ]);
    });

    test('priority_schedule ordena por prioridade antes da data', () {
      final tasks = [
        task(title: 'Baixa hoje', priority: 'baixa', date: '2026-04-28'),
        task(title: 'Alta sem data', priority: 'alta'),
        task(title: 'Media hoje', priority: 'media', date: '2026-04-28'),
      ];

      TaskSmartRules.sortTasks(tasks, sortKey: 'priority_schedule');

      expect(tasks.map((t) => t.title), [
        'Alta sem data',
        'Media hoje',
        'Baixa hoje',
      ]);
    });

    test('title ordena alfabeticamente', () {
      final tasks = [
        task(title: 'Zebra', priority: 'alta'),
        task(title: 'Abacaxi', priority: 'baixa'),
        task(title: 'Mesa', priority: 'media'),
      ];

      TaskSmartRules.sortTasks(tasks, sortKey: 'title');

      expect(tasks.map((t) => t.title), ['Abacaxi', 'Mesa', 'Zebra']);
    });

    test('created_desc ordena mais recentes primeiro', () {
      final tasks = [
        task(title: 'Antiga', priority: 'media', createdAt: '2026-04-20T10:00:00'),
        task(title: 'Nova', priority: 'media', createdAt: '2026-04-28T10:00:00'),
        task(title: 'Intermediária', priority: 'media', createdAt: '2026-04-25T10:00:00'),
      ];

      TaskSmartRules.sortTasks(tasks, sortKey: 'created_desc');

      expect(tasks.map((t) => t.title), ['Nova', 'Intermediária', 'Antiga']);
    });
  });
}
