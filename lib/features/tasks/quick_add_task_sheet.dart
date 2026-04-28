import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/models/task_model.dart';
import '../../domain/providers.dart';

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

  static QuickAddTaskParserResult parse(String input, {DateTime? now, DateTime? fallbackDate}) {
    final base = now ?? DateTime.now();
    final today = DateTime(base.year, base.month, base.day);
    var text = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    var date = fallbackDate == null ? null : DateTime(fallbackDate.year, fallbackDate.month, fallbackDate.day);
    String? time;
    var priority = 'media';

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
    if (RegExp(r'\bamanh[ãa]\b').hasMatch(normalizedLower)) {
      date = today.add(const Duration(days: 1));
      text = text.replaceAll(RegExp(r'\bamanh[ãa]\b', caseSensitive: false), '').trim();
    } else if (RegExp(r'\bhoje\b').hasMatch(normalizedLower)) {
      date = today;
      text = text.replaceAll(RegExp(r'\bhoje\b', caseSensitive: false), '').trim();
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

  const QuickAddTaskSheet({super.key, this.contextData = const QuickAddTaskContext(), this.title = 'Captura rápida'});

  static Future<void> show(BuildContext context, {QuickAddTaskContext contextData = const QuickAddTaskContext(), String title = 'Captura rápida'}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => QuickAddTaskSheet(contextData: contextData, title: title),
    );
  }

  @override
  ConsumerState<QuickAddTaskSheet> createState() => _QuickAddTaskSheetState();
}

class _QuickAddTaskSheetState extends ConsumerState<QuickAddTaskSheet> {
  final _controller = TextEditingController();
  QuickAddTaskParserResult? _preview;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updatePreview);
    _updatePreview();
  }

  @override
  void dispose() {
    _controller.removeListener(_updatePreview);
    _controller.dispose();
    super.dispose();
  }

  void _updatePreview() {
    setState(() {
      _preview = QuickAddTaskParser.parse(_controller.text, fallbackDate: widget.contextData.selectedDate);
    });
  }

  Future<void> _save() async {
    final parsed = QuickAddTaskParser.parse(_controller.text, fallbackDate: widget.contextData.selectedDate);
    if (parsed.title.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Digite o título da tarefa.')));
      return;
    }

    final now = DateTime.now().toIso8601String();
    final isSubtask = widget.contextData.parentTaskId != null;
    final task = Task(
      title: parsed.title.trim(),
      date: parsed.date == null ? null : DateFormat('yyyy-MM-dd').format(parsed.date!),
      time: parsed.time,
      categoryId: widget.contextData.categoryId,
      projectId: widget.contextData.projectId,
      projectStepId: widget.contextData.projectId == null ? null : widget.contextData.projectStepId,
      parentTaskId: widget.contextData.parentTaskId,
      priority: parsed.priority,
      status: 'pendente',
      reminderEnabled: false,
      recurrenceType: isSubtask ? 'none' : 'none',
      createdAt: now,
      updatedAt: now,
    );

    await ref.read(tasksProvider.notifier).addTask(task);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarefa criada.')));
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _preview ?? QuickAddTaskParser.parse(_controller.text, fallbackDate: widget.contextData.selectedDate);
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('Use termos como hoje, amanhã, 18:30, #alta ou #baixa.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Nova tarefa',
                hintText: 'Ex: pagar conta amanhã 09:00 #alta',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            _QuickAddPreview(parsed: parsed, contextData: widget.contextData),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _save, icon: const Icon(Icons.add), label: const Text('Criar tarefa')),
          ],
        ),
      ),
    );
  }
}

class _QuickAddPreview extends StatelessWidget {
  final QuickAddTaskParserResult parsed;
  final QuickAddTaskContext contextData;

  const _QuickAddPreview({required this.parsed, required this.contextData});

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
            _PreviewChip(icon: Icons.flag, label: parsed.priority),
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
    return Chip(avatar: Icon(icon, size: 16), label: Text(label));
  }
}
