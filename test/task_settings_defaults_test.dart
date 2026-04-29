import 'package:diasorganize/features/tasks/quick_add_task_sheet.dart';
import 'package:diasorganize/features/tasks/task_settings_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TaskSettingsDefaults', () {
    test('declara defaults para todas as chaves de tarefas', () {
      expect(TaskSettingsDefaults.values.keys, containsAll([
        TaskSettingsKeys.defaultView,
        TaskSettingsKeys.showCompletedInline,
        TaskSettingsKeys.showSubtasksInline,
        TaskSettingsKeys.showProjectBadges,
        TaskSettingsKeys.defaultSort,
        TaskSettingsKeys.defaultReminderHour,
        TaskSettingsKeys.quickAddDefaultPriority,
        TaskSettingsKeys.inboxAsDefaultCapture,
      ]));
    });

    test('mantém valores padrão compatíveis com telas operacionais', () {
      expect(TaskSettingsDefaults.values[TaskSettingsKeys.defaultSort], 'schedule_priority');
      expect(TaskSettingsDefaults.values[TaskSettingsKeys.quickAddDefaultPriority], 'media');
      expect(TaskSettingsDefaults.values[TaskSettingsKeys.inboxAsDefaultCapture], 'true');
      expect(TaskSettingsDefaults.values[TaskSettingsKeys.defaultReminderHour], '09:00');
    });
  });

  group('QuickAddTaskParser com defaults configuráveis', () {
    test('usa prioridade padrão quando o texto não informa prioridade', () {
      final parsed = QuickAddTaskParser.parse(
        'Comprar pão hoje 08:30',
        now: DateTime(2026, 4, 28, 7),
        defaultPriority: 'alta',
      );

      expect(parsed.title, 'Comprar pão');
      expect(parsed.priority, 'alta');
      expect(parsed.time, '08:30');
      expect(parsed.date, DateTime(2026, 4, 28));
    });

    test('prioridade explícita do texto sobrescreve prioridade padrão', () {
      final parsed = QuickAddTaskParser.parse(
        'Enviar relatório amanhã #baixa',
        now: DateTime(2026, 4, 28, 7),
        defaultPriority: 'alta',
      );

      expect(parsed.title, 'Enviar relatório');
      expect(parsed.priority, 'baixa');
      expect(parsed.date, DateTime(2026, 4, 29));
    });

    test('prioridade padrão inválida cai para média', () {
      final parsed = QuickAddTaskParser.parse('Tarefa simples', defaultPriority: 'urgente');

      expect(parsed.title, 'Tarefa simples');
      expect(parsed.priority, 'media');
    });
  });
}
