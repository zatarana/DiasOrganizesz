import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../data/models/task_model.dart';
import '../../core/notifications/notification_service.dart';
import 'package:intl/intl.dart';

class CreateTaskScreen extends ConsumerStatefulWidget {
  final Task? task;
  final DateTime? selectedDate;
  final int? projectId;
  final int? projectStepId;
  final int? parentTaskId;

  const CreateTaskScreen({super.key, this.task, this.selectedDate, this.projectId, this.projectStepId, this.parentTaskId});

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String? _time;
  String _priority = 'media';
  String _recurrenceType = 'none';
  int? _categoryId;
  int? _projectId;
  int? _projectStepId;
  int? _parentTaskId;
  bool _hasReminder = false;

  @override
  void initState() {
    super.initState();
    _projectId = widget.projectId;
    _projectStepId = widget.projectStepId;
    _parentTaskId = widget.parentTaskId;
    if (widget.selectedDate != null) _date = DateFormat('yyyy-MM-dd').format(widget.selectedDate!);
    final task = widget.task;
    if (task != null) {
      _titleController.text = task.title;
      _descController.text = task.description ?? '';
      if (task.date != null) _date = task.date!;
      _time = task.time;
      _priority = task.priority;
      _recurrenceType = task.recurrenceType;
      _categoryId = task.categoryId;
      _projectId = task.projectId ?? widget.projectId;
      _projectStepId = task.projectStepId ?? widget.projectStepId;
      _parentTaskId = task.parentTaskId ?? widget.parentTaskId;
      _hasReminder = task.reminderEnabled && task.time != null;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool _isSelectedDateTimeOverdue() {
    final date = DateTime.tryParse(_date);
    if (date == null) return false;
    if (_time != null) {
      final parts = _time!.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 23;
        final minute = int.tryParse(parts[1]) ?? 59;
        return DateTime(date.year, date.month, date.day, hour, minute).isBefore(DateTime.now());
      }
    }
    return DateTime(date.year, date.month, date.day, 23, 59, 59).isBefore(DateTime.now());
  }

  String _normalizedStatusForSave() {
    final current = widget.task?.status ?? 'pendente';
    if (current == 'concluida' || current == 'canceled') return current;
    return _isSelectedDateTimeOverdue() ? 'atrasada' : 'pendente';
  }

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Título é obrigatório.')));
      return;
    }
    final categories = ref.read(categoriesProvider);
    final categoryStillExists = _categoryId != null && categories.any((category) => category.id == _categoryId);
    final catId = categoryStillExists ? _categoryId : (categories.isNotEmpty ? categories.first.id : 1);
    final hasValidReminder = _hasReminder && _time != null;
    final isSubtask = _parentTaskId != null;

