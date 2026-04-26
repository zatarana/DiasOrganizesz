import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/task_model.dart';
import '../data/models/category_model.dart';
import '../data/models/financial_category_model.dart';
import '../data/models/debt_model.dart';
import '../data/models/setting_model.dart';
import '../data/models/transaction_model.dart';
import '../data/models/project_model.dart';
import '../data/models/project_step_model.dart';
import '../data/database/db_helper.dart';
import '../core/notifications/notification_service.dart';

final dbProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper.instance);

class AppSettingKeys {
  static const defaultCurrency = 'default_currency';
  static const homeShowFinancialValues = 'home_show_financial_values';
  static const financeDiscreteMode = 'finance_discrete_mode';
  static const financeVisualLock = 'finance_visual_lock';
  static const privacyHideHomeValues = 'privacy_hide_home_values';
  static const debtsShowPaid = 'debts_show_paid';
  static const debtsRemindersDefault = 'debts_reminders_default';
  static const debtsReminderDaysBefore = 'debts_reminder_days_before';
  static const projectsShowCompleted = 'projects_show_completed';
  static const projectsShowPaused = 'projects_show_paused';
  static const projectsDefaultSort = 'projects_default_sort';
  static const homeShowProjectsCard = 'home_show_projects_card';
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, Map<String, String>>((ref) {
  return AppSettingsNotifier(ref.watch(dbProvider));
});

class AppSettingsNotifier extends StateNotifier<Map<String, String>> {
  final DatabaseHelper db;
  AppSettingsNotifier(this.db) : super({
    AppSettingKeys.defaultCurrency: 'BRL',
    AppSettingKeys.homeShowFinancialValues: 'true',
    AppSettingKeys.financeDiscreteMode: 'false',
    AppSettingKeys.financeVisualLock: 'false',
    AppSettingKeys.privacyHideHomeValues: 'false',
    AppSettingKeys.debtsShowPaid: 'true',
    AppSettingKeys.debtsRemindersDefault: 'false',
    AppSettingKeys.debtsReminderDaysBefore: '0',
    AppSettingKeys.projectsShowCompleted: 'true',
    AppSettingKeys.projectsShowPaused: 'true',
    AppSettingKeys.projectsDefaultSort: 'created_desc',
    AppSettingKeys.homeShowProjectsCard: 'true',
  }) {
    loadSettings();
  }

  Future<void> loadSettings() async {
    final loaded = Map<String, String>.from(state);
    for (final key in state.keys) {
      final setting = await db.getSetting(key);
      if (setting != null) loaded[key] = setting.value;
    }
    state = loaded;
  }

  Future<void> setValue(String key, String value) async {
    await db.saveSetting(AppSetting(key: key, value: value));
    state = {...state, key: value};
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ref.watch(dbProvider));
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final DatabaseHelper db;
  ThemeModeNotifier(this.db) : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final setting = await db.getSetting('theme_mode');
    if (setting != null) {
      if (setting.value == 'light') state = ThemeMode.light;
      else if (setting.value == 'dark') state = ThemeMode.dark;
      else state = ThemeMode.system;
    }
  }

  Future<void> setTheme(ThemeMode mode) async {
    state = mode;
    String val = 'system';
    if (mode == ThemeMode.light) val = 'light';
    else if (mode == ThemeMode.dark) val = 'dark';
    await db.saveSetting(AppSetting(key: 'theme_mode', value: val));
  }
}

final categoriesProvider = StateNotifierProvider<CategoryNotifier, List<TaskCategory>>((ref) {
  return CategoryNotifier(ref.watch(dbProvider));
});

class CategoryNotifier extends StateNotifier<List<TaskCategory>> {
  final DatabaseHelper db;
  CategoryNotifier(this.db) : super([]) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    state = await db.getCategories();
  }

  Future<void> addCategory(TaskCategory category) async {
    final newCategory = await db.createCategory(category);
    state = [...state, newCategory];
  }

  Future<void> removeCategory(int id) async {
    await db.deleteCategory(id);
    state = state.where((c) => c.id != id).toList();
  }
}

