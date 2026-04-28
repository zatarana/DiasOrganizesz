import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';

class TaskSettingsKeys {
  static const defaultView = 'tasks_default_view';
  static const showCompletedInline = 'tasks_show_completed_inline';
  static const showSubtasksInline = 'tasks_show_subtasks_inline';
  static const showProjectBadges = 'tasks_show_project_badges';
  static const defaultSort = 'tasks_default_sort';
  static const defaultReminderHour = 'tasks_default_reminder_hour';
  static const quickAddDefaultPriority = 'tasks_quick_add_default_priority';
  static const inboxAsDefaultCapture = 'tasks_inbox_as_default_capture';
}

class TaskSettingsDefaults {
  static const defaultView = 'central';
  static const showCompletedInline = 'false';
  static const showSubtasksInline = 'true';
  static const showProjectBadges = 'true';
  static const defaultSort = 'schedule_priority';
  static const defaultReminderHour = '09:00';
  static const quickAddDefaultPriority = 'media';
  static const inboxAsDefaultCapture = 'true';
}

class TaskSettingsScreen extends ConsumerWidget {
  const TaskSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    String valueOf(String key, String fallback) => settings[key] ?? fallback;
    bool boolOf(String key, String fallback) => valueOf(key, fallback) == 'true';

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações de tarefas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          const _SettingsHeader(),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Abertura e visualização',
            children: [
              _DropdownSetting(
                title: 'Tela padrão de tarefas',
                subtitle: 'Define a visão preferida para evoluções futuras da aba.',
                value: valueOf(TaskSettingsKeys.defaultView, TaskSettingsDefaults.defaultView),
                items: const {
                  'central': 'Central',
                  'today': 'Hoje',
                  'inbox': 'Inbox',
                  'classic': 'Lista clássica',
                  'kanban': 'Kanban',
                },
                onChanged: (value) => notifier.setValue(TaskSettingsKeys.defaultView, value),
              ),
              _DropdownSetting(
                title: 'Ordenação padrão',
                subtitle: 'Base para listas inteligentes e futuras telas configuráveis.',
                value: valueOf(TaskSettingsKeys.defaultSort, TaskSettingsDefaults.defaultSort),
                items: const {
                  'schedule_priority': 'Data e prioridade',
                  'priority_schedule': 'Prioridade e data',
                  'title': 'Título',
                  'created_desc': 'Mais recentes',
                },
                onChanged: (value) => notifier.setValue(TaskSettingsKeys.defaultSort, value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Cards e detalhes',
            children: [
              SwitchListTile(
                value: boolOf(TaskSettingsKeys.showCompletedInline, TaskSettingsDefaults.showCompletedInline),
                title: const Text('Mostrar concluídas junto das ativas'),
                subtitle: const Text('Preparado para telas futuras que exibem listas mistas.'),
                onChanged: (value) => notifier.setValue(TaskSettingsKeys.showCompletedInline, '$value'),
              ),
              SwitchListTile(
                value: boolOf(TaskSettingsKeys.showSubtasksInline, TaskSettingsDefaults.showSubtasksInline),
                title: const Text('Mostrar subtarefas inline'),
                subtitle: const Text('Mantém subtarefas visíveis dentro do contexto da tarefa pai.'),
                onChanged: (value) => notifier.setValue(TaskSettingsKeys.showSubtasksInline, '$value'),
              ),
              SwitchListTile(
                value: boolOf(TaskSettingsKeys.showProjectBadges, TaskSettingsDefaults.showProjectBadges),
                title: const Text('Mostrar selo de projeto'),
                subtitle: const Text('Exibe quando uma tarefa pertence a um projeto.'),
                onChanged: (value) => notifier.setValue(TaskSettingsKeys.showProjectBadges, '$value'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Captura rápida',
            children: [
              SwitchListTile(
                value: boolOf(TaskSettingsKeys.inboxAsDefaultCapture, TaskSettingsDefaults.inboxAsDefaultCapture),
                title: const Text('Capturar sem contexto no Inbox'),
                subtitle: const Text('Quando não houver data/projeto, a tarefa fica solta para organizar depois.'),
                onChanged: (value) => notifier.setValue(TaskSettingsKeys.inboxAsDefaultCapture, '$value'),
              ),
              _DropdownSetting(
                title: 'Prioridade padrão do Quick Add',
                subtitle: 'Usada quando o texto não informa #alta, #media ou #baixa.',
                value: valueOf(TaskSettingsKeys.quickAddDefaultPriority, TaskSettingsDefaults.quickAddDefaultPriority),
                items: const {
                  'baixa': 'Baixa',
                  'media': 'Média',
                  'alta': 'Alta',
                },
                onChanged: (value) => notifier.setValue(TaskSettingsKeys.quickAddDefaultPriority, value),
              ),
              _DropdownSetting(
                title: 'Hora padrão de lembrete',
                subtitle: 'Preparado para lembretes automáticos futuros em tarefas com data.',
                value: valueOf(TaskSettingsKeys.defaultReminderHour, TaskSettingsDefaults.defaultReminderHour),
                items: const {
                  '07:00': '07:00',
                  '08:00': '08:00',
                  '09:00': '09:00',
                  '12:00': '12:00',
                  '18:00': '18:00',
                  '20:00': '20:00',
                },
                onChanged: (value) => notifier.setValue(TaskSettingsKeys.defaultReminderHour, value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Resumo atual',
            children: [
              _SummaryLine(label: 'Tela padrão', value: _labelForDefaultView(valueOf(TaskSettingsKeys.defaultView, TaskSettingsDefaults.defaultView))),
              _SummaryLine(label: 'Ordenação', value: _labelForSort(valueOf(TaskSettingsKeys.defaultSort, TaskSettingsDefaults.defaultSort))),
              _SummaryLine(label: 'Subtarefas inline', value: boolOf(TaskSettingsKeys.showSubtasksInline, TaskSettingsDefaults.showSubtasksInline) ? 'Sim' : 'Não'),
              _SummaryLine(label: 'Prioridade Quick Add', value: valueOf(TaskSettingsKeys.quickAddDefaultPriority, TaskSettingsDefaults.quickAddDefaultPriority)),
              _SummaryLine(label: 'Hora padrão', value: valueOf(TaskSettingsKeys.defaultReminderHour, TaskSettingsDefaults.defaultReminderHour)),
            ],
          ),
        ],
      ),
    );
  }

  String _labelForDefaultView(String value) {
    switch (value) {
      case 'today':
        return 'Hoje';
      case 'inbox':
        return 'Inbox';
      case 'classic':
        return 'Lista clássica';
      case 'kanban':
        return 'Kanban';
      default:
        return 'Central';
    }
  }

  String _labelForSort(String value) {
    switch (value) {
      case 'priority_schedule':
        return 'Prioridade e data';
      case 'title':
        return 'Título';
      case 'created_desc':
        return 'Mais recentes';
      default:
        return 'Data e prioridade';
    }
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: const Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(child: Icon(Icons.tune)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Preferências da aba Tarefas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('Ajustes preparados para central, cards, Quick Add e futuras listas configuráveis.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DropdownSetting extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final Map<String, String> items;
  final ValueChanged<String> onChanged;

  const _DropdownSetting({required this.title, required this.subtitle, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final safeValue = items.containsKey(value) ? value : items.keys.first;
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: DropdownButton<String>(
        value: safeValue,
        items: items.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value))).toList(),
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(label),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}
