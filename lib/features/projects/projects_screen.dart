import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  String _quickFilter = 'all';

  Color _safeProjectColor(Project project) {
    return Color(int.tryParse(project.color) ?? 0xFF2196F3);
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectsProvider);
    final tasks = ref.watch(tasksProvider);
    final appSettings = ref.watch(appSettingsProvider);
    final showCompleted = (appSettings[AppSettingKeys.projectsShowCompleted] ?? 'true') == 'true';
    final showPaused = (appSettings[AppSettingKeys.projectsShowPaused] ?? 'true') == 'true';
    final defaultSort = appSettings[AppSettingKeys.projectsDefaultSort] ?? 'created_desc';

    final validProjects = projects.where((p) => p.status != 'canceled').toList();
    final filteredProjects = validProjects.where((p) => _matchesQuickFilter(p, showCompleted: showCompleted, showPaused: showPaused)).toList();
    _applySort(filteredProjects, defaultSort);
    final inProgressCount = validProjects.where((p) => _matchesQuickFilter(p, forcedFilter: 'in_progress')).length;
    final completedCount = validProjects.where((p) => p.status == 'completed').length;
    final overdueCount = validProjects.where((p) => _matchesQuickFilter(p, forcedFilter: 'overdue')).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Projetos')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateProjectScreen()));
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo Projeto'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: [
              _buildSummaryCard('Total de Projetos', validProjects.length.toString(), Icons.folder_copy, Colors.blue),
              _buildSummaryCard('Em andamento', inProgressCount.toString(), Icons.play_circle_fill, Colors.orange),
              _buildSummaryCard('Concluídos', completedCount.toString(), Icons.check_circle, Colors.green),
              _buildSummaryCard('Atrasados', overdueCount.toString(), Icons.warning_amber, Colors.red),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Filtros rápidos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _buildQuickFilter('all', 'Todos'),
                _buildQuickFilter('planned', 'Planejados'),
                _buildQuickFilter('in_progress', 'Em andamento'),
                if (showPaused) _buildQuickFilter('paused', 'Pausados'),
                if (showCompleted) _buildQuickFilter('completed', 'Concluídos'),
                _buildQuickFilter('overdue', 'Atrasados'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Lista de Projetos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (filteredProjects.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'Nenhum projeto encontrado para os filtros atuais.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
            )
          else
            ...filteredProjects.map((project) {
              final projectTasks = tasks.where((t) => t.projectId == project.id && t.status != 'canceled').toList();
              final completedTasks = projectTasks.where((t) => t.status == 'concluida').length;
              final progress = (project.progress / 100).clamp(0.0, 1.0);
              final color = _safeProjectColor(project);
              final daysRemaining = _getDaysRemaining(project.endDate);
              final dueDateLabel = _formatDueDate(project.endDate);

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
                            CircleAvatar(
                              backgroundColor: color.withOpacity(0.1),
                              child: Icon(_iconFromKey(project.icon), color: color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(project.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                            _buildStatusBadge(project.status),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Align(alignment: Alignment.centerLeft, child: _buildPriorityBadge(project.priority)),
                        if (project.description != null && project.description!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(project.description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey.shade600)),
                        ],
                        const SizedBox(height: 8),
                        Text('Prazo: $dueDateLabel', style: const TextStyle(fontSize: 12)),
                        if (daysRemaining != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            daysRemaining >= 0 ? 'Faltam $daysRemaining dia(s) para o prazo' : 'Prazo expirado há ${daysRemaining.abs()} dia(s)',
                            style: TextStyle(color: daysRemaining >= 0 ? Colors.teal : Colors.red, fontSize: 12),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${project.progress.toInt()}% Concluído', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
            }),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(title, style: const TextStyle(fontSize: 12), maxLines: 2),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilter(String value, String label) {
    final selected = _quickFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _quickFilter = value),
      ),
    );
  }

  bool _matchesQuickFilter(Project project, {String? forcedFilter, bool showCompleted = true, bool showPaused = true}) {
    if (project.status == 'canceled') return false;
    final filter = forcedFilter ?? _quickFilter;
    if (!showCompleted && project.status == 'completed' && filter != 'completed') return false;
    if (!showPaused && project.status == 'paused' && filter != 'paused') return false;
    final isOverdue = _isOverdue(project);
    final startDate = project.startDate == null ? null : DateTime.tryParse(project.startDate!);
    final isPlanned = startDate != null && startDate.isAfter(DateTime.now());

    switch (filter) {
      case 'planned':
        return isPlanned;
      case 'in_progress':
        return project.status == 'active' && !isPlanned && !isOverdue;
      case 'paused':
        return project.status == 'paused';
      case 'completed':
        return project.status == 'completed';
      case 'overdue':
        return isOverdue;
      default:
        return true;
    }
  }

  void _applySort(List<Project> items, String sort) {
    switch (sort) {
      case 'deadline_asc':
        items.sort((a, b) {
          final ad = a.endDate == null ? null : DateTime.tryParse(a.endDate!);
          final bd = b.endDate == null ? null : DateTime.tryParse(b.endDate!);
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return ad.compareTo(bd);
        });
        break;
      case 'progress_desc':
        items.sort((a, b) => b.progress.compareTo(a.progress));
        break;
      case 'name_asc':
        items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        break;
      default:
        items.sort((a, b) {
          final ad = DateTime.tryParse(a.createdAt);
          final bd = DateTime.tryParse(b.createdAt);
          if (ad == null && bd == null) return 0;
          if (ad == null) return 1;
          if (bd == null) return -1;
          return bd.compareTo(ad);
        });
    }
  }

  bool _isOverdue(Project project) {
    if (project.endDate == null) return false;
    if (project.status == 'completed' || project.status == 'canceled') return false;
    final end = DateTime.tryParse(project.endDate!);
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }

  int? _getDaysRemaining(String? endDate) {
    if (endDate == null) return null;
    final end = DateTime.tryParse(endDate);
    if (end == null) return null;
    return end.difference(DateTime.now()).inDays;
  }

  String _formatDueDate(String? endDate) {
    if (endDate == null) return 'Sem prazo';
    final dt = DateTime.tryParse(endDate);
    if (dt == null) return 'Sem prazo';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  IconData _iconFromKey(String key) {
    switch (key) {
      case 'work':
        return Icons.work;
      case 'school':
        return Icons.school;
      case 'build':
        return Icons.build;
      case 'lightbulb':
        return Icons.lightbulb;
      default:
        return Icons.rocket_launch;
    }
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

  Widget _buildPriorityBadge(String priority) {
    Color color;
    String label;
    switch (priority) {
      case 'alta':
        color = Colors.red;
        label = 'Alta';
        break;
      case 'baixa':
        color = Colors.green;
        label = 'Baixa';
        break;
      default:
        color = Colors.orange;
        label = 'Média';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text('Prioridade: $label', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }
}