final tasksProvider = StateNotifierProvider<TaskNotifier, List<Task>>((ref) {
  return TaskNotifier(ref.watch(dbProvider), ref);
});

class TaskNotifier extends StateNotifier<List<Task>> {
  final DatabaseHelper db;
  final Ref ref;
  TaskNotifier(this.db, this.ref) : super([]) {
    loadTasks();
  }

  bool _isOverdue(Task t) {
    if (t.date == null) return false;
    try {
      final currentDt = DateTime.parse(t.date!);
      if (t.time != null) {
        final parts = t.time!.split(':');
        final taskTime = DateTime(currentDt.year, currentDt.month, currentDt.day, int.parse(parts[0]), int.parse(parts[1]));
        return taskTime.isBefore(DateTime.now());
      } else {
        final taskDate = DateTime(currentDt.year, currentDt.month, currentDt.day, 23, 59, 59);
        return taskDate.isBefore(DateTime.now());
      }
    } catch (e) {
      return false;
    }
  }

  Future<void> loadTasks() async {
    final tasks = await db.getTasks();
    final updatedTasks = <Task>[];
    
    for (var t in tasks) {
      if (t.status == 'pendente' && _isOverdue(t)) {
        final updatedTask = t.copyWith(status: 'atrasada', updatedAt: DateTime.now().toIso8601String());
        await db.updateTask(updatedTask);
        updatedTasks.add(updatedTask);
      } else {
        updatedTasks.add(t);
      }
    }
    state = updatedTasks;
    final projectIds = state.where((t) => t.projectId != null).map((t) => t.projectId!).toSet();
    for (final id in projectIds) {
      await ref.read(projectsProvider.notifier).recalculateProgress(id);
    }
  }

  Future<Task> addTaskWithReturn(Task task) async {
    final newTask = await db.createTask(task);
    state = [...state, newTask];
    if (newTask.projectId != null) {
      await ref.read(projectsProvider.notifier).recalculateProgress(newTask.projectId!);
    }
    return newTask;
  }

  Future<void> addTask(Task task) async {
    await addTaskWithReturn(task);
  }

  Future<void> updateTask(Task task) async {
    await db.updateTask(task);
    if (task.status == 'concluida' && task.id != null) {
      NotificationService().cancelNotification(task.id!);
    }
    state = [
      for (final t in state)
        if (t.id == task.id) task else t
    ];

    if (task.projectId != null) {
      await ref.read(projectsProvider.notifier).recalculateProgress(task.projectId!);
    }
  }

  Future<void> removeTask(int id) async {
    final taskIdx = state.indexWhere((t) => t.id == id);
    final projectId = taskIdx == -1 ? null : state[taskIdx].projectId;
    await db.deleteTask(id);
    NotificationService().cancelNotification(id);
    state = state.where((t) => t.id != id).toList();
    if (projectId != null) {
      await ref.read(projectsProvider.notifier).recalculateProgress(projectId);
    }
  }

  Future<void> clearCompletedTasks() async {
    final completed = state.where((t) => t.status == 'concluida').toList();
    for (var t in completed) {
      if (t.id != null) {
        await db.deleteTask(t.id!);
        NotificationService().cancelNotification(t.id!);
      }
    }
    state = state.where((t) => t.status != 'concluida').toList();
  }
}

final transactionsProvider = StateNotifierProvider<TransactionNotifier, List<FinancialTransaction>>((ref) {
  return TransactionNotifier(ref.watch(dbProvider), ref);
});

class TransactionNotifier extends StateNotifier<List<FinancialTransaction>> {
  final DatabaseHelper db;
  final Ref ref;
  TransactionNotifier(this.db, this.ref) : super([]) {
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    state = await db.getTransactions();
  }

