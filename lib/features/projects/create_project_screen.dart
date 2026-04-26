import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/providers.dart';
import '../../data/models/project_model.dart';

class CreateProjectScreen extends ConsumerStatefulWidget {
  final Project? project;

  const CreateProjectScreen({super.key, this.project});

  @override
  ConsumerState<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _notesController = TextEditingController();

  static const _statusOptions = ['active', 'paused', 'completed', 'canceled'];
  static const _priorityOptions = ['baixa', 'media', 'alta'];
  static const _colorOptions = ['0xFF2196F3', '0xFF4CAF50', '0xFFFF9800', '0xFFE91E63', '0xFF9C27B0'];
  static const _iconOptions = ['rocket_launch', 'work', 'school', 'build', 'lightbulb'];

  DateTime? _startDate;
  DateTime? _endDate;
  String _status = 'active';
  String _priority = 'media';
  String _color = '0xFF2196F3';
  String _icon = 'rocket_launch';
  bool _reminderEnabled = false;

  String _safeOption(String value, List<String> options, String fallback) {
    return options.contains(value) ? value : fallback;
  }

  @override
  void initState() {
    super.initState();
    if (widget.project != null) {
      _nameController.text = widget.project!.name;
      _descriptionController.text = widget.project!.description ?? '';
      _notesController.text = widget.project!.notes ?? '';
      _status = _safeOption(widget.project!.status, _statusOptions, 'active');
      _priority = _safeOption(widget.project!.priority, _priorityOptions, 'media');
      _color = _safeOption(widget.project!.color, _colorOptions, '0xFF2196F3');
      _icon = _safeOption(widget.project!.icon, _iconOptions, 'rocket_launch');
      _reminderEnabled = widget.project!.reminderEnabled;
      if (widget.project!.startDate != null) _startDate = DateTime.tryParse(widget.project!.startDate!);
      if (widget.project!.endDate != null) _endDate = DateTime.tryParse(widget.project!.endDate!);
    } else {
      _startDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final dt = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (dt != null) setState(() => _startDate = dt);
  }

  Future<void> _pickEndDate() async {
    final dt = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (dt != null) setState(() => _endDate = dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.project == null ? 'Novo Projeto' : 'Editar Projeto')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Título *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descrição (Opcional)', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Observações (Opcional)', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickStartDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_startDate == null ? 'Data Inicial' : DateFormat('dd/MM/yyyy').format(_startDate!)),
                  ),
                ),
                IconButton(
                  tooltip: 'Limpar data inicial',
                  onPressed: _startDate == null ? null : () => setState(() => _startDate = null),
                  icon: const Icon(Icons.clear),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickEndDate,
                    icon: const Icon(Icons.event),
                    label: Text(_endDate == null ? 'Prazo Final' : DateFormat('dd/MM/yyyy').format(_endDate!)),
                  ),
                ),
                IconButton(
                  tooltip: 'Limpar prazo final',
                  onPressed: _endDate == null
                      ? null
                      : () => setState(() {
                            _endDate = null;
                            _reminderEnabled = false;
                          }),
                  icon: const Icon(Icons.clear),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Status *', border: OutlineInputBorder()),
              initialValue: _status,
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Ativo')),
                DropdownMenuItem(value: 'paused', child: Text('Pausado')),
                DropdownMenuItem(value: 'completed', child: Text('Concluído')),
                DropdownMenuItem(value: 'canceled', child: Text('Cancelado')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _status = val);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Prioridade *', border: OutlineInputBorder()),
              initialValue: _priority,
              items: const [
                DropdownMenuItem(value: 'baixa', child: Text('Baixa')),
                DropdownMenuItem(value: 'media', child: Text('Média')),
                DropdownMenuItem(value: 'alta', child: Text('Alta')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _priority = val);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Cor', border: OutlineInputBorder()),
              initialValue: _color,
              items: const [
                DropdownMenuItem(value: '0xFF2196F3', child: Text('Azul')),
                DropdownMenuItem(value: '0xFF4CAF50', child: Text('Verde')),
                DropdownMenuItem(value: '0xFFFF9800', child: Text('Laranja')),
                DropdownMenuItem(value: '0xFFE91E63', child: Text('Rosa')),
                DropdownMenuItem(value: '0xFF9C27B0', child: Text('Roxo')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _color = val);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Ícone', border: OutlineInputBorder()),
              initialValue: _icon,
              items: const [
                DropdownMenuItem(value: 'rocket_launch', child: Text('Foguete')),
                DropdownMenuItem(value: 'work', child: Text('Trabalho')),
                DropdownMenuItem(value: 'school', child: Text('Estudo')),
                DropdownMenuItem(value: 'build', child: Text('Construção')),
                DropdownMenuItem(value: 'lightbulb', child: Text('Ideia')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _icon = val);
              },
            ),
            SwitchListTile(
              title: const Text('Ativar lembrete de prazo'),
              subtitle: const Text('Lembrete local para o prazo final do projeto'),
              value: _endDate != null && _reminderEnabled,
              onChanged: _endDate != null ? (v) => setState(() => _reminderEnabled = v) : null,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              onPressed: _saveProject,
              child: const Text('Salvar Projeto', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProject() async {
    final title = _nameController.text.trim();
    final description = _descriptionController.text.trim();
    final notes = _notesController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Título é obrigatório.')));
      return;
    }

    if (_startDate != null && _endDate != null && _endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Prazo final não pode ser anterior à data de início.')));
      return;
    }

    final wasCompleted = widget.project?.status == 'completed';
    final completedAt = _status == 'completed' ? (widget.project?.completedAt ?? DateTime.now().toIso8601String()) : null;
    final shouldRecalculateProgress = widget.project != null && wasCompleted && _status != 'completed';
    final project = Project(
      id: widget.project?.id,
      name: title,
      description: description.isNotEmpty ? description : null,
      startDate: _startDate?.toIso8601String(),
      endDate: _endDate?.toIso8601String(),
      status: _status,
      notes: notes.isNotEmpty ? notes : null,
      completedAt: completedAt,
      progress: _status == 'completed' ? 100 : (shouldRecalculateProgress ? 0 : (widget.project?.progress ?? 0)),
      reminderEnabled: _endDate != null && _reminderEnabled,
      priority: _priority,
      color: _color,
      icon: _icon,
      createdAt: widget.project?.createdAt ?? DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );

    if (widget.project == null) {
      await ref.read(projectsProvider.notifier).addProject(project);
    } else {
      await ref.read(projectsProvider.notifier).updateProject(project);
      if (shouldRecalculateProgress && project.id != null) {
        await ref.read(projectsProvider.notifier).recalculateProgress(project.id!);
      }
    }

    if (mounted) Navigator.pop(context);
  }
}
