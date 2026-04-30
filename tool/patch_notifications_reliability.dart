import 'dart:io';

void main() {
  _patchProviders();
  _patchCreateTaskScreen();
  _validate();
  stdout.writeln('Notificações: sincronização centralizada aplicada.');
}

void _patchProviders() {
  final file = File('lib/domain/providers.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }

  var text = file.readAsStringSync();

  text = text.replaceAll(
    "    if (newTask.projectId != null) {\n      await ref.read(projectsProvider.notifier).recalculateProgress(newTask.projectId!);\n    }\n    return newTask;",
    "    if (newTask.projectId != null) {\n      await ref.read(projectsProvider.notifier).recalculateProgress(newTask.projectId!);\n    }\n    await NotificationService().syncTaskReminder(newTask);\n    return newTask;",
  );

  text = text.replaceAll(
    "    await db.updateTask(task);\n\n    if (task.id != null && (task.status == 'concluida' || task.status == 'canceled' || !task.reminderEnabled || task.time == null || task.date == null)) {\n      await NotificationService().cancelNotification(NotificationService().taskReminderId(task.id!));\n    }\n\n    state = [for (final t in state) if (t.id == task.id) task else t];",
    "    await db.updateTask(task);\n    await NotificationService().syncTaskReminder(task);\n\n    state = [for (final t in state) if (t.id == task.id) task else t];",
  );

  text = text.replaceAll(
    "    await db.deleteTask(id);\n    await NotificationService().cancelNotification(NotificationService().taskReminderId(id));\n    state = state.where((t) => t.id != id).toList();",
    "    await db.deleteTask(id);\n    await NotificationService().cancelTaskReminderSet(id);\n    state = state.where((t) => t.id != id).toList();",
  );

  text = text.replaceAll(
    "        await db.deleteTask(t.id!);\n        await NotificationService().cancelNotification(NotificationService().taskReminderId(t.id!));",
    "        await db.deleteTask(t.id!);\n        await NotificationService().cancelTaskReminderSet(t.id!);",
  );

  text = text.replaceAll(
    "        await notificationService.cancelNotification(notificationService.taskReminderId(task.id!));",
    "        await notificationService.cancelTaskReminderSet(task.id!);",
  );

  text = text.replaceAll(
    "    _syncTransactionReminder(newTransaction);",
    "    await _syncTransactionReminder(newTransaction);",
  );
  text = text.replaceAll(
    "    _syncTransactionReminder(transaction);",
    "    await _syncTransactionReminder(transaction);",
  );
  text = text.replaceAll(
    "  void _syncTransactionReminder(FinancialTransaction t) {\n    if (t.id == null) return;\n    final reminderId = NotificationService().transactionReminderId(t.id!);\n\n    final shouldCancel = !t.reminderEnabled || t.status == 'paid' || t.status == 'canceled';\n    if (shouldCancel) {\n      NotificationService().cancelNotification(reminderId);\n      return;\n    }\n\n    final targetDate = DateTime.tryParse(t.dueDate ?? t.transactionDate);\n    if (targetDate == null) return;\n    final settings = ref.read(appSettingsProvider);\n    final daysBefore = t.debtId != null ? int.tryParse(settings[AppSettingKeys.debtsReminderDaysBefore] ?? '0') ?? 0 : 0;\n    final reminderBase = targetDate.subtract(Duration(days: daysBefore));\n    final reminderTime = DateTime(reminderBase.year, reminderBase.month, reminderBase.day, 9, 0);\n    if (reminderTime.isBefore(DateTime.now())) {\n      NotificationService().cancelNotification(reminderId);\n      return;\n    }\n\n    NotificationService().scheduleNotification(\n      id: reminderId,\n      title: t.type == 'income' ? 'Receita prevista próxima' : 'Despesa próxima do vencimento',\n      body: t.title,\n      scheduledDate: reminderTime,\n    );\n  }",
    "  Future<void> _syncTransactionReminder(FinancialTransaction t) async {\n    final settings = ref.read(appSettingsProvider);\n    final daysBefore = int.tryParse(settings[AppSettingKeys.debtsReminderDaysBefore] ?? '0') ?? 0;\n    await NotificationService().syncTransactionReminder(t, debtsReminderDaysBefore: daysBefore);\n  }",
  );

  text = text.replaceAll(
    "    _syncProjectReminder(created);",
    "    await _syncProjectReminder(created);",
  );
  text = text.replaceAll(
    "    _syncProjectReminder(project);",
    "    await _syncProjectReminder(project);",
  );
  text = text.replaceAll(
    "  void _syncProjectReminder(Project p) {\n    if (p.id == null) return;\n    final reminderId = NotificationService().projectReminderId(p.id!);\n    if (!p.reminderEnabled || p.status == 'completed' || p.status == 'canceled') {\n      NotificationService().cancelNotification(reminderId);\n      return;\n    }\n    final end = p.endDate == null ? null : DateTime.tryParse(p.endDate!);\n    if (end == null) {\n      NotificationService().cancelNotification(reminderId);\n      return;\n    }\n    final reminderTime = DateTime(end.year, end.month, end.day, 9, 0);\n    if (reminderTime.isBefore(DateTime.now())) {\n      NotificationService().cancelNotification(reminderId);\n      return;\n    }\n    NotificationService().scheduleNotification(id: reminderId, title: 'Prazo de projeto próximo', body: p.name, scheduledDate: reminderTime);\n  }",
    "  Future<void> _syncProjectReminder(Project p) async {\n    await NotificationService().syncProjectReminder(p);\n  }",
  );

  text = text.replaceAll(
    "    _syncStepReminder(newStep);",
    "    await _syncStepReminder(newStep);",
  );
  text = text.replaceAll(
    "    _syncStepReminder(step);",
    "    await _syncStepReminder(step);",
  );
  text = text.replaceAll(
    "  void _syncStepReminder(ProjectStep step) {\n    if (step.id == null) return;\n    final reminderId = NotificationService().projectStepReminderId(step.id!);\n    if (!step.reminderEnabled || step.status == 'completed' || step.status == 'canceled') {\n      NotificationService().cancelNotification(reminderId);\n      return;\n    }\n    final due = step.dueDate == null ? null : DateTime.tryParse(step.dueDate!);\n    if (due == null) {\n      NotificationService().cancelNotification(reminderId);\n      return;\n    }\n    final reminderTime = DateTime(due.year, due.month, due.day, 9, 0);\n    if (reminderTime.isBefore(DateTime.now())) {\n      NotificationService().cancelNotification(reminderId);\n      return;\n    }\n    NotificationService().scheduleNotification(id: reminderId, title: 'Prazo de etapa próximo', body: step.title, scheduledDate: reminderTime);\n  }",
    "  Future<void> _syncStepReminder(ProjectStep step) async {\n    await NotificationService().syncProjectStepReminder(step);\n  }",
  );

  file.writeAsStringSync(text);
}

void _patchCreateTaskScreen() {
  final file = File('lib/features/tasks/create_task_screen.dart');
  if (!file.existsSync()) return;

  var text = file.readAsStringSync();
  text = text.replaceAll(RegExp(r"\n\s*await NotificationService\(\)\.scheduleNotification\([\s\S]*?taskReminderOffsetId\([\s\S]*?\);"), '');
  text = text.replaceAll(RegExp(r"\n\s*await NotificationService\(\)\.cancelTaskReminderSet\([^;]+;"), '');
  file.writeAsStringSync(text);
}

void _validate() {
  final providers = File('lib/domain/providers.dart').readAsStringSync();
  final service = File('lib/core/notifications/notification_service.dart').readAsStringSync();

  final required = <String>[
    'await NotificationService().syncTaskReminder(newTask);',
    'await NotificationService().syncTaskReminder(task);',
    'await NotificationService().cancelTaskReminderSet(id);',
    'Future<void> _syncTransactionReminder',
    'syncTransactionReminder(t, debtsReminderDaysBefore: daysBefore)',
    'Future<void> _syncProjectReminder',
    'Future<void> _syncStepReminder',
    'Future<void> rescheduleAllActiveNotifications(DatabaseHelper db)',
    'Future<void> syncTaskReminder(Task task)',
    'Future<void> cancelTaskReminderSet(int taskId)',
  ];

  final combined = '$providers\n$service';
  for (final check in required) {
    if (!combined.contains(check)) {
      stderr.writeln('ERRO notificações: faltou "$check".');
      exit(1);
    }
  }

  if (providers.contains('cancelNotification(NotificationService().taskReminderId') ||
      providers.contains('notificationService.taskReminderId(task.id!)')) {
    stderr.writeln('ERRO notificações: cancelamento de tarefa ainda usa só taskReminderId.');
    exit(1);
  }
}
