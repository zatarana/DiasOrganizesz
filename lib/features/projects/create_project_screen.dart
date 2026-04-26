import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/providers.dart';
import '../../data/models/project_model.dart';
import '../../data/database/db_helper.dart';

class CreateProjectScreen extends ConsumerStatefulWidget {
  final Project? project;

  const CreateProjectScreen({super.key, this.project});

  @override
  ConsumerState<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends ConsumerState<CreateProjectScreen> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime? _startDate;
  DateTime? _endDate;
  String _status = 'active';

  @override
  void initState() {
    super.initState();
    if (widget.project != null) {
      _nameController.text = widget.project!.name;
      _descriptionController.text = widget.project!.description ?? '';
      _status = widget.project!.status;
      if (widget.project!.startDate != null) {
        _startDate = DateTime.parse(widget.project!.startDate!);
      }
      if (widget.project!.endDate != null) {
        _endDate = DateTime.parse(widget.project!.endDate!);
      }
    } else {
      _startDate = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project == null ? 'Novo Projeto' : 'Editar Projeto'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nome do Projeto', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Descrição (Opcional)', border: OutlineInputBorder()),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                       final dt = await showDatePicker(
                         context: context, 
                         initialDate: _startDate ?? DateTime.now(), 
                         firstDate: DateTime(2000), 
                         lastDate: DateTime(2100)
                       );
                       if (dt != null) setState(()=> _startDate = dt);
                    },
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_startDate == null ? 'Data Inicial' : DateFormat('dd/MM/yyyy').format(_startDate!)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                       final dt = await showDatePicker(
                         context: context, 
                         initialDate: _endDate ?? (_startDate ?? DateTime.now()), 
                         firstDate: DateTime(2000), 
                         lastDate: DateTime(2100)
                       );
                       if (dt != null) setState(()=> _endDate = dt);
                    },
                    icon: const Icon(Icons.event),
                    label: Text(_endDate == null ? 'Prazo Final' : DateFormat('dd/MM/yyyy').format(_endDate!)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
               decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
               value: _status,
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

  void _saveProject() {
     final name = _nameController.text.trim();
     if (name.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, informe o nome do projeto.')));
       return;
     }

     final project = Project(
        id: widget.project?.id,
        name: name,
        description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        startDate: _startDate?.toIso8601String(),
        endDate: _endDate?.toIso8601String(),
        status: _status,
        createdAt: widget.project?.createdAt ?? DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
     );

     if (widget.project == null) {
       ref.read(projectsProvider.notifier).addProject(project);
     } else {
       ref.read(projectsProvider.notifier).updateProject(project);
     }

     Navigator.pop(context);
  }
}
