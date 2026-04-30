import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/task_model.dart';
import '../../domain/providers.dart';
import 'create_task_screen.dart';
import 'task_settings_screen.dart';

class QuickAddTaskContext {
  final DateTime? selectedDate;
  final int? categoryId;
  final int? projectId;
  final int? projectStepId;
  final int? parentTaskId;

  const QuickAddTaskContext({
    this.selectedDate,
    this.categoryId,
    this.projectId,
    this.projectStepId,
    this.parentTaskId,
  });
}

class QuickAddTaskParserResult {
  final String title;
  final DateTime? date;
  final String? time;
  final String priority;

  const QuickAddTaskParserResult({required this.title, this.date, this.time, required this.priority});
}

class QuickAddTaskParser {
  const QuickAddTaskParser._();

  static QuickAddTaskParserResult parse(
    String input, {
    DateTime? now,
    DateTime? fallbackDate,
    String defaultPriority = 'media',
  }) {
    final base = now ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    var text = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    var date = fallbackDate == null ? null : DateTime(fallbackDate.year, fallbackDate.month, fallbackDate.day);
    String? time;
    var priority = _safePriority(defaultPriority);

    final lower = text.toLowerCase();
    if (lower.contains('#alta') || lower.contains('!alta') || lower.contains(' prioridade alta')) {
      priority = 'alta';
      text = _removeTokens(text, ['#alta', '!alta', 'prioridade alta']);
    } else if (lower.contains('#baixa') || lower.contains('!baixa') || lower.contains(' prioridade baixa')) {
      priority = 'baixa';
      text = _removeTokens(text, ['#baixa', '!baixa', 'prioridade baixa']);
    } else if (lower.contains('#media') || lower.contains('#média') || lower.contains('!media') || lower.contains('!média')) {
      priority = 'media';
      text = _removeTokens(text, ['#media', '#média', '!media', '!média']);
    }

    final normalizedLower = text.toLowerCase();
    if (normalizedLower.contains('amanhã') || normalizedLower.contains('amanha')) {
      date = today.add(const Duration(days: 1));
      text = _removeTokens(text, ['amanhã', 'amanha']);
    } else if (normalizedLower.contains('hoje')) {
      date = today;
      text = _removeTokens(text, ['hoje']);
    } else if (normalizedLower.contains('semana que vem') || normalizedLower.contains('próxima semana') || normalizedLower.contains('proxima semana')) {
      date = today.add(const Duration(days: 7));
      text = _removeTokens(text, ['semana que vem', 'próxima semana', 'proxima semana']);
    }

    final timeMatch = RegExp(r'\b([01]?\d|2[0-3])[:h]([0-5]\d)\b').firstMatch(text);
    if (timeMatch != null) {
      final hour = timeMatch.group(1)!.padLeft(2, '0');
      final minute = timeMatch.group(2)!.padLeft(2, '0');
      time = '$hour:$minute';
      text = text.replaceFirst(timeMatch.group(0)!, '').trim();
    }

    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return QuickAddTaskParserResult(title: text, date: date, time: time, priority: priority);
  }

  static String _safePriority(String value) {
    if (value == 'alta' || value == 'media' || value == 'baixa') return value;
    return 'media';
  }

  static String _removeTokens(String input, List<String> tokens) {
    var output = input;
    for (final token in tokens) {
      output = output.replaceAll(RegExp(RegExp.escape(token), caseSensitive: false), '');
    }
    return output.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

class QuickAddTaskSheet extends ConsumerStatefulWidget {
  final QuickAddTaskContext contextData;
  final String title;

  const QuickAddTaskSheet({super.key, this.contextData = const QuickAddTaskContext(), this.title = 'Captura inteligente'});

  static Future<void> show(BuildContext context, {QuickAddTaskContext contextData = const QuickAddTaskContext(), String title = 'Captura inteligente'}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => QuickAddTaskSheet(contextData: contextData, title: title),
    );
  }

  @override
  ConsumerState<QuickAddTaskSheet> createState() => _QuickAddTaskSheetState();
}

class _QuickAddTaskSheetState extends ConsumerState<QuickAddTaskSheet> {
  final _controller = TextEditingController();
  final _tagController = TextEditingController();
  QuickAddTaskParserResult? _preview;
  DateTime? _selectedDate;
  String? _selectedTime;
  String _priority = 'media';
  String _recurrenceType = 'none';
  int? _categoryId;
  final List<String> _tags = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.contextData.selectedDate;
    _categoryId = widget.contextData.categoryId;
    _priority = _defaultPriority();
    _controller.addListener(_updatePreview);
    _updatePreview();
  }

  @override
  void dispose() {
    _controller.removeListener(_updatePreview);
    _controller.dispose();
    _tagController.dispose();
    super.dispose();
  }