  Future<void> addTransaction(FinancialTransaction transaction) async {
    final newTransaction = await db.createTransaction(transaction);
    state = [newTransaction, ...state]; // Add to top since it sorted desc usually, though DB sort is date based
    _syncTransactionReminder(newTransaction);
    _checkDebtStatus(transaction.debtId);
  }

  Future<void> updateTransaction(FinancialTransaction transaction) async {
    await db.updateTransaction(transaction);
    state = [
      for (final t in state)
        if (t.id == transaction.id) transaction else t
    ];
    _syncTransactionReminder(transaction);
    _checkDebtStatus(transaction.debtId);
  }

  Future<void> removeTransaction(int id) async {
    final transaction = state.firstWhere((t) => t.id == id, orElse: () => state.first);
    await db.deleteTransaction(id);
    state = state.where((t) => t.id != id).toList();
    if (transaction.id != null) {
      NotificationService().cancelNotification(NotificationService().transactionReminderId(transaction.id!));
    }
    _checkDebtStatus(transaction.debtId);
  }

  Future<void> clearCanceledTransactions() async {
    final canceled = state.where((t) => t.status == 'canceled').toList();
    for (final t in canceled) {
      if (t.id == null) continue;
      await db.deleteTransaction(t.id!);
      NotificationService().cancelNotification(NotificationService().transactionReminderId(t.id!));
    }
    state = state.where((t) => t.status != 'canceled').toList();
  }

  void _syncTransactionReminder(FinancialTransaction t) {
    if (t.id == null) return;
    final reminderId = NotificationService().transactionReminderId(t.id!);

    final shouldCancel = !t.reminderEnabled || t.status == 'paid' || t.status == 'canceled';
    if (shouldCancel) {
      NotificationService().cancelNotification(reminderId);
      return;
    }

    final targetDate = DateTime.tryParse(t.dueDate ?? t.transactionDate);
    if (targetDate == null) return;
    final settings = ref.read(appSettingsProvider);
    final daysBefore = t.debtId != null ? int.tryParse(settings[AppSettingKeys.debtsReminderDaysBefore] ?? '0') ?? 0 : 0;
    final reminderBase = targetDate.subtract(Duration(days: daysBefore));
    final reminderTime = DateTime(reminderBase.year, reminderBase.month, reminderBase.day, 9, 0);
    if (reminderTime.isBefore(DateTime.now())) return;

    NotificationService().scheduleNotification(
      id: reminderId,
      title: t.type == 'income' ? 'Receita prevista próxima' : 'Despesa próxima do vencimento',
      body: t.title,
      scheduledDate: reminderTime,
    );
  }

  void _checkDebtStatus(int? debtId) {
    if (debtId == null) return;
    
    final debts = ref.read(debtsProvider);
    final idx = debts.indexWhere((d) => d.id == debtId);
    if (idx == -1) return;
    
    final debt = debts[idx];
    if (debt.status == 'canceled' || debt.status == 'paused') return;

    final debtTransactions = state.where((t) => t.debtId == debtId && t.status != 'canceled').toList();
    
    if (debtTransactions.isEmpty) return;

    final allPaid = debtTransactions.every((t) => t.status == 'paid');
    final hasOverdue = debtTransactions.any((t) => t.status == 'overdue');
    
    String newStatus = debt.status;

    if (allPaid) {
       newStatus = 'paid';
    } else if (hasOverdue) {
       newStatus = 'overdue';
    } else {
       newStatus = 'active';
    }
    
    if (newStatus != debt.status) {
      ref.read(debtsProvider.notifier).updateDebt(debt.copyWith(status: newStatus));
    }
  }
}

final financialCategoriesProvider = StateNotifierProvider<FinancialCategoryNotifier, List<FinancialCategory>>((ref) {
  return FinancialCategoryNotifier(ref.watch(dbProvider));
});

class FinancialCategoryNotifier extends StateNotifier<List<FinancialCategory>> {
  final DatabaseHelper db;
  FinancialCategoryNotifier(this.db) : super([]) {
    loadCategories();
  }

