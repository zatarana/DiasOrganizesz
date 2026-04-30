import 'package:flutter/material.dart';

import 'quick_add_task_sheet.dart';

class QuickAddTaskButton extends StatelessWidget {
  final QuickAddTaskContext contextData;
  final String label;
  final bool extended;

  const QuickAddTaskButton({
    super.key,
    this.contextData = const QuickAddTaskContext(),
    this.label = 'Capturar tarefa',
    this.extended = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!extended) {
      return FloatingActionButton(
        tooltip: 'Capturar tarefa',
        onPressed: () => QuickAddTaskSheet.show(context, contextData: contextData),
        child: const Icon(Icons.add),
      );
    }

    return FloatingActionButton.extended(
      onPressed: () => QuickAddTaskSheet.show(context, contextData: contextData),
      icon: const Icon(Icons.add),
      label: Text(label),
    );
  }
}

class SmartTaskActionButton extends QuickAddTaskButton {
  const SmartTaskActionButton({
    super.key,
    super.contextData,
    super.label = 'Capturar tarefa',
    super.extended = true,
  });
}

class QuickAddTaskIconButton extends StatelessWidget {
  final QuickAddTaskContext contextData;
  final String tooltip;

  const QuickAddTaskIconButton({
    super.key,
    this.contextData = const QuickAddTaskContext(),
    this.tooltip = 'Capturar tarefa',
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.add),
      onPressed: () => QuickAddTaskSheet.show(context, contextData: contextData),
    );
  }
}
