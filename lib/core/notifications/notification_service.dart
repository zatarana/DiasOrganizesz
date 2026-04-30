import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../data/database/db_helper.dart';
import '../../data/models/project_model.dart';
import '../../data/models/project_step_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/transaction_model.dart';

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  factory NotificationService() => _notificationService;

  NotificationService._internal();

  static const String _channelId = 'diasorganize_channel_id';
  static const String _channelName = 'DiasOrganize Lembretes';
  static const String _channelDescription = 'Canal de lembretes para tarefas, finanças, dívidas e projetos';

  Future<void> init() async {
    tz.initializeTimeZones();

    const initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsDarwin = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
      macOS: initializationSettingsDarwin,
    );
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);

    if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    final androidPlugin = flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    if (!scheduledDate.isAfter(DateTime.now())) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.max,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
      macOS: DarwinNotificationDetails(),
    );

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (error) {
      debugPrint('Falha ao agendar notificação exata, tentando modo inexato: $error');
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  int taskReminderId(int taskId) => taskId;
  int taskReminderOffsetId(int taskId, int index) => 400000 + (taskId * 10) + index;
  int transactionReminderId(int transactionId) => 100000 + transactionId;
  int projectReminderId(int projectId) => 200000 + projectId;
  int projectStepReminderId(int stepId) => 300000 + stepId;

  Future<void> cancelTaskReminderSet(int taskId) async {
    await cancelNotification(taskReminderId(taskId));
    for (var index = 0; index < 3; index++) {
      await cancelNotification(taskReminderOffsetId(taskId, index));
    }
  }

  Future<void> syncTaskReminder(Task task) async {
    final taskId = task.id;
    if (taskId == null) return;

    await cancelTaskReminderSet(taskId);

    final shouldSkip = !task.reminderEnabled ||
        task.time == null ||
        task.date == null ||
        task.status == 'concluida' ||
        task.status == 'canceled';
    if (shouldSkip) return;

    try {
      final parts = task.time!.split(':');
      if (parts.length < 2) return;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      final date = DateTime.tryParse(task.date!);
      if (hour == null || minute == null || date == null) return;

      final taskDateTime = DateTime(date.year, date.month, date.day, hour, minute);
      final offsets = parseReminderOffsets(task.reminderOffsets).take(3).toList();

      if (offsets.isEmpty) {
        await scheduleNotification(
          id: taskReminderId(taskId),
          title: 'Lembrete: ${task.title}',
          body: 'Sua tarefa está programada para agora!',
          scheduledDate: taskDateTime,
        );
        return;
      }

      for (var index = 0; index < offsets.length; index++) {
        final offset = offsets[index];
        final reminderTime = taskDateTime.subtract(Duration(minutes: offset));
        final label = reminderOffsetLabel(offset).toLowerCase();
        await scheduleNotification(
          id: taskReminderOffsetId(taskId, index),
          title: offset == 0 ? 'Lembrete: ${task.title}' : 'Lembrete: ${task.title} em $label',
          body: offset == 0 ? 'Sua tarefa está programada para agora!' : 'Sua tarefa está chegando: $label.',
          scheduledDate: reminderTime,
        );
      }
    } catch (error) {
      debugPrint('Erro ao sincronizar lembretes de tarefa: $error');
      await cancelTaskReminderSet(taskId);
    }
  }

  Future<void> syncTransactionReminder(FinancialTransaction transaction, {int debtsReminderDaysBefore = 0}) async {
    final id = transaction.id;
    if (id == null) return;

    final reminderId = transactionReminderId(id);
    await cancelNotification(reminderId);

    if (!transaction.reminderEnabled || transaction.status == 'paid' || transaction.status == 'canceled') return;

    final targetDate = DateTime.tryParse(transaction.dueDate ?? transaction.transactionDate);
    if (targetDate == null) return;

    final daysBefore = transaction.debtId != null ? debtsReminderDaysBefore : 0;
    final reminderBase = targetDate.subtract(Duration(days: daysBefore));
    final reminderTime = DateTime(reminderBase.year, reminderBase.month, reminderBase.day, 9, 0);
    if (!reminderTime.isAfter(DateTime.now())) return;

    await scheduleNotification(
      id: reminderId,
      title: transaction.type == 'income' ? 'Receita prevista próxima' : 'Despesa próxima do vencimento',
      body: transaction.title,
      scheduledDate: reminderTime,
    );
  }

  Future<void> syncProjectReminder(Project project) async {
    final id = project.id;
    if (id == null) return;

    final reminderId = projectReminderId(id);
    await cancelNotification(reminderId);

    if (!project.reminderEnabled || project.status == 'completed' || project.status == 'canceled') return;

    final end = project.endDate == null ? null : DateTime.tryParse(project.endDate!);
    if (end == null) return;

    final reminderTime = DateTime(end.year, end.month, end.day, 9, 0);
    await scheduleNotification(id: reminderId, title: 'Prazo de projeto próximo', body: project.name, scheduledDate: reminderTime);
  }

  Future<void> syncProjectStepReminder(ProjectStep step) async {
    final id = step.id;
    if (id == null) return;

    final reminderId = projectStepReminderId(id);
    await cancelNotification(reminderId);

    if (!step.reminderEnabled || step.status == 'completed' || step.status == 'canceled') return;

    final due = step.dueDate == null ? null : DateTime.tryParse(step.dueDate!);
    if (due == null) return;

    final reminderTime = DateTime(due.year, due.month, due.day, 9, 0);
    await scheduleNotification(id: reminderId, title: 'Prazo de etapa próximo', body: step.title, scheduledDate: reminderTime);
  }

  Future<void> rescheduleAllActiveNotifications(DatabaseHelper db) async {
    try {
      await cancelAllNotifications();

      final tasks = await db.getTasks();
      final transactions = await db.getTransactions();
      final projects = (await db.getProjects()).map((map) => Project.fromMap(map)).toList();
      final steps = await db.getAllProjectSteps();
      final debtsReminderSetting = await db.getSetting('debts_reminder_days_before');
      final debtsReminderDaysBefore = int.tryParse(debtsReminderSetting?.value ?? '0') ?? 0;

      for (final task in tasks) {
        await syncTaskReminder(task);
      }
      for (final transaction in transactions) {
        await syncTransactionReminder(transaction, debtsReminderDaysBefore: debtsReminderDaysBefore);
      }
      for (final project in projects) {
        await syncProjectReminder(project);
      }
      for (final step in steps) {
        await syncProjectStepReminder(step);
      }
    } catch (error) {
      debugPrint('Erro ao re-agendar notificações no startup: $error');
    }
  }

  List<int> parseReminderOffsets(String? offsetsString) {
    if (offsetsString == null || offsetsString.trim().isEmpty) return const [];
    return offsetsString
        .split(',')
        .map((value) => int.tryParse(value.trim()))
        .whereType<int>()
        .where((value) => value >= 0)
        .toList();
  }

  String reminderOffsetLabel(int offset) {
    if (offset == 0) return 'no horário';
    if (offset == 5) return '5 minutos antes';
    if (offset == 10) return '10 minutos antes';
    if (offset == 30) return '30 minutos antes';
    if (offset == 60) return '1 hora antes';
    if (offset == 1440) return '1 dia antes';
    return '$offset minutos antes';
  }

  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
