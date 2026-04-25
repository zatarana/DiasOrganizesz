import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/task_model.dart';
import '../data/models/category_model.dart';
import '../data/database/db_helper.dart';
import '../core/notifications/notification_service.dart';

final dbProvider = Provider<DatabaseHelper>((ref) => DatabaseHelper.instance);

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