  String _defaultPriority() {
    final settings = ref.read(taskSettingsProvider);
    final value = settings[TaskSettingsKeys.quickAddDefaultPriority] ?? TaskSettingsDefaults.quickAddDefaultPriority;
    if (value == 'alta' || value == 'media' || value == 'baixa') return value;
    return TaskSettingsDefaults.quickAddDefaultPriority;
  }

  DateTime? _fallbackDate() {
    if (_selectedDate != null) return _selectedDate;
    final settings = ref.read(taskSettingsProvider);
    final inboxAsDefault = settings[TaskSettingsKeys.inboxAsDefaultCapture] ?? TaskSettingsDefaults.inboxAsDefaultCapture;
    if (inboxAsDefault == 'false') return DateTime.now();
    return null;
  }

  QuickAddTaskParserResult _parseCurrentText() {
    final parsed = QuickAddTaskParser.parse(
      _controller.text,
      fallbackDate: _fallbackDate(),
      defaultPriority: _priority,
    );
    return QuickAddTaskParserResult(
      title: parsed.title,
      date: _selectedDate ?? parsed.date,
      time: _selectedTime ?? parsed.time,
      priority: _priority == parsed.priority ? parsed.priority : _priority,
    );
  }

  void _updatePreview() {
    if (!mounted) return;
    setState(() => _preview = _parseCurrentText());
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 10),
    );
    if (selected != null) setState(() => _selectedDate = DateTime(selected.year, selected.month, selected.day));
  }

  Future<void> _pickTime() async {
    final selected = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (selected != null) {
      setState(() => _selectedTime = '${selected.hour.toString().padLeft(2, '0')}:${selected.minute.toString().padLeft(2, '0')}');
    }
  }

  void _cyclePriority() {
    setState(() {
      _priority = switch (_priority) { 'baixa' => 'media', 'media' => 'alta', _ => 'baixa' };
    });
  }

  void _addTag(String value) {
    final clean = value.trim().replaceAll(',', '');
    if (clean.isEmpty) return;
    if (_tags.any((tag) => tag.toLowerCase() == clean.toLowerCase())) {
      _tagController.clear();
      return;
    }
    setState(() {
      _tags.add(clean);
      _tagController.clear();
    });
  }

  Future<void> _openTagDialog() async {
    _tagController.clear();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Adicionar tags'),
        content: TextField(
          controller: _tagController,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Ex: estudo, casa, urgente'),
          onSubmitted: (value) {
            for (final tag in value.split(',')) _addTag(tag);
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              for (final tag in _tagController.text.split(',')) _addTag(tag);
              Navigator.pop(ctx);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
  }

  Future<void> _selectCategory() async {
    final categories = ref.read(categoriesProvider);
    if (categories.isEmpty) return;
    final selected = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Lista / Categoria', style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(leading: const Icon(Icons.inbox_outlined), title: const Text('Sem categoria'), onTap: () => Navigator.pop(ctx, null)),
          ...categories.map((category) => ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(category.name, overflow: TextOverflow.ellipsis),
                selected: category.id == _categoryId,
                onTap: () => Navigator.pop(ctx, category.id),
              )),
        ],
      ),
    );
    setState(() => _categoryId = selected);
  }

  Future<void> _selectRecurrence() async {
    final selected = await showMenu<String>(
      context: context,
      position: const RelativeRect.fromLTRB(80, 420, 80, 0),
      items: const [
        PopupMenuItem(value: 'none', child: Text('Não repetir')),
        PopupMenuItem(value: 'daily', child: Text('Diariamente')),
        PopupMenuItem(value: 'weekly', child: Text('Semanalmente')),
        PopupMenuItem(value: 'monthly', child: Text('Mensalmente')),
      ],
    );
    if (selected != null) setState(() => _recurrenceType = selected);
  }

  Task? _buildPartialTask() {
    final parsed = _parseCurrentText();
    final title = parsed.title.trim();
    if (title.isEmpty) return null;
    final now = DateTime.now().toIso8601String();
    final date = parsed.date == null ? null : DateFormat('yyyy-MM-dd').format(parsed.date!);
    return Task(
      title: title,
      date: date,
      time: parsed.time,
      categoryId: _categoryId ?? widget.contextData.categoryId,
      projectId: widget.contextData.projectId,
      projectStepId: widget.contextData.projectId == null ? null : widget.contextData.projectStepId,
      parentTaskId: widget.contextData.parentTaskId,
      priority: parsed.priority,
      status: 'pendente',
      reminderEnabled: parsed.time != null,
      recurrenceType: _recurrenceType,
      tags: _tags.isEmpty ? null : _tags.join(', '),
      reminderOffsets: parsed.time == null ? null : '0',
      createdAt: now,
      updatedAt: now,
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    final task = _buildPartialTask();
    if (task == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Digite o título da tarefa.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      await ref.read(tasksProvider.notifier).addTask(task);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarefa criada.')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _openFullEditor() {
    final task = _buildPartialTask();
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateTaskScreen(
          task: task,
          selectedDate: _selectedDate,
          projectId: widget.contextData.projectId,
          projectStepId: widget.contextData.projectStepId,
          parentTaskId: widget.contextData.parentTaskId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _preview ?? _parseCurrentText();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: bottomInset + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(backgroundColor: Theme.of(context).colorScheme.primaryContainer, child: const Icon(Icons.add_task)),
                const SizedBox(width: 12),
                Expanded(child: Text(widget.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))),
              ],
            ),
            const SizedBox(height: 6),
            const Text('Digite livremente ou use os atalhos. Ex: estudar amanhã 19:30 #alta.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'O que precisa ser feito?',
                hintText: 'Ex: revisar português amanhã 09:00 #alta',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 10),
            _SmartShortcutBar(
              priority: _priority,
              recurrenceType: _recurrenceType,
              onDate: _pickDate,
              onTime: _pickTime,
              onPriority: _cyclePriority,
              onCategory: _selectCategory,
              onTags: _openTagDialog,
              onRepeat: _selectRecurrence,
            ),
            if (_tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _tags.map((tag) => InputChip(label: Text(tag), onDeleted: () => setState(() => _tags.remove(tag)))).toList(),
              ),
            ],
            const SizedBox(height: 12),
            _QuickAddPreview(parsed: parsed, contextData: widget.contextData, recurrenceType: _recurrenceType),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSaving ? null : _openFullEditor,
                    icon: const Icon(Icons.open_in_full),
                    label: const Text('Mais opções'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check),
                    label: Text(_isSaving ? 'Salvando...' : 'Criar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartShortcutBar extends StatelessWidget {
  final String priority;
  final String recurrenceType;
  final VoidCallback onDate;
  final VoidCallback onTime;
  final VoidCallback onPriority;
  final VoidCallback onCategory;
  final VoidCallback onTags;
  final VoidCallback onRepeat;

  const _SmartShortcutBar({required this.priority, required this.recurrenceType, required this.onDate, required this.onTime, required this.onPriority, required this.onCategory, required this.onTags, required this.onRepeat});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _ShortcutChip(icon: Icons.calendar_today, label: 'Data', onTap: onDate),
          _ShortcutChip(icon: Icons.access_time, label: 'Hora', onTap: onTime),
          _ShortcutChip(icon: Icons.flag, label: _priorityLabel(priority), onTap: onPriority),
          _ShortcutChip(icon: Icons.folder_outlined, label: 'Lista', onTap: onCategory),
          _ShortcutChip(icon: Icons.label_outline, label: 'Tags', onTap: onTags),
          _ShortcutChip(icon: Icons.repeat, label: _recurrenceLabel(recurrenceType), onTap: onRepeat),
        ],
      ),
    );
  }
}

