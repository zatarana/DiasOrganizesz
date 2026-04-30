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
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _tagController = TextEditingController();
  String _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String? _time;
  String _priority = 'media';
  String _recurrenceType = 'none';
  int? _categoryId;
  int? _projectId;
  int? _projectStepId;
  int? _parentTaskId;
  bool _hasReminder = false;
  bool _isSaving = false;
  final List<String> _tags = [];
  final List<int> _reminderOffsets = [];

  static const List<int> _availableReminderOffsets = [0, 5, 10, 30, 60, 1440];

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
      _tags.addAll(_parseTags(task.tags));
      _reminderOffsets.addAll(_parseReminderOffsets(task.reminderOffsets));
      if (_hasReminder && _reminderOffsets.isEmpty) _reminderOffsets.add(0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _tagController.dispose();
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
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final categories = ref.read(categoriesProvider);
    final categoryStillExists = _categoryId != null && categories.any((category) => category.id == _categoryId);
    final catId = categoryStillExists ? _categoryId : (categories.isNotEmpty ? categories.first.id : 1);
    final isSubtask = _parentTaskId != null;
    final reminderOffsets = _time == null || !_hasReminder ? <int>[] : _reminderOffsets.take(3).toList()..sort();
    final hasValidReminder = reminderOffsets.isNotEmpty;

    setState(() => _isSaving = true);
    try {
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
        tags: _tags.isEmpty ? null : _tags.join(', '),
        reminderOffsets: hasValidReminder ? reminderOffsets.join(',') : null,
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
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _syncReminder(Task task) async {
    if (task.id == null) return;
    final notificationService = NotificationService();
    await notificationService.cancelTaskReminderSet(task.id!);

    if (!task.reminderEnabled || task.time == null || task.date == null || task.status == 'concluida' || task.status == 'canceled') return;
    final offsets = _parseReminderOffsets(task.reminderOffsets);
    if (offsets.isEmpty) return;

    try {
      final parts = task.time!.split(':');
      final currentDate = DateTime.parse(task.date!);
      final taskDateTime = DateTime(currentDate.year, currentDate.month, currentDate.day, int.parse(parts[0]), int.parse(parts[1]));
      for (var index = 0; index < offsets.take(3).length; index++) {
        final offset = offsets[index];
        final reminderTime = taskDateTime.subtract(Duration(minutes: offset));
        if (!reminderTime.isAfter(DateTime.now())) continue;
        final label = _reminderOffsetLabel(offset).toLowerCase();
        await notificationService.scheduleNotification(
          id: notificationService.taskReminderOffsetId(task.id!, index),
          title: offset == 0 ? 'Lembrete: ${task.title}' : 'Lembrete: ${task.title} em $label',
          body: offset == 0 ? 'Sua tarefa está programada para agora!' : 'Sua tarefa está chegando: $label.',
          scheduledDate: reminderTime,
        );
      }
    } catch (error) {
      debugPrint('Erro ao sincronizar lembretes de tarefa: $error');
      await notificationService.cancelTaskReminderSet(task.id!);
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
    await NotificationService().cancelTaskReminderSet(task.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isSubtask = _parentTaskId != null;
    final canShowSubtasks = widget.task?.id != null && !isSubtask;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? (isSubtask ? 'Nova Subtarefa' : 'Nova Tarefa') : 'Editar Tarefa'),
        actions: [if (widget.task != null) IconButton(icon: const Icon(Icons.delete), onPressed: _isSaving ? null : _confirmDelete)],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
                textInputAction: TextInputAction.next,
                validator: (value) => value == null || value.trim().isEmpty ? 'Informe o título da tarefa.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Descrição', border: OutlineInputBorder()),
              ),
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
                      trailing: _time == null
                          ? const Icon(Icons.access_time)
                          : IconButton(
                              tooltip: 'Limpar horário',
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() {
                                _time = null;
                                _hasReminder = false;
                                _reminderOffsets.clear();
                              }),
                            ),
                      onTap: () async {
                        final selected = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                        if (selected != null) {
                          setState(() {
                            _time = '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}';
                            if (_hasReminder && _reminderOffsets.isEmpty) _reminderOffsets.add(0);
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _ReminderSelector(
                enabled: _time != null && _hasReminder,
                canEnable: _time != null,
                selectedOffsets: _reminderOffsets,
                availableOffsets: _availableReminderOffsets,
                onEnabledChanged: (value) => setState(() {
                  _hasReminder = value;
                  if (!value) {
                    _reminderOffsets.clear();
                  } else if (_reminderOffsets.isEmpty) {
                    _reminderOffsets.add(0);
                  }
                }),
                onOffsetToggled: _toggleReminderOffset,
              ),
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
              const SizedBox(height: 16),
              _TagsSelector(
                controller: _tagController,
                tags: _tags,
                onAdd: _addTag,
                onRemove: _removeTag,
              ),
              if (canShowSubtasks) ...[
                const SizedBox(height: 16),
                _subtasksCard(widget.task!),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: _isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Salvar Tarefa', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleReminderOffset(int offset) {
    setState(() {
      if (_reminderOffsets.contains(offset)) {
        _reminderOffsets.remove(offset);
      } else if (_reminderOffsets.length < 3) {
        _reminderOffsets.add(offset);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escolha no máximo 3 lembretes.')));
      }
      _reminderOffsets.sort();
      _hasReminder = _reminderOffsets.isNotEmpty;
    });
  }

  void _addTag(String value) {
    final clean = value.trim().replaceAll(',', '');
    if (clean.isEmpty) return;
    if (_tags.any((tag) => tag.toLowerCase() == clean.toLowerCase())) {
      _tagController.clear();
      return;
    }
    setState(() {
      _tags.add(clean);
      _tagController.clear();
    });
  }

  void _removeTag(String value) {
    setState(() => _tags.remove(value));
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

class _ReminderSelector extends StatelessWidget {
  final bool enabled;
  final bool canEnable;
  final List<int> selectedOffsets;
  final List<int> availableOffsets;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onOffsetToggled;

  const _ReminderSelector({
    required this.enabled,
    required this.canEnable,
    required this.selectedOffsets,
    required this.availableOffsets,
    required this.onEnabledChanged,
    required this.onOffsetToggled,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Lembretes'),
              subtitle: Text(canEnable ? 'Selecione até 3 lembretes antes do horário.' : 'Defina um horário para ativar lembretes.'),
              value: canEnable && enabled,
              onChanged: canEnable ? onEnabledChanged : null,
            ),
            if (enabled) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableOffsets.map((offset) {
                  final selected = selectedOffsets.contains(offset);
                  final disabled = !selected && selectedOffsets.length >= 3;
                  return FilterChip(
                    selected: selected,
                    label: Text(_reminderOffsetLabel(offset)),
                    onSelected: disabled ? null : (_) => onOffsetToggled(offset),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TagsSelector extends StatelessWidget {
  final TextEditingController controller;
  final List<String> tags;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  const _TagsSelector({required this.controller, required this.tags, required this.onAdd, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'Adicionar tag',
                hintText: 'Ex: estudo, casa, urgente',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(icon: const Icon(Icons.add), onPressed: () => onAdd(controller.text)),
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: onAdd,
            ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tags.map((tag) => InputChip(label: Text(tag), onDeleted: () => onRemove(tag), visualDensity: VisualDensity.compact)).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

List<String> _parseTags(String? raw) {
  if (raw == null || raw.trim().isEmpty) return [];
  return raw.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toSet().toList();
}

List<int> _parseReminderOffsets(String? raw) {
  if (raw == null || raw.trim().isEmpty) return [];
  final values = raw.split(',').map((item) => int.tryParse(item.trim())).whereType<int>().where((value) => value >= 0).toSet().toList();
  values.sort();
  return values.take(3).toList();
}

String _reminderOffsetLabel(int minutes) {
  if (minutes == 0) return 'Na hora';
  if (minutes < 60) return '$minutes min antes';
  if (minutes == 60) return '1 h antes';
  if (minutes == 1440) return '1 dia antes';
  if (minutes % 60 == 0) return '${minutes ~/ 60} h antes';
  return '$minutes min antes';
}
