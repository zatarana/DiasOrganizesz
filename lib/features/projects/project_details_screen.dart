import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/project_model.dart';
import '../../data/models/project_step_model.dart';
import '../../data/models/task_model.dart';
import '../../domain/providers.dart';
import '../tasks/create_task_screen.dart';
import 'create_project_screen.dart';

class ProjectDetailsScreen extends ConsumerStatefulWidget {
  final Project project;

  const ProjectDetailsScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectDetailsScreen> createState() => _ProjectDetailsScreenState();
}

class _ProjectDetailsScreenState extends ConsumerState<ProjectDetailsScreen> {
  final Set<int> _expandedSessionIds = <int>{};

  bool _isTaskOverdue(Task task) {
    final date = DateTime.tryParse(task.date ?? '');
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
    final projectIndex = projects.indexWhere((p) => p.id == widget.project.id);

    if (projectIndex == -1) {
      return Scaffold(
        appBar: AppBar(title: const Text('Projeto não encontrado')),
        body: const Center(child: Text('Este projeto foi excluído.')),
      );
    }

    final project = projects[projectIndex];
    final projectId = project.id;
    final allTasks = ref.watch(tasksProvider);
    final projectTasks = allTasks.where((task) => task.projectId == projectId && task.status != 'canceled').toList();
    final parentProjectTasks = projectTasks.where((task) => task.parentTaskId == null).toList();
    final looseTasks = parentProjectTasks.where((task) => task.projectStepId == null).toList();
    final sessions = projectId == null
        ? <ProjectStep>[]
        : ref.watch(projectStepsProvider(projectId)).where((session) => session.status != 'canceled').toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    final doneTasks = parentProjectTasks.where((task) => task.status == 'concluida').length;
    final progress = (project.progress / 100).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Editar projeto',
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateProjectScreen(project: project))),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'complete') _updateStatus(project, 'completed');
              if (value == 'pause') _updateStatus(project, project.status == 'paused' ? 'active' : 'paused');
              if (value == 'delete') _confirmDelete(project);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'complete', child: Text('Concluir projeto')),
              PopupMenuItem(value: 'pause', child: Text(project.status == 'paused' ? 'Retomar projeto' : 'Pausar projeto')),
              const PopupMenuItem(value: 'delete', child: Text('Excluir projeto', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCard(project, doneTasks, parentProjectTasks.length, progress),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(child: Text('Sessões', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              TextButton.icon(
                onPressed: projectId == null || project.status == 'canceled' ? null : () => _showSessionDialog(projectId),
                icon: const Icon(Icons.add),
                label: const Text('Nova sessão'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (sessions.isEmpty)
            _emptyCard('Nenhuma sessão criada. Crie sessões como: Ideias, Fazer, Em andamento, Revisão, Concluído — ou os nomes que preferir.')
          else
            ...sessions.map((session) {
              final tasks = parentProjectTasks.where((task) => task.projectStepId == session.id).toList();
              return _sessionCard(project, session, tasks);
            }),
          const SizedBox(height: 12),
          _looseTasksCard(project, looseTasks),
        ],
      ),
    );
  }

  Widget _summaryCard(Project project, int doneTasks, int totalTasks, double progress) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(project.description?.isNotEmpty == true ? project.description! : 'Sem descrição.'),
            const SizedBox(height: 12),
            LinearProgressIndicator(value: progress, minHeight: 8),
            const SizedBox(height: 8),
            Text('Progresso: ${project.progress.toInt()}% • Tarefas: $doneTasks/$totalTasks'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip('Status: ${_projectStatus(project.status)}'),
                _chip('Prioridade: ${_priorityLabel(project.priority)}'),
                _chip('Prazo: ${_dateLabel(project.endDate)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionCard(Project project, ProjectStep session, List<Task> tasks) {
    final sessionId = session.id;
    final expanded = sessionId != null && _expandedSessionIds.contains(sessionId);
    final done = tasks.where((task) => task.status == 'concluida').length;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(
        children: [
          ListTile(
            leading: Icon(expanded ? Icons.keyboard_arrow_down : Icons.chevron_right),
            title: Text(session.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${tasks.length} tarefa(s) • $done concluída(s)', maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'task') _openNewTask(project, session.id);
                if (value == 'edit') _showSessionDialog(session.projectId, session: session);
                if (value == 'delete') _confirmDeleteSession(session);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'task', child: Text('Adicionar tarefa')),
                PopupMenuItem(value: 'edit', child: Text('Editar sessão')),
                PopupMenuItem(value: 'delete', child: Text('Excluir sessão', style: TextStyle(color: Colors.red))),
              ],
            ),
            onTap: sessionId == null
                ? null
                : () => setState(() {
                      expanded ? _expandedSessionIds.remove(sessionId) : _expandedSessionIds.add(sessionId);
                    }),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (session.description?.isNotEmpty == true)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(session.description!, style: TextStyle(color: Colors.grey.shade700)),
                    ),
                  if (tasks.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('Nenhuma tarefa nesta sessão.', style: TextStyle(color: Colors.grey)),
                    )
                  else
                    ...tasks.map((task) => _taskTile(project, task)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: project.status == 'canceled' ? null : () => _openNewTask(project, session.id),
                      icon: const Icon(Icons.add_task),
                      label: const Text('Adicionar tarefa'),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _looseTasksCard(Project project, List<Task> tasks) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Tarefas sem sessão', style: TextStyle(fontWeight: FontWeight.bold))),
                TextButton.icon(
                  onPressed: project.status == 'canceled' ? null : () => _openNewTask(project, null),
                  icon: const Icon(Icons.add),
                  label: const Text('Tarefa'),
                ),
              ],
            ),
            if (tasks.isEmpty)
              const Text('Nenhuma tarefa solta neste projeto.', style: TextStyle(color: Colors.grey))
            else
              ...tasks.map((task) => _taskTile(project, task)),
          ],
        ),
      ),
    );
  }

  Widget _taskTile(Project project, Task task) {
    final isDone = task.status == 'concluida';
    final subtasks = ref.watch(tasksProvider).where((sub) => sub.parentTaskId == task.id && sub.status != 'canceled').toList();
    final doneSubtasks = subtasks.where((sub) => sub.status == 'concluida').length;
    return CheckboxListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      value: isDone,
      title: Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(decoration: isDone ? TextDecoration.lineThrough : null)),
      subtitle: Text('${_compactDate(task)}${subtasks.isEmpty ? '' : ' • Subtarefas $doneSubtasks/${subtasks.length}'}', maxLines: 1, overflow: TextOverflow.ellipsis),
      secondary: IconButton(
        tooltip: 'Editar tarefa',
        icon: const Icon(Icons.edit_outlined),
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(task: task))),
      ),
      onChanged: project.status == 'canceled'
          ? null
          : (value) async {
              if (value == null) return;
              await ref.read(tasksProvider.notifier).updateTask(task.copyWith(status: value ? 'concluida' : _statusWhenTaskReopened(task), updatedAt: DateTime.now().toIso8601String()));
              if (value) _maybeSuggestCompleteProject(project.id, project.status);
            },
    );
  }

  Widget _emptyCard(String text) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(text, style: const TextStyle(color: Colors.grey))));
  Widget _chip(String text) => Chip(label: Text(text), visualDensity: VisualDensity.compact);

  void _openNewTask(Project project, int? sessionId) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(projectId: project.id, projectStepId: sessionId)));
  }

  Future<void> _showSessionDialog(int projectId, {ProjectStep? session}) async {
    final titleController = TextEditingController(text: session?.title ?? '');
    final descriptionController = TextEditingController(text: session?.description ?? '');
    final result = await showDialog<Map<String, String>?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(session == null ? 'Nova sessão' : 'Editar sessão'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Nome da sessão')),
              TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Descrição opcional')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () { FocusScope.of(ctx).unfocus(); Navigator.pop(ctx); }, child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              final title = titleController.text.trim();
              if (title.isEmpty) return;
              FocusScope.of(ctx).unfocus();
              Navigator.pop(ctx, {'title': title, 'description': descriptionController.text.trim()});
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    titleController.dispose();
    descriptionController.dispose();
    if (result == null || !mounted) return;
    final description = result['description']?.trim();
    if (session == null) {
      await ref.read(projectStepsProvider(projectId).notifier).addStep(result['title']!, description: description?.isEmpty == true ? null : description);
    } else {
      await ref.read(projectStepsProvider(projectId).notifier).updateStep(session.copyWith(title: result['title'], description: description?.isEmpty == true ? null : description, clearDescription: description?.isEmpty == true, updatedAt: DateTime.now().toIso8601String()));
    }
  }

  void _confirmDeleteSession(ProjectStep session) {
    final linkedTasks = ref.read(tasksProvider).where((task) => task.projectStepId == session.id).toList();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir sessão'),
        content: Text(linkedTasks.isEmpty ? 'Deseja excluir esta sessão?' : 'Esta sessão possui ${linkedTasks.length} tarefa(s). Elas serão mantidas no projeto, mas ficarão sem sessão.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              if (session.id != null) await ref.read(projectStepsProvider(session.projectId).notifier).removeStep(session.id!);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _updateStatus(Project project, String status) async {
    await ref.read(projectsProvider.notifier).updateProject(project.copyWith(status: status, completedAt: status == 'completed' ? DateTime.now().toIso8601String() : null, clearCompletedAt: status != 'completed', progress: status == 'completed' ? 100 : project.progress, updatedAt: DateTime.now().toIso8601String()));
  }

  void _confirmDelete(Project project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir projeto'),
        content: const Text('Deseja manter as tarefas vinculadas ou excluir tudo junto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              if (project.id != null) await ref.read(projectsProvider.notifier).removeProject(project.id!, deleteLinkedTasks: false);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Manter tarefas'),
          ),
          TextButton(
            onPressed: () async {
              if (project.id != null) await ref.read(projectsProvider.notifier).removeProject(project.id!, deleteLinkedTasks: true);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (!mounted) return;
              Navigator.pop(context);
            },
            child: const Text('Excluir tudo', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _maybeSuggestCompleteProject(int? projectId, String currentProjectStatus) {
    if (projectId == null || currentProjectStatus == 'completed' || currentProjectStatus == 'canceled') return;
    final tasks = ref.read(tasksProvider).where((task) => task.projectId == projectId && task.status != 'canceled').toList();
    if (tasks.isEmpty || tasks.any((task) => task.status != 'concluida')) return;
    final projects = ref.read(projectsProvider);
    final index = projects.indexWhere((project) => project.id == projectId);
    if (index == -1) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Projeto concluído?'),
        content: const Text('Todas as tarefas foram concluídas. Deseja concluir o projeto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Agora não')),
          TextButton(
            onPressed: () {
              _updateStatus(projects[index], 'completed');
              Navigator.pop(ctx);
            },
            child: const Text('Concluir'),
          ),
        ],
      ),
    );
  }

  String _compactDate(Task task) {
    final date = DateTime.tryParse(task.date ?? '');
    final formatted = date == null ? 'Sem data' : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
    return task.time == null ? formatted : '$formatted ${task.time}';
  }

  String _dateLabel(String? isoDate) {
    final date = DateTime.tryParse(isoDate ?? '');
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _projectStatus(String status) {
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
}
