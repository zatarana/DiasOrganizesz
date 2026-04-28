import '../../data/models/task_model.dart';

class TaskSmartRules {
  const TaskSmartRules._();

  static bool isCanceled(Task task) => task.status == 'canceled';

  static bool isCompleted(Task task) => task.status == 'concluida';

  static bool isActive(Task task) => !isCanceled(task) && !isCompleted(task);

  static bool isParentTask(Task task) => task.parentTaskId == null;

  static bool isSubtask(Task task) => task.parentTaskId != null;

  static bool hasDate(Task task) => task.date != null && task.date!.trim().isNotEmpty && DateTime.tryParse(task.date!) != null;

  static bool hasTime(Task task) => task.time != null && task.time!.trim().isNotEmpty;

  static DateTime? dateOnly(Task task) {
    final parsed = DateTime.tryParse(task.date ?? '');
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static DateTime? scheduledDateTime(Task task) {
    final date = dateOnly(task);
    if (date == null) return null;
    if (!hasTime(task)) return DateTime(date.year, date.month, date.day, 23, 59, 59);
    final parts = task.time!.split(':');
    if (parts.length != 2) return DateTime(date.year, date.month, date.day, 23, 59, 59);
    final hour = int.tryParse(parts[0]) ?? 23;
    final minute = int.tryParse(parts[1]) ?? 59;
    return DateTime(date.year, date.month, date.day, hour.clamp(0, 23), minute.clamp(0, 59));
  }

  static bool isOverdue(Task task, {DateTime? now}) {
    if (!isActive(task)) return false;
    final scheduled = scheduledDateTime(task);
    if (scheduled == null) return false;
    return scheduled.isBefore(now ?? DateTime.now());
  }

  static bool isToday(Task task, {DateTime? now, bool includeOverdue = true}) {
    if (!isActive(task)) return false;
    final base = now ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    final taskDate = dateOnly(task);
    if (taskDate == null) return false;
    if (taskDate == today) return true;
    return includeOverdue && taskDate.isBefore(today);
  }

  static bool isExactlyToday(Task task, {DateTime? now}) {
    if (!isActive(task)) return false;
    final base = now ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    return dateOnly(task) == today;
  }

  static bool isNextSevenDays(Task task, {DateTime? now}) {
    if (!isActive(task)) return false;
    final base = now ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    final limit = today.add(const Duration(days: 7));
    final taskDate = dateOnly(task);
    if (taskDate == null) return false;
    return !taskDate.isBefore(today) && taskDate.isBefore(limit);
  }

  static bool isNoDate(Task task) => isActive(task) && !hasDate(task);

  static bool isInbox(Task task) {
    return isActive(task) && task.projectId == null && task.projectStepId == null && !hasDate(task);
  }

  static int priorityRank(Task task) {
    switch (task.priority) {
      case 'alta':
        return 0;
      case 'media':
        return 1;
      case 'baixa':
        return 2;
      default:
        return 3;
    }
  }

  static DateTime _distantFuture() => DateTime(2100, 12, 31, 23, 59, 59);

  static DateTime _safeCreatedAt(Task task) => DateTime.tryParse(task.createdAt) ?? DateTime.fromMillisecondsSinceEpoch(0);

  static int compareByTitle(Task a, Task b) {
    final byTitle = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    if (byTitle != 0) return byTitle;
    return compareByScheduleAndPriority(a, b);
  }

  static int compareByCreatedDesc(Task a, Task b) {
    final byCreated = _safeCreatedAt(b).compareTo(_safeCreatedAt(a));
    if (byCreated != 0) return byCreated;
    return compareByScheduleAndPriority(a, b);
  }

  static int compareByPriorityAndSchedule(Task a, Task b) {
    final byPriority = priorityRank(a).compareTo(priorityRank(b));
    if (byPriority != 0) return byPriority;
    return compareByScheduleAndPriority(a, b);
  }

  static int compareByScheduleAndPriority(Task a, Task b) {
    final ad = scheduledDateTime(a) ?? _distantFuture();
    final bd = scheduledDateTime(b) ?? _distantFuture();
    final byDate = ad.compareTo(bd);
    if (byDate != 0) return byDate;
    final byPriority = priorityRank(a).compareTo(priorityRank(b));
    if (byPriority != 0) return byPriority;
    return a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  static void sortTasks(List<Task> tasks, {String sortKey = 'schedule_priority'}) {
    switch (sortKey) {
      case 'priority_schedule':
        tasks.sort(compareByPriorityAndSchedule);
        break;
      case 'title':
        tasks.sort(compareByTitle);
        break;
      case 'created_desc':
        tasks.sort(compareByCreatedDesc);
        break;
      case 'schedule_priority':
      default:
        tasks.sort(compareByScheduleAndPriority);
        break;
    }
  }

  static List<Task> parentTasks(Iterable<Task> tasks, {bool includeCompleted = true, String sortKey = 'schedule_priority'}) {
    final filtered = tasks.where((task) {
      if (isCanceled(task)) return false;
      if (!includeCompleted && isCompleted(task)) return false;
      return isParentTask(task);
    }).toList();
    sortTasks(filtered, sortKey: sortKey);
    return filtered;
  }

  static Map<int, List<Task>> subtasksByParent(Iterable<Task> tasks, {String sortKey = 'schedule_priority'}) {
    final result = <int, List<Task>>{};
    for (final task in tasks) {
      final parentId = task.parentTaskId;
      if (parentId == null || isCanceled(task)) continue;
      result.putIfAbsent(parentId, () => <Task>[]).add(task);
    }
    for (final entry in result.entries) {
      sortTasks(entry.value, sortKey: sortKey);
    }
    return result;
  }

  static TaskDayProgress dayProgress(Iterable<Task> tasks, {DateTime? now}) {
    final todayTasks = tasks.where((task) => isExactlyToday(task, now: now) && isParentTask(task) && !isCanceled(task)).toList();
    final total = todayTasks.length;
    final completed = todayTasks.where(isCompleted).length;
    return TaskDayProgress(total: total, completed: completed);
  }

  static List<Task> todayTasks(Iterable<Task> tasks, {DateTime? now, String sortKey = 'schedule_priority'}) {
    final filtered = tasks.where((task) => isToday(task, now: now) && isParentTask(task)).toList();
    sortTasks(filtered, sortKey: sortKey);
    return filtered;
  }

  static List<Task> inboxTasks(Iterable<Task> tasks, {String sortKey = 'schedule_priority'}) {
    final filtered = tasks.where((task) => isInbox(task) && isParentTask(task)).toList();
    sortTasks(filtered, sortKey: sortKey);
    return filtered;
  }

  static List<Task> suggestedForToday(Iterable<Task> tasks, {DateTime? now}) {
    final base = now ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    final filtered = tasks.where((task) {
      if (!isActive(task) || !isParentTask(task)) return false;
      final date = dateOnly(task);
      return date == null || date.isBefore(today);
    }).toList();
    filtered.sort((a, b) {
      final byPriority = priorityRank(a).compareTo(priorityRank(b));
      if (byPriority != 0) return byPriority;
      return compareByScheduleAndPriority(a, b);
    });
    return filtered;
  }
}

class TaskDayProgress {
  final int total;
  final int completed;

  const TaskDayProgress({required this.total, required this.completed});

  int get pending => total - completed;

  double get ratio => total == 0 ? 0 : completed / total;

  int get percent => (ratio * 100).round();

  bool get allDone => total > 0 && completed == total;
}