    final task = Task(
      id: widget.task?.id,
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      date: _date,
      time: _time,
      categoryId: catId!,
      projectId: _projectId,
      projectStepId: _projectId == null ? null : _projectStepId,
      parentTaskId: _parentTaskId,
      priority: _priority,
      status: _normalizedStatusForSave(),
      reminderEnabled: hasValidReminder,
      recurrenceType: isSubtask ? 'none' : _recurrenceType,
      createdAt: widget.task?.createdAt ?? DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    if (widget.task == null) {
      final insertedTask = await ref.read(tasksProvider.notifier).addTaskWithReturn(task);
      await _syncReminder(insertedTask);
    } else {
      await ref.read(tasksProvider.notifier).updateTask(task);
      await _syncReminder(task);
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _syncReminder(Task task) async {
    if (task.id == null) return;
    final reminderId = NotificationService().taskReminderId(task.id!);
    if (!task.reminderEnabled || task.time == null || task.date == null || task.status == 'concluida' || task.status == 'canceled') {
      await NotificationService().cancelNotification(reminderId);
      return;
    }
    try {
      final parts = task.time!.split(':');
      final currentDate = DateTime.parse(task.date!);
      final reminderTime = DateTime(currentDate.year, currentDate.month, currentDate.day, int.parse(parts[0]), int.parse(parts[1]));
      if (!reminderTime.isAfter(DateTime.now())) {
        await NotificationService().cancelNotification(reminderId);
        return;
      }
      await NotificationService().scheduleNotification(id: reminderId, title: 'Lembrete: ${task.title}', body: 'Sua tarefa está programada para agora!', scheduledDate: reminderTime);
    } catch (error) {
      debugPrint('Erro ao sincronizar lembrete de tarefa: $error');
      await NotificationService().cancelNotification(reminderId);
    }
  }

  Future<void> _confirmDelete() async {
    final task = widget.task;
    if (task?.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir tarefa?'),
        content: Text('Deseja excluir "${task!.title}"? Subtarefas vinculadas ficarão sem tarefa principal.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Excluir', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(tasksProvider.notifier).removeTask(task!.id!);
    await NotificationService().cancelNotification(NotificationService().taskReminderId(task.id!));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isSubtask = _parentTaskId != null;
    final canShowSubtasks = widget.task?.id != null && !isSubtask;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? (isSubtask ? 'Nova Subtarefa' : 'Nova Tarefa') : 'Editar Tarefa'),
        actions: [if (widget.task != null) IconButton(icon: const Icon(Icons.delete), onPressed: _confirmDelete)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            TextField(controller: _descController, maxLines: 3, decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade400)),
                    title: Text(_date, overflow: TextOverflow.ellipsis),
                    subtitle: const Text('Data'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final selected = await showDatePicker(context: context, initialDate: DateTime.tryParse(_date) ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                      if (selected != null) setState(() => _date = DateFormat('yyyy-MM-dd').format(selected));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade400)),
                    title: Text(_time ?? '--:--'),
                    subtitle: const Text('Horário'),
                    trailing: _time == null ? const Icon(Icons.access_time) : IconButton(tooltip: 'Limpar horário', icon: const Icon(Icons.clear), onPressed: () => setState(() { _time = null; _hasReminder = false; })),
                    onTap: () async {
                      final selected = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (selected != null) setState(() => _time = '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(title: const Text('Ativar Lembrete Local'), subtitle: const Text('Requer data e horário definidos'), value: _time != null && _hasReminder, onChanged: _time != null ? (val) => setState(() => _hasReminder = val) : null),
            const SizedBox(height: 16),
            Consumer(builder: (context, ref, child) {
              final categories = ref.watch(categoriesProvider);
              if (categories.isEmpty) return const SizedBox.shrink();
              final safeCategoryId = categories.any((category) => category.id == _categoryId) ? _categoryId : categories.first.id;
              return DropdownButtonFormField<int>(initialValue: safeCategoryId, decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()), items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(), onChanged: (val) { if (val != null) setState(() => _categoryId = val); });
            }),
            if (!isSubtask) ...[
              const SizedBox(height: 16),
              _projectPicker(),
              if (_projectId != null) ...[const SizedBox(height: 16), _sessionPicker()],
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(initialValue: _priority, decoration: const InputDecoration(labelText: 'Prioridade', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'baixa', child: Text('Baixa')), DropdownMenuItem(value: 'media', child: Text('Média')), DropdownMenuItem(value: 'alta', child: Text('Alta'))], onChanged: (val) { if (val != null) setState(() => _priority = val); }),
            if (!isSubtask) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(initialValue: _recurrenceType, decoration: const InputDecoration(labelText: 'Recorrência', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'none', child: Text('Não repetir')), DropdownMenuItem(value: 'daily', child: Text('Diariamente')), DropdownMenuItem(value: 'weekly', child: Text('Semanalmente')), DropdownMenuItem(value: 'monthly', child: Text('Mensalmente'))], onChanged: (val) { if (val != null) setState(() => _recurrenceType = val); }),
            ],
            if (canShowSubtasks) ...[
              const SizedBox(height: 16),
              _subtasksCard(widget.task!),
            ],
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _save, style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Salvar Tarefa', style: TextStyle(fontSize: 16)))),
          ],
        ),
      ),
    );
  }

  Widget _projectPicker() {
    return Consumer(builder: (context, ref, child) {
      final allProjects = ref.watch(projectsProvider);
      final projectItems = allProjects.where((p) => p.status != 'completed' && p.status != 'canceled' || p.id == _projectId).toList();
      final safeProjectId = projectItems.any((project) => project.id == _projectId) ? _projectId : null;
      if (safeProjectId != _projectId) _projectStepId = null;
      return DropdownButtonFormField<int>(initialValue: safeProjectId, decoration: const InputDecoration(labelText: 'Vincular ao Projeto', border: OutlineInputBorder()), items: [const DropdownMenuItem<int>(value: null, child: Text('Nenhum projeto')), ...projectItems.map((p) { final inactive = p.status == 'completed' || p.status == 'canceled'; return DropdownMenuItem(value: p.id, child: Text(inactive ? '${p.name} (${p.status})' : p.name, overflow: TextOverflow.ellipsis)); })], onChanged: (val) => setState(() { _projectId = val; _projectStepId = null; }));
    });
  }

  Widget _sessionPicker() {
    return Consumer(builder: (context, ref, child) {
      final allSteps = ref.watch(projectStepsProvider(_projectId!));
      final stepItems = allSteps.where((s) => s.status != 'completed' && s.status != 'canceled' || s.id == _projectStepId).toList();
      final safeStepId = stepItems.any((step) => step.id == _projectStepId) ? _projectStepId : null;
      return DropdownButtonFormField<int>(initialValue: safeStepId, decoration: const InputDecoration(labelText: 'Sessão do Projeto', border: OutlineInputBorder()), items: [const DropdownMenuItem<int>(value: null, child: Text('Sem sessão específica')), ...stepItems.map((s) { final inactive = s.status == 'completed' || s.status == 'canceled'; return DropdownMenuItem<int>(value: s.id, child: Text(inactive ? '${s.title} (${s.status})' : s.title, overflow: TextOverflow.ellipsis)); })], onChanged: (val) => setState(() => _projectStepId = val));
    });
  }

  Widget _subtasksCard(Task parent) {
    final subtasks = ref.watch(tasksProvider).where((task) => task.parentTaskId == parent.id && task.status != 'canceled').toList();
    final done = subtasks.where((task) => task.status == 'concluida').length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Subtarefas ${subtasks.isEmpty ? '' : '($done/${subtasks.length})'}', style: const TextStyle(fontWeight: FontWeight.bold))),
            TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(parentTaskId: parent.id, projectId: parent.projectId, projectStepId: parent.projectStepId, selectedDate: DateTime.tryParse(parent.date ?? '')))), icon: const Icon(Icons.add), label: const Text('Adicionar')),
          ]),
          if (subtasks.isEmpty)
            const Text('Nenhuma subtarefa criada.', style: TextStyle(color: Colors.grey))
          else
            ...subtasks.map((subtask) {
              final isDone = subtask.status == 'concluida';
              return CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                value: isDone,
                title: Text(subtask.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(decoration: isDone ? TextDecoration.lineThrough : null)),
                secondary: IconButton(icon: const Icon(Icons.edit), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: subtask)))),
                onChanged: (value) => ref.read(tasksProvider.notifier).updateTask(subtask.copyWith(status: value == true ? 'concluida' : 'pendente', updatedAt: DateTime.now().toIso8601String())),
              );
            }),
        ]),
      ),
    );
  }
}
