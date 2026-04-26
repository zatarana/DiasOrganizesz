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

  const CreateTaskScreen({super.key, this.task, this.selectedDate, this.projectId});

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String? _time;
  String _priority = 'media';
  int? _categoryId;
  int? _projectId;
  int? _projectStepId;
  bool _hasReminder = false;

  @override
  void initState() {
    super.initState();
    _projectId = widget.projectId;
    if (widget.selectedDate != null) {
      _date = DateFormat('yyyy-MM-dd').format(widget.selectedDate!);
    }
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descController.text = widget.task!.description ?? '';
      if (widget.task!.date != null) _date = widget.task!.date!;
      _time = widget.task!.time;
      _priority = widget.task!.priority;
      _categoryId = widget.task!.categoryId;
      _projectId = widget.task!.projectId ?? widget.projectId;
      _projectStepId = widget.task!.projectStepId;
      _hasReminder = widget.task!.reminderEnabled;
    }
  }

  Future<void> _save() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Título é obrigatório.')));
      return;
    }

    final categories = ref.read(categoriesProvider);
    final catId = _categoryId ?? (categories.isNotEmpty ? categories.first.id : 1);

    final task = Task(
      id: widget.task?.id,
      title: _titleController.text,
      description: _descController.text.isEmpty ? null : _descController.text,
      date: _date,
      time: _time,
      categoryId: catId!,
      projectId: _projectId,
      projectStepId: _projectId == null ? null : _projectStepId,
      priority: _priority,
      status: widget.task?.status ?? 'pendente',
      reminderEnabled: _hasReminder,
      createdAt: widget.task?.createdAt ?? DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    if (widget.task == null) {
      final insertedTask = await ref.read(tasksProvider.notifier).addTaskWithReturn(task);
      _scheduleReminderIfNeeded(insertedTask);
    } else {
      await ref.read(tasksProvider.notifier).updateTask(task);
      _scheduleReminderIfNeeded(task);
    }
    Navigator.pop(context);
  }

  void _scheduleReminderIfNeeded(Task task) {
    if (task.reminderEnabled && task.time != null && task.date != null) {
      try {
        final parts = task.time!.split(':');
        final currentDt = DateTime.parse(task.date!);
        final reminderTime = DateTime(currentDt.year, currentDt.month, currentDt.day, int.parse(parts[0]), int.parse(parts[1]));
        if (reminderTime.isAfter(DateTime.now())) {
          NotificationService().scheduleNotification(
            id: task.id ?? 0,
            title: 'Lembrete: ${task.title}',
            body: 'Sua tarefa está programada para agora!',
            scheduledDate: reminderTime,
          );
        }
      } catch (e) {
        debugPrint('Erro ao agendar notificacao: $e');
      }
    } else {
      NotificationService().cancelNotification(task.id ?? 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Nova Tarefa' : 'Editar Tarefa'),
        actions: [
          if (widget.task != null)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                ref.read(tasksProvider.notifier).removeTask(widget.task!.id!);
                NotificationService().cancelNotification(widget.task!.id!);
                Navigator.pop(context);
              },
            )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
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
                    title: Text(_date),
                    subtitle: const Text('Data'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final selected = await showDatePicker(
                        context: context,
                        initialDate: DateTime.parse(_date),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (selected != null) setState(() => _date = DateFormat('yyyy-MM-dd').format(selected));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade400)),
                    title: Text(_time ?? '--:--'),
                    subtitle: const Text('Horário (Opcional)'),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final selected = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                      if (selected != null) {
                        setState(() => _time = '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}');
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Ativar Lembrete Local'),
              subtitle: const Text('Requer data e horário definidos'),
              value: _hasReminder,
              onChanged: _time != null ? (val) => setState(() => _hasReminder = val) : null,
            ),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, child) {
                final categories = ref.watch(categoriesProvider);
                if (categories.isEmpty) return const SizedBox.shrink();
                return DropdownButtonFormField<int>(
                  initialValue: _categoryId ?? categories.first.id,
                  decoration: const InputDecoration(labelText: 'Categoria', border: OutlineInputBorder()),
                  items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _categoryId = val);
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            Consumer(
              builder: (context, ref, child) {
                final projects = ref.watch(projectsProvider);
                return DropdownButtonFormField<int>(
                  initialValue: _projectId,
                  decoration: const InputDecoration(labelText: 'Vincular ao Projeto (Opcional)', border: OutlineInputBorder()),
                  items: [
                    const DropdownMenuItem<int>(value: null, child: Text('Nenhum projeto')),
                    ...projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _projectId = val;
                      _projectStepId = null;
                    });
                  },
                );
              },
            ),
            if (_projectId != null) ...[
              const SizedBox(height: 16),
              Consumer(
                builder: (context, ref, child) {
                  final steps = ref.watch(projectStepsProvider(_projectId!));
                  return DropdownButtonFormField<int>(
                    initialValue: _projectStepId,
                    decoration: const InputDecoration(labelText: 'Etapa do Projeto (Opcional)', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem<int>(value: null, child: Text('Sem etapa específica')),
                      ...steps.map((s) => DropdownMenuItem<int>(value: s.id, child: Text(s.title))),
                    ],
                    onChanged: (val) => setState(() => _projectStepId = val),
                  );
                },
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(labelText: 'Prioridade', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'baixa', child: Text('Baixa')),
                DropdownMenuItem(value: 'media', child: Text('Média')),
                DropdownMenuItem(value: 'alta', child: Text('Alta')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _priority = val);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Salvar Tarefa', style: TextStyle(fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }
}