class _ShortcutChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShortcutChip({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(avatar: Icon(icon, size: 18), label: Text(label), onPressed: onTap),
    );
  }
}

class _QuickAddPreview extends StatelessWidget {
  final QuickAddTaskParserResult parsed;
  final QuickAddTaskContext contextData;
  final String recurrenceType;

  const _QuickAddPreview({required this.parsed, required this.contextData, required this.recurrenceType});

  @override
  Widget build(BuildContext context) {
    final dateLabel = parsed.date == null ? 'Inbox / sem data' : DateFormat('dd/MM/yyyy').format(parsed.date!);
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _PreviewChip(icon: Icons.title, label: parsed.title.isEmpty ? 'Título pendente' : parsed.title),
            _PreviewChip(icon: Icons.event, label: dateLabel),
            if (parsed.time != null) _PreviewChip(icon: Icons.access_time, label: parsed.time!),
            _PreviewChip(icon: Icons.flag, label: _priorityLabel(parsed.priority)),
            if (recurrenceType != 'none') _PreviewChip(icon: Icons.repeat, label: _recurrenceLabel(recurrenceType)),
            if (contextData.projectId != null) const _PreviewChip(icon: Icons.rocket_launch, label: 'Projeto herdado'),
            if (contextData.parentTaskId != null) const _PreviewChip(icon: Icons.account_tree, label: 'Subtarefa'),
          ],
        ),
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PreviewChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 16), label: Text(label, overflow: TextOverflow.ellipsis));
  }
}

String _priorityLabel(String value) => switch (value) { 'alta' => 'Alta', 'baixa' => 'Baixa', _ => 'Média' };
String _recurrenceLabel(String value) => switch (value) { 'daily' => 'Diária', 'weekly' => 'Semanal', 'monthly' => 'Mensal', _ => 'Repetir' };
