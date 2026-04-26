import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../domain/providers.dart';
import '../../data/models/project_model.dart';
import 'create_project_screen.dart';
import 'project_details_screen.dart';

class ProjectsScreen extends ConsumerStatefulWidget {
  const ProjectsScreen({super.key});

  @override
  ConsumerState<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends ConsumerState<ProjectsScreen> {
  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    final tasks = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Projetos'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateProjectScreen()));
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo Projeto'),
      ),
      body: projects.isEmpty
          ? const Center(
              child: Text(
                'Nenhum projeto cadastrado.\nQue tal começar um novo objetivo?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];
                
                // Calculate progress
                final projectTasks = tasks.where((t) => t.projectId == project.id).toList();
                final completedTasks = projectTasks.where((t) => t.status == 'concluida').length;
                final progress = projectTasks.isEmpty ? 0.0 : completedTasks / projectTasks.length;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProjectDetailsScreen(project: project)));
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                               Expanded(
                                 child: Text(
                                   project.name,
                                   style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                 ),
                               ),
                               _buildStatusBadge(project.status),
                            ],
                          ),
                          if (project.description != null && project.description!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              project.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                               Text('${(progress * 100).toInt()}% Concluído', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                               Text('$completedTasks/${projectTasks.length} tarefas', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              color: progress >= 1.0 ? Colors.green : Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildStatusBadge(String status) {
     Color color;
     String label;

     switch (status) {
        case 'active':
          color = Colors.blue;
          label = 'Ativo';
          break;
        case 'completed':
          color = Colors.green;
          label = 'Concluído';
          break;
        case 'paused':
          color = Colors.orange;
          label = 'Pausado';
          break;
        case 'canceled':
          color = Colors.red;
          label = 'Cancelado';
          break;
        default:
          color = Colors.grey;
          label = status;
     }

     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
       decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color),
       ),
       child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
     );
  }
}
