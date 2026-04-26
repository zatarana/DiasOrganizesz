import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../data/models/project_model.dart';
import '../../data/models/project_step_model.dart';
import '../../data/models/task_model.dart';
import 'create_project_screen.dart';
import '../tasks/create_task_screen.dart';

class ProjectDetailsScreen extends ConsumerStatefulWidget {
  final Project project;

  const ProjectDetailsScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends ConsumerState<ProjectDetailsScreen> {
  bool _isTaskOverdue(Task task) {
    if (task.date == null) return false;
    final date = DateTime.tryParse(task.date!);
    if (date == null) return false;

    if (task.time != null) {
      final parts = task.time!.split(':');
      if (parts.length == 2) {
        final hour = int.tryParse(parts[0]) ?? 23;
        final minute = int.tryParse(parts[1]) ?? 59;
        return DateTime(date.year, date.month, date.day, hour, minute).isBefore(DateTime.now());
      }
    }

    return DateTime(date.year, date.month, date.day, 23, 59, 59).isBefore(DateTime.now());
  }

  String _statusWhenTaskReopened(Task task) => _isTaskOverdue(task) ? 'atrasada' : 'pendente';

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
    final activeSteps = steps.where((s) => s.status != 'canceled').toList();

    final doneTasks = projectTasks.where((t) => t.status == 'concluida').length;
    final doneSteps = activeSteps.where((s) => s.status == 'completed').length;
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
                    Text('Etapas concluídas: $doneSteps/${activeSteps.length}'),
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
                      onPressed: project.id == null || project.status == 'canceled' ? null : () => _showAddStepDialog(project.id!),
                      icon: const Icon(Icons.playlist_add),
                      label: const Text('Adicionar etapa'),
                    ),
                    const SizedBox(height: 8),
                    if (activeSteps.isEmpty)
                      const Text('Nenhuma etapa criada.')
                    else
                      ...activeSteps.map((step) => _buildStepTile(step, project)),
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
                      onPressed: project.status == 'canceled'
                          ? null
                          : () {
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
                          onChanged: project.status == 'canceled'
                              ? null
                              : (val) async {
                                  if (val == null) return;
                                  final updated = t.copyWith(status: val ? 'concluida' : _statusWhenTaskReopened(t), updatedAt: DateTime.now().toIso8601String());
                                  await ref.read(tasksProvider.notifier).updateTask(updated);
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
                      onPressed: project.status == 'completed' || project.status == 'canceled' ? null : () => _updateStatus(project, 'completed'),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Concluir projeto'),
                    ),
                    OutlinedButton.icon(
                      onPressed: project.status == 'paused' || project.status == 'canceled' ? null : () => _updateStatus(project, 'paused'),
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

  Widget _buildStepTile(ProjectStep step, Project project) {
    final isCompleted = step.status == 'completed';
    final subtitleParts = <String>[
      'Status: ${_stepStatusLabel(step.status)}',
      if (step.dueDate != null) 'Prazo: ${_dateLabel(step.dueDate)}',
    ];

    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: isCompleted,
      title: Text(
        step.title,
        style: TextStyle(decoration: isCompleted ? TextDecoration.lineThrough : null),
      ),
      subtitle: Text(subtitleParts.join(' • ')),
      secondary: IconButton(
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        onPressed: step.id == null ? null : () => _confirmDeleteStep(step),
      ),
      onChanged: project.status == 'canceled'
          ? null
          : (val) async {
              if (val == null) return;
              final now = DateTime.now().toIso8601String();
              final updated = step.copyWith(
                status: val ? 'completed' : 'pending',
                completedAt: val ? now : null,
                clearCompletedAt: !val,
                updatedAt: now,
              );
              await ref.read(projectStepsProvider(step.projectId).notifier).updateStep(updated);
              if (val) _maybeSuggestCompleteProject(project.id, project.status);
            },
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
      case 'canceled':
        return 'Cancelado';
      default:
        return status;
    }
  }

  String _stepStatusLabel(String status) {
    switch (status) {
      case 'completed':
        return 'Concluída';
      case 'in_progress':
        return 'Em andamento';
      case 'canceled':
        return 'Cancelada';
      default:
        return 'Pendente';
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
                value: dueDate != null && remind,
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
                      reminderEnabled: dueDate != null && remind,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Adicionar'),
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }

  void _confirmDeleteStep(ProjectStep step) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir etapa'),
        content: Text('Deseja excluir a etapa "${step.title}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              await ref.read(projectStepsProvider(step.projectId).notifier).removeStep(step.id!);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
            onPressed: () async {
              if (widget.project.id != null) {
                await ref.read(projectsProvider.notifier).removeProject(widget.project.id!, deleteLinkedTasks: false);
              }
              if (mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            child: const Text('Manter tarefas (desvincular)'),
          ),
          TextButton(
            onPressed: () async {
              if (widget.project.id != null) {
                await ref.read(projectsProvider.notifier).removeProject(widget.project.id!, deleteLinkedTasks: true);
              }
              if (mounted) {
                Navigator.pop(ctx);
                Navigator.pop(context);
              }
            },
            child: const Text('Excluir tarefas vinculadas', style: TextStyle(color: Colors.red)),
          )
        ],
      ),
    );
  }

  void _maybeSuggestCompleteProject(int? projectId, String currentProjectStatus) {
    if (projectId == null || currentProjectStatus == 'completed' || currentProjectStatus == 'canceled') return;

    final allTasks = ref.read(tasksProvider).where((t) => t.projectId == projectId && t.status != 'canceled').toList();
    final allSteps = ref.read(projectStepsProvider(projectId)).where((s) => s.status != 'canceled').toList();
    final hasWork = allTasks.isNotEmpty || allSteps.isNotEmpty;
    final tasksDone = allTasks.isEmpty || allTasks.every((t) => t.status == 'concluida');
    final stepsDone = allSteps.isEmpty || allSteps.every((s) => s.status == 'completed');

    if (!hasWork || !tasksDone || !stepsDone) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Projeto pronto para conclusão'),
        content: const Text('Todas as tarefas e etapas deste projeto foram concluídas. Deseja marcar o projeto como concluído?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Agora não')),
          TextButton(
            onPressed: () {
              final projects = ref.read(projectsProvider);
              final idx = projects.indexWhere((p) => p.id == projectId);
              if (idx != -1) _updateStatus(projects[idx], 'completed');
              Navigator.pop(ctx);
            },
            child: const Text('Marcar como concluído'),
          ),
        ],
      ),
    );
  }
}
