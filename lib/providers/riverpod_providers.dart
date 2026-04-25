import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task_model.dart';
import '../models/category_model.dart';
import '../services/db_helper.dart';

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

  Future<void> addTask(Task task) async {
    final newTask = await db.createTask(task);
    state = [...state, newTask];
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
}
