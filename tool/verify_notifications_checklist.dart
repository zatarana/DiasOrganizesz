import 'dart:io';

void main() {
  final failures = <String>[];
  final service = _read('lib/core/notifications/notification_service.dart', failures);
  final providers = _read('lib/domain/providers.dart', failures);
  final main = _read('lib/main.dart', failures);
  final androidManifest = _read('android/app/src/main/AndroidManifest.xml', failures, required: false);

  _mustContain(service, 'DarwinInitializationSettings', 'NotificationService precisa configurar DarwinInitializationSettings para iOS/macOS.', failures);
  _mustContain(service, 'requestPermissions(alert: true, badge: true, sound: true)', 'NotificationService precisa solicitar permissões iOS/macOS.', failures);
  _mustContain(service, 'requestNotificationsPermission()', 'NotificationService precisa solicitar permissão Android 13+.', failures);
  _mustContain(service, 'requestExactAlarmsPermission()', 'NotificationService precisa solicitar alarme exato Android.', failures);
  _mustContain(service, 'AndroidScheduleMode.exactAllowWhileIdle', 'Agendamento exato precisa usar exactAllowWhileIdle.', failures);
  _mustContain(service, 'AndroidScheduleMode.inexactAllowWhileIdle', 'Agendamento precisa ter fallback inexato.', failures);

  _mustContain(service, 'int taskReminderId(int taskId)', 'ID principal de tarefa ausente.', failures);
  _mustContain(service, 'int taskReminderOffsetId(int taskId, int index)', 'IDs de offsets de tarefa ausentes.', failures);
  _mustContain(service, 'Future<void> cancelTaskReminderSet(int taskId)', 'Cancelamento completo de lembretes de tarefa ausente.', failures);
  _mustContain(service, 'cancelNotification(taskReminderId(taskId))', 'cancelTaskReminderSet deve cancelar o lembrete principal.', failures);
  _mustContain(service, 'cancelNotification(taskReminderOffsetId(taskId, index))', 'cancelTaskReminderSet deve cancelar offsets.', failures);
  _mustContain(service, 'Future<void> syncTaskReminder(Task task)', 'Sincronização central de tarefas ausente.', failures);
  _mustContain(service, 'parseReminderOffsets(task.reminderOffsets)', 'syncTaskReminder precisa respeitar offsets salvos.', failures);
  _mustContain(service, 'Future<void> syncTransactionReminder', 'Sincronização central de transações ausente.', failures);
  _mustContain(service, 'Future<void> syncProjectReminder', 'Sincronização central de projetos ausente.', failures);
  _mustContain(service, 'Future<void> syncProjectStepReminder', 'Sincronização central de etapas ausente.', failures);
  _mustContain(service, 'Future<void> rescheduleAllActiveNotifications(DatabaseHelper db)', 'Reagendamento global ausente.', failures);
  _mustContain(service, 'await cancelAllNotifications();', 'Reagendamento global deve limpar notificações antigas antes de recriar.', failures);

  _mustContain(main, 'await notificationService.init();', 'main.dart precisa inicializar NotificationService antes do app.', failures);
  _mustContain(main, 'await notificationService.rescheduleAllActiveNotifications(DatabaseHelper.instance);', 'main.dart precisa reagendar notificações no startup.', failures);

  _mustContain(providers, 'await NotificationService().syncTaskReminder(newTask);', 'TaskNotifier deve sincronizar lembrete ao criar tarefa.', failures);
  _mustContain(providers, 'await NotificationService().syncTaskReminder(task);', 'TaskNotifier deve sincronizar lembrete ao atualizar tarefa.', failures);
  _mustContain(providers, 'await NotificationService().cancelTaskReminderSet(id);', 'TaskNotifier deve cancelar conjunto completo ao excluir tarefa.', failures);
  _mustContain(providers, 'syncTransactionReminder(t, debtsReminderDaysBefore: daysBefore)', 'TransactionNotifier deve delegar lembretes ao NotificationService.', failures);
  _mustContain(providers, 'await NotificationService().syncProjectReminder(p);', 'ProjectNotifier deve delegar lembretes ao NotificationService.', failures);
  _mustContain(providers, 'await NotificationService().syncProjectStepReminder(step);', 'ProjectStepNotifier deve delegar lembretes ao NotificationService.', failures);

  _mustNotContain(providers, 'cancelNotification(NotificationService().taskReminderId', 'Cancelamento de tarefa não pode usar apenas taskReminderId.', failures);
  _mustNotContain(providers, 'notificationService.taskReminderId(task.id!)', 'Cancelamento de tarefa não pode usar apenas taskReminderId via variável local.', failures);
  _mustNotContain(providers, 'scheduleNotification(\n          id: NotificationService().taskReminderOffsetId', 'UI/Provider não deve agendar offset manual fora do NotificationService.', failures);

  if (androidManifest.isNotEmpty) {
    _mustContain(androidManifest, 'android.permission.POST_NOTIFICATIONS', 'AndroidManifest precisa declarar POST_NOTIFICATIONS.', failures);
    _mustContain(androidManifest, 'android.permission.SCHEDULE_EXACT_ALARM', 'AndroidManifest precisa declarar SCHEDULE_EXACT_ALARM.', failures);
    _mustContain(androidManifest, 'android.permission.RECEIVE_BOOT_COMPLETED', 'AndroidManifest precisa declarar RECEIVE_BOOT_COMPLETED.', failures);
  }

  if (failures.isNotEmpty) {
    stderr.writeln('ERRO checklist notificações:');
    for (final failure in failures) {
      stderr.writeln('- $failure');
    }
    exit(1);
  }

  stdout.writeln('Checklist de notificações validado com sucesso.');
}

String _read(String path, List<String> failures, {bool required = true}) {
  final file = File(path);
  if (!file.existsSync()) {
    if (required) failures.add('Arquivo obrigatório não encontrado: $path');
    return '';
  }
  return file.readAsStringSync();
}

void _mustContain(String text, String expected, String message, List<String> failures) {
  if (!text.contains(expected)) failures.add(message);
}

void _mustNotContain(String text, String forbidden, String message, List<String> failures) {
  if (text.contains(forbidden)) failures.add(message);
}
