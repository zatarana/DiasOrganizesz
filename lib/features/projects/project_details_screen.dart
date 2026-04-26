import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../data/models/project_model.dart';
import '../../data/models/project_step_model.dart';
import 'create_project_screen.dart';
import '../tasks/create_task_screen.dart';

class ProjectDetailsScreen extends ConsumerStatefulWidget {
  final Project project;

  const ProjectDetailsScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends ConsumerState<ProjectDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    final pIndex = projects.indexWhere((p) => p.id == widget.project.id);

    if (pIndex == -1) {
      return Scaffold(
        appBar: AppBar(title: const Text('Projeto não encontrado')),
        body: const Center(child: Text('Este projeto foi excluído.')),
      );
    }

    final project = projects[pIndex];
    final allTasks = ref.watch(tasksProvider);
    final projectTasks = allTasks.where((t) => t.projectId == project.id && t.status != 'canceled').toList();
    final steps = project.id == null ? <ProjectStep>[] : ref.watch(projectStepsProvider(project.id!));

    final doneTasks = projectTasks.where((t) => t.status == 'concluida').length;
    final progress = (project.progress / 100).clamp(0.0, 1.0);
    final daysRemaining = _daysRemaining(project.endDate);

    return Scaffold(
      appBar: AppBar(title: const Text('Detalhes do Projeto')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _sectionTitle('Seção 1: Resumo do projeto'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(project.description?.isNotEmpty == true ? project.description! : 'Sem descrição.'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _infoChip('Status: ${_statusLabel(project.status)}'),
                        _infoChip('Prioridade: ${_priorityLabel(project.priority)}'),
                        _infoChip('Início: ${_dateLabel(project.startDate)}'),
                        _infoChip('Prazo: ${_dateLabel(project.endDate)}'),
                        _infoChip(daysRemaining == null ? 'Dias restantes: —' : 'Dias restantes: $daysRemaining'),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            _sectionTitle('Seção 2: Progresso'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Progresso geral: ${project.progress.toInt()}%'),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress, minHeight: 8),
                    const SizedBox(height: 8),
                    Text('Tarefas concluídas: $doneTasks/${projectTasks.length}'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            _sectionTitle('Seção 3: Etapas'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      onPressed: project.id == null ? null : () => _showAddStepDialog(project.id!),
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Adicionar etapa'),
                    ),
                    const SizedBox(height: 8),
                    if (steps.isEmpty)
                      const Text('Nenhuma etapa criada.')
                    else
                      ...steps.map((step) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.flag_outlined),
                            title: Text(step.title),
                            subtitle: Text('Status: ${step.status}'),
                          )),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            _sectionTitle('Seção 4: Tarefas'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(projectId: project.id)));
                      },
                      icon: const Icon(Icons.add_task),
                      label: const Text('Adicionar tarefa'),
                    ),
                    const SizedBox(height: 8),
                    if (projectTasks.isEmpty)
                      const Text('Nenhuma tarefa vinculada.')
                    else
                      ...projectTasks.map((t) {
                        final isCompleted = t.status == 'concluida';
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          value: isCompleted,
                          title: Text(
                            t.title,
                            style: TextStyle(decoration: isCompleted ? TextDecoration.lineThrough : null),
                          ),
                          subtitle: Text(t.date ?? 'Sem data'),
                          onChanged: (val) {
                            if (val == null) return;
                            final updated = t.copyWith(status: val ? 'concluida' : 'pendente');
                            ref.read(tasksProvider.notifier).updateTask(updated);
                            if (val) _maybeSuggestCompleteProject(project.id, project.status);
                          },
                        );
                      }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            _sectionTitle('Seção 5: Ações'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateProjectScreen(project: project))),
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar projeto'),
                    ),
                    OutlinedButton.icon(
                      onPressed: project.status == 'completed' ? null : () => _updateStatus(project, 'completed'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Concluir projeto'),
                    ),
                    OutlinedButton.icon(
                      onPressed: project.status == 'paused' ? null : () => _updateStatus(project, 'paused'),
                      icon: const Icon(Icons.pause_circle_outline),
                      label: const Text('Pausar projeto'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _confirmDelete,
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text('Excluir projeto', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoChip(String text) {
    return Chip(label: Text(text));
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'active':
        return 'Em andamento';
      case 'paused':
        return 'Pausado';
      case 'completed':
        return 'Concluído';
      default:
        return status;
    }
  }

  String _priorityLabel(String priority) {
    switch (priority) {
      case 'alta':
        return 'Alta';
      case 'baixa':
        return 'Baixa';
      default:
        return 'Média';
    }
  }

  String _dateLabel(String? isoDate) {
    if (isoDate == null) return '—';
    final dt = DateTime.tryParse(isoDate);
    if (dt == null) return '—';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  int? _daysRemaining(String? endDate) {
    if (endDate == null) return null;
    final end = DateTime.tryParse(endDate);
    if (end == null) return null;
    return end.difference(DateTime.now()).inDays;
  }

  Future<void> _updateStatus(Project project, String status) async {
    final completedAt = status == 'completed' ? (project.completedAt ?? DateTime.now().toIso8601String()) : null;
    await ref.read(projectsProvider.notifier).updateProject(
          project.copyWith(
            status: status,
            completedAt: completedAt,
            clearCompletedAt: status != 'completed',
            progress: status == 'completed' ? 100 : project.progress,
            updatedAt: DateTime.now().toIso8601String(),
          ),
        );
    if (project.id != null && status != 'paused' && status != 'completed') {
      await ref.read(projectsProvider.notifier).recalculateProgress(project.id!);
    }
  }

  void _showAddStepDialog(int projectId) {
    final controller = TextEditingController();
    DateTime? dueDate;
    bool remind = false;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) => AlertDialog(
        title: const Text('Adicionar etapa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Título da etapa'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final dt = await showDatePicker(
                  context: context,
                  initialDate: dueDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (dt != null) setLocalState(() => dueDate = dt);
              },
              icon: const Icon(Icons.event),
              label: Text(dueDate == null ? 'Definir prazo (opcional)' : 'Prazo: ${_dateLabel(dueDate!.toIso8601String())}'),
            ),
            SwitchListTile(
              title: const Text('Lembrete de prazo'),
              value: remind,
              onChanged: dueDate != null ? (v) => setLocalState(() => remind = v) : null,
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final title = controller.text.trim();
              if (title.isEmpty) return;
              await ref.read(projectStepsProvider(projectId).notifier).addStep(
                title,
                dueDate: dueDate?.toIso8601String(),
                reminderEnabled: remind,
              );
              Navigator.pop(ctx);
            },
            child: const Text('Adicionar'),
          ),
        ],
      )),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Projeto'),
        content: const Text('O que deseja fazer com as tarefas vinculadas a este projeto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (widget.project.id != null) {
                ref.read(projectsProvider.notifier).removeProject(widget.project.id!, deleteLinkedTasks: false);
              }
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Manter tarefas (desvincular)'),
          ),
          TextButton(
            onPressed: () {
              if (widget.project.id != null) {
                ref.read(projectsProvider.notifier).removeProject(widget.project.id!, deleteLinkedTasks: true);
              }
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Excluir tarefas vinculadas', style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  void _maybeSuggestCompleteProject(int? projectId, String currentProjectStatus) {
    if (projectId == null || currentProjectStatus == 'completed') return;
    final allTasks = ref.read(tasksProvider);
    final projectTasks = allTasks.where((t) => t.projectId == projectId).toList();
    final allCompleted = projectTasks.isNotEmpty && projectTasks.every((t) => t.status == 'concluida');
    if (!allCompleted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Projeto pronto para conclusão'),
        content: const Text('Todas as tarefas deste projeto foram concluídas. Deseja marcar o projeto como concluído?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Agora não')),
          TextButton(
            onPressed: () {
              final projects = ref.read(projectsProvider);
              final idx = projects.indexWhere((p) => p.id == projectId);
              if (idx != -1) {
                _updateStatus(projects[idx], 'completed');
              }
              Navigator.pop(ctx);
            },
            child: const Text('Marcar como concluído'),
          ),
        ],
      ),
    );
  }
}
