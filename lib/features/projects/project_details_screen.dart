import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../../data/models/project_model.dart';
import 'create_project_screen.dart';
import '../tasks/create_task_screen.dart'; // We should probably pass project to CreateTaskScreen

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
    final projectTasks = allTasks.where((t) => t.projectId == project.id).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => CreateProjectScreen(project: project)));
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => _confirmDelete(),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Pass the preset projectId down to create task
          Navigator.push(context, MaterialPageRoute(builder: (_) => CreateTaskScreen(projectId: project.id)));
        },
        icon: const Icon(Icons.add_task),
        label: const Text('Nova Tarefa'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
           if (project.description != null && project.description!.isNotEmpty)
              Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: Text(project.description!, style: const TextStyle(fontSize: 16)),
              ),
           const Divider(),
           const Padding(
             padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             child: Text('Tarefas do Projeto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
           ),
           Expanded(
             child: projectTasks.isEmpty 
               ? const Center(child: Text('Nenhuma tarefa vinculada a este projeto.'))
               : ListView.builder(
                   itemCount: projectTasks.length,
                   itemBuilder: (context, index) {
                      final t = projectTasks[index];
                      bool isCompleted = t.status == 'concluida';
                      return CheckboxListTile(
                        title: Text(t.title, style: TextStyle(decoration: isCompleted ? TextDecoration.lineThrough : null)),
                        subtitle: t.date != null ? Text(t.date!) : null,
                        value: isCompleted,
                        onChanged: (val) {
                           if (val != null) {
                              final updated = t.copyWith(status: val ? 'concluida' : 'pendente');
                              ref.read(tasksProvider.notifier).updateTask(updated);
                           }
                        },
                      );
                   },
                 ),
           )
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir Projeto'),
        content: const Text('Deseja excluir este projeto? O projeto será removido das tarefas associadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
               if (widget.project.id != null) {
                  ref.read(projectsProvider.notifier).removeProject(widget.project.id!);
               }
               Navigator.pop(ctx);
               Navigator.pop(context);
            }, 
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          )
        ],
      )
    );
  }
}