  Future<void> loadCategories() async {
    state = await db.getFinancialCategories();
  }

  Future<void> addCategory(FinancialCategory category) async {
    final newCategory = await db.createFinancialCategory(category);
    state = [...state, newCategory];
  }

  Future<void> updateCategory(FinancialCategory category) async {
    await db.updateFinancialCategory(category);
    state = [
      for (final t in state)
        if (t.id == category.id) category else t
    ];
  }

  Future<void> removeCategory(int id) async {
    await db.deleteFinancialCategory(id);
    state = state.where((t) => t.id != id).toList();
  }
}

final debtsProvider = StateNotifierProvider<DebtNotifier, List<Debt>>((ref) {
  return DebtNotifier(ref.watch(dbProvider), ref);
});

class DebtNotifier extends StateNotifier<List<Debt>> {
  final DatabaseHelper db;
  final Ref ref;
  DebtNotifier(this.db, this.ref) : super([]) {
    loadDebts();
  }

  Future<void> loadDebts() async {
    final m = await db.getDebts();
    state = m.map((e) => Debt.fromMap(e)).toList();
  }

  Future<void> addDebt(Debt debt) async {
    final id = await db.createDebt(debt.toMap());
    state = [debt.copyWith(id: id), ...state];
  }

  Future<void> updateDebt(Debt debt) async {
    await db.updateDebt(debt.toMap());
    state = [
      for (final d in state)
        if (d.id == debt.id) debt else d
    ];
  }

  Future<void> removeDebt(int id) async {
    final installments = ref.read(transactionsProvider).where((t) => t.debtId == id).toList();
    for (final i in installments) {
      if (i.id != null) {
        NotificationService().cancelNotification(NotificationService().transactionReminderId(i.id!));
      }
    }
    await db.deleteDebt(id);
    state = state.where((d) => d.id != id).toList();
  }

  Future<void> clearCanceledDebts() async {
    final canceledIds = state.where((d) => d.status == 'canceled' && d.id != null).map((d) => d.id!).toList();
    for (final id in canceledIds) {
      await removeDebt(id);
    }
  }
}

final projectsProvider = StateNotifierProvider<ProjectNotifier, List<Project>>((ref) {
  return ProjectNotifier(ref.watch(dbProvider), ref);
});

class ProjectNotifier extends StateNotifier<List<Project>> {
  final DatabaseHelper db;
  final Ref ref;
  ProjectNotifier(this.db, this.ref) : super([]) {
    loadProjects();
  }

  Future<void> loadProjects() async {
    final m = await db.getProjects();
    state = m.map((e) => Project.fromMap(e)).toList();
  }

  Future<void> addProject(Project project) async {
    final id = await db.createProject(project.toMap());
    state = [project.copyWith(id: id), ...state];
    _syncProjectReminder(state.first);
  }

  Future<void> updateProject(Project project) async {
    await db.updateProject(project.toMap());
    _syncProjectReminder(project);
    state = [
      for (final p in state)
        if (p.id == project.id) project else p
    ];
  }

  Future<void> removeProject(int id, {bool deleteLinkedTasks = false}) async {
    NotificationService().cancelNotification(NotificationService().projectReminderId(id));
    await db.deleteProject(id, deleteLinkedTasks: deleteLinkedTasks);
    state = state.where((p) => p.id != id).toList();
  }

  Future<void> recalculateProgress(int projectId) async {
    final idx = state.indexWhere((p) => p.id == projectId);
    if (idx == -1) return;
    final project = state[idx];

    if (project.status == 'paused') return;
    if (project.status == 'completed') {
      final completedProject = project.copyWith(progress: 100, updatedAt: DateTime.now().toIso8601String());
      await updateProject(completedProject);
      return;
    }

    final tasks = ref.read(tasksProvider).where((t) => t.projectId == projectId && t.status != 'canceled').toList();
    double progress = 0;

    if (tasks.isNotEmpty) {
      final done = tasks.where((t) => t.status == 'concluida').length;
      progress = (done / tasks.length) * 100;
    } else {
      final steps = ref.read(projectStepsProvider(projectId)).where((s) => s.status != 'canceled').toList();
      if (steps.isNotEmpty) {
        final done = steps.where((s) => s.status == 'completed').length;
        progress = (done / steps.length) * 100;
      }
    }

    final updated = project.copyWith(progress: progress, updatedAt: DateTime.now().toIso8601String());
    await updateProject(updated);
  }

