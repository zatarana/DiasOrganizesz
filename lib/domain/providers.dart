import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/task_model.dart';
import '../data/models/category_model.dart';
import '../data/models/financial_category_model.dart';
import '../data/models/debt_model.dart';
import '../data/models/setting_model.dart';
import '../data/models/transaction_model.dart';
import '../data/models/project_model.dart';
import '../data/database/db_helper.dart';
import '../core/notifications/notification_service.dart';

final dbProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper.instance);

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
  return TaskNotifier(ref.watch(dbProvider));
});

class TaskNotifier extends StateNotifier<List<Task>> {
  final DatabaseHelper db;
  TaskNotifier(this.db) : super([]) {
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
  }

  Future<Task> addTaskWithReturn(Task task) async {
    final newTask = await db.createTask(task);
    state = [...state, newTask];
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
  }

  Future<void> removeTask(int id) async {
    await db.deleteTask(id);
    NotificationService().cancelNotification(id);
    state = state.where((t) => t.id != id).toList();
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
    _checkDebtStatus(transaction.debtId);
  }

  Future<void> updateTransaction(FinancialTransaction transaction) async {
    await db.updateTransaction(transaction);
    state = [
      for (final t in state)
        if (t.id == transaction.id) transaction else t
    ];
    _checkDebtStatus(transaction.debtId);
  }

  Future<void> removeTransaction(int id) async {
    final transaction = state.firstWhere((t) => t.id == id, orElse: () => state.first);
    await db.deleteTransaction(id);
    state = state.where((t) => t.id != id).toList();
    _checkDebtStatus(transaction.debtId);
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
  return DebtNotifier(ref.watch(dbProvider));
});

class DebtNotifier extends StateNotifier<List<Debt>> {
  final DatabaseHelper db;
  DebtNotifier(this.db) : super([]) {
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
    await db.deleteDebt(id);
    state = state.where((d) => d.id != id).toList();
  }
}

final projectsProvider = StateNotifierProvider<ProjectNotifier, List<Project>>((ref) {
  return ProjectNotifier(ref.watch(dbProvider));
});

class ProjectNotifier extends StateNotifier<List<Project>> {
  final DatabaseHelper db;
  ProjectNotifier(this.db) : super([]) {
    loadProjects();
  }

  Future<void> loadProjects() async {
    final m = await db.getProjects();
    state = m.map((e) => Project.fromMap(e)).toList();
  }

  Future<void> addProject(Project project) async {
    final id = await db.createProject(project.toMap());
    state = [project.copyWith(id: id), ...state];
  }

  Future<void> updateProject(Project project) async {
    await db.updateProject(project.toMap());
    state = [
      for (final p in state)
        if (p.id == project.id) project else p
    ];
  }

  Future<void> removeProject(int id) async {
    await db.deleteProject(id);
    state = state.where((p) => p.id != id).toList();
  }
}

