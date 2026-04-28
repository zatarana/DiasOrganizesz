import 'package:flutter/material.dart';

import 'quick_add_task_sheet.dart';

class QuickAddTaskButton extends StatelessWidget {
  final QuickAddTaskContext contextData;
  final String label;
  final bool extended;

  const QuickAddTaskButton({
    super.key,
    this.contextData = const QuickAddTaskContext(),
    this.label = 'Quick Add',
    this.extended = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!extended) {
      return FloatingActionButton(
        onPressed: () => QuickAddTaskSheet.show(context, contextData: contextData),
        child: const Icon(Icons.flash_on),
      );
    }

    return FloatingActionButton.extended(
      onPressed: () => QuickAddTaskSheet.show(context, contextData: contextData),
      icon: const Icon(Icons.flash_on),
      label: Text(label),
    );
  }
}

class QuickAddTaskIconButton extends StatelessWidget {
  final QuickAddTaskContext contextData;
  final String tooltip;

  const QuickAddTaskIconButton({
    super.key,
    this.contextData = const QuickAddTaskContext(),
    this.tooltip = 'Captura rápida',
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: const Icon(Icons.flash_on),
      onPressed: () => QuickAddTaskSheet.show(context, contextData: contextData),
    );
  }
}