  void _syncProjectReminder(Project p) {
    if (p.id == null) return;
    final reminderId = NotificationService().projectReminderId(p.id!);
    if (!p.reminderEnabled || p.status == 'completed' || p.status == 'canceled') {
      NotificationService().cancelNotification(reminderId);
      return;
    }
    final end = p.endDate == null ? null : DateTime.tryParse(p.endDate!);
    if (end == null) return;
    final reminderTime = DateTime(end.year, end.month, end.day, 9, 0);
    if (reminderTime.isBefore(DateTime.now())) return;
    NotificationService().scheduleNotification(
      id: reminderId,
      title: 'Prazo de projeto próximo',
      body: p.name,
      scheduledDate: reminderTime,
    );
  }
}

final projectStepsProvider = StateNotifierProvider.family<ProjectStepNotifier, List<ProjectStep>, int>((ref, projectId) {
  return ProjectStepNotifier(ref.watch(dbProvider), projectId, ref);
});

final allProjectStepsProvider = FutureProvider<List<ProjectStep>>((ref) async {
  return ref.watch(dbProvider).getAllProjectSteps();
});

class ProjectStepNotifier extends StateNotifier<List<ProjectStep>> {
  final DatabaseHelper db;
  final Ref ref;
  final int projectId;
  ProjectStepNotifier(this.db, this.projectId, this.ref) : super([]) {
    loadSteps();
  }

  Future<void> loadSteps() async {
    state = await db.getProjectSteps(projectId);
  }

  Future<void> addStep(String title, {String? description, String? dueDate, bool reminderEnabled = false}) async {
    final now = DateTime.now().toIso8601String();
    final step = ProjectStep(
      projectId: projectId,
      title: title,
      description: description,
      orderIndex: state.length,
      status: 'pending',
      dueDate: dueDate,
      completedAt: null,
      reminderEnabled: reminderEnabled,
      createdAt: now,
      updatedAt: now,
    );
    final newStep = await db.createProjectStep(step);
    state = [...state, newStep];
    _syncStepReminder(newStep);
    await ref.read(projectsProvider.notifier).recalculateProgress(projectId);
  }

  Future<void> updateStep(ProjectStep step) async {
    await db.updateProjectStep(step);
    _syncStepReminder(step);
    state = [
      for (final s in state)
        if (s.id == step.id) step else s
    ];
    await ref.read(projectsProvider.notifier).recalculateProgress(projectId);
  }

  Future<void> removeStep(int stepId) async {
    NotificationService().cancelNotification(NotificationService().projectStepReminderId(stepId));
    await db.deleteProjectStep(stepId);
    state = state.where((s) => s.id != stepId).toList();
    await ref.read(projectsProvider.notifier).recalculateProgress(projectId);
  }

  void _syncStepReminder(ProjectStep step) {
    if (step.id == null) return;
    final reminderId = NotificationService().projectStepReminderId(step.id!);
    if (!step.reminderEnabled || step.status == 'completed' || step.status == 'canceled') {
      NotificationService().cancelNotification(reminderId);
      return;
    }
    final due = step.dueDate == null ? null : DateTime.tryParse(step.dueDate!);
    if (due == null) return;
    final reminderTime = DateTime(due.year, due.month, due.day, 9, 0);
    if (reminderTime.isBefore(DateTime.now())) return;
    NotificationService().scheduleNotification(
      id: reminderId,
      title: 'Prazo de etapa próximo',
      body: step.title,
      scheduledDate: reminderTime,
    );
  }
}
