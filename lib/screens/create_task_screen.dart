import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/riverpod_providers.dart';
import '../models/task_model.dart';
import 'package:intl/intl.dart';

class CreateTaskScreen extends ConsumerStatefulWidget {
  final Task? task;
  const CreateTaskScreen({super.key, this.task});

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _date = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String _priority = 'media';
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    if (widget.task != null) {
      _titleController.text = widget.task!.title;
      _descController.text = widget.task!.description;
      _date = widget.task!.date;
      _priority = widget.task!.priority;
      _categoryId = widget.task!.categoryId;
    }
  }

  void _save() {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Título é obrigatório.')));
      return;
    }
    
    final categories = ref.read(categoriesProvider);
    final catId = _categoryId ?? (categories.isNotEmpty ? categories.first.id : 1);

    final t = Task(
      id: widget.task?.id,
      title: _titleController.text,
      description: _descController.text,
      date: _date,
      categoryId: catId!,
      priority: _priority,
      status: widget.task?.status ?? 'pendente',
      hasReminder: false,
      createdAt: widget.task?.createdAt ?? DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    if (widget.task == null) {
      ref.read(tasksProvider.notifier).addTask(t);
    } else {
      ref.read(tasksProvider.notifier).updateTask(t);
    }
    Navigator.pop(context);
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
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey.shade400)),
              title: Text('Data: $_date'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.parse(_date),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (d != null) {
                  setState(() {
                    _date = DateFormat('yyyy-MM-dd').format(d);
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _priority,
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
