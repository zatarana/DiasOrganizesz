import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/task_model.dart';
import '../data/models/category_model.dart';
import '../data/database/db_helper.dart';

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

  Future<void> loadTasks() async {
    state = await db.getTasks();
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
    state = [
      for (final t in state)
        if (t.id == task.id) task else t
    ];
  }

  Future<void> removeTask(int id) async {
    await db.deleteTask(id);
    state = state.where((t) => t.id != id).toList();
  }

  Future<void> clearCompletedTasks() async {
    final completed = state.where((t) => t.status == 'concluida').toList();
    for (var t in completed) {
      if (t.id != null) await db.deleteTask(t.id!);
    }
    state = state.where((t) => t.status != 'concluida').toList();
  }
}

