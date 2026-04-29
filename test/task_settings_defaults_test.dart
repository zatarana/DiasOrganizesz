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
      expect(TaskSettingsDefaults.values[TaskSettingsKeys.defaultView], 'central');
      expect(TaskSettingsDefaults.values[TaskSettingsKeys.defaultSort], 'schedule_priority');
      expect(TaskSettingsDefaults.values[TaskSettingsKeys.quickAddDefaultPriority], 'media');
      expect(TaskSettingsDefaults.values[TaskSettingsKeys.inboxAsDefaultCapture], 'true');
      expect(TaskSettingsDefaults.values[TaskSettingsKeys.defaultReminderHour], '09:00');
    });

    test('mantém flags booleanas como strings aceitas pela tela de configurações', () {
      expect(TaskSettingsDefaults.values[TaskSettingsKeys.showCompletedInline], anyOf('true', 'false'));
      expect(TaskSettingsDefaults.values[TaskSettingsKeys.showSubtasksInline], anyOf('true', 'false'));
      expect(TaskSettingsDefaults.values[TaskSettingsKeys.showProjectBadges], anyOf('true', 'false'));
      expect(TaskSettingsDefaults.values[TaskSettingsKeys.inboxAsDefaultCapture], anyOf('true', 'false'));
    });
  });
}
