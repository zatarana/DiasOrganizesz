import 'dart:io';

void main() {
  final file = File('lib/features/finance/finance_planning_screen.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }

  var text = file.readAsStringSync();

  text = _ensureImport(text);
  text = text.replaceFirst(
    r'''  String _money(num value) => 'R\$ ${value.toDouble().toStringAsFixed(2)}';''',
    '  String _money(num value) => MoneyFormatter.format(value);',
  );

  text = _replaceControllerInitialValues(text);
  text = _replaceMoneyParsing(text);
  text = _addInputFormatters(text);

  final checks = <String>[
    "import '../../core/utils/money_formatter.dart';",
    'String _money(num value) => MoneyFormatter.format(value);',
    'MoneyFormatter.parse(',
    'inputFormatters: const [MoneyInputFormatter()]',
    'MoneyFormatter.formatForInput(',
  ];
  for (final check in checks) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO: patch F-M1 incompleto. Faltou: $check');
      exit(1);
    }
  }

  if (text.contains(r'''String _money(num value) => 'R\$ ''') || text.contains(".replaceAll(',', '.')")) {
    stderr.writeln('ERRO: formatação/parsing monetário antigo ainda existe em finance_planning_screen.dart.');
    exit(1);
  }

  file.writeAsStringSync(text);
  stdout.writeln('F-M1 aplicado: Planejamento Financeiro usando MoneyFormatter e MoneyInputFormatter.');
}

String _ensureImport(String text) {
  if (text.contains("import '../../core/utils/money_formatter.dart';")) return text;
  return text.replaceFirst(
    "import 'package:intl/intl.dart';\n\n",
    "import 'package:intl/intl.dart';\n\nimport '../../core/utils/money_formatter.dart';\n",
  );
}

String _replaceControllerInitialValues(String text) {
  final replacements = <String, String>{
    "TextEditingController(text: account.currentBalance.toStringAsFixed(2))": "TextEditingController(text: MoneyFormatter.formatForInput(account.currentBalance))",
    "TextEditingController(text: account == null ? '' : account.initialBalance.toStringAsFixed(2))": "TextEditingController(text: account == null ? '' : MoneyFormatter.formatForInput(account.initialBalance))",
    "TextEditingController(text: budget == null ? '' : budget.limitAmount.toStringAsFixed(2))": "TextEditingController(text: budget == null ? '' : MoneyFormatter.formatForInput(budget.limitAmount))",
    "TextEditingController(text: goal == null ? '' : goal.targetAmount.toStringAsFixed(2))": "TextEditingController(text: goal == null ? '' : MoneyFormatter.formatForInput(goal.targetAmount))",
    "TextEditingController(text: goal == null ? '' : goal.currentAmount.toStringAsFixed(2))": "TextEditingController(text: goal == null ? '' : MoneyFormatter.formatForInput(goal.currentAmount))",
  };

  for (final entry in replacements.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  return text;
}

String _replaceMoneyParsing(String text) {
  final parsePattern = RegExp(r"double\.tryParse\(([A-Za-z_]\w*)\.text\.replaceAll\(',', '\.'\)\)(?:\s*\?\?\s*0(?:\.0)?)?");
  text = text.replaceAllMapped(parsePattern, (match) {
    final controller = match.group(1)!;
    final source = match.group(0)!;
    final hasFallback = source.contains('??');
    return hasFallback ? "MoneyFormatter.parse($controller.text) ?? 0" : "MoneyFormatter.parse($controller.text)";
  });

  final genericParsePattern = RegExp(r"double\.tryParse\(([^;\n]+?)\.replaceAll\(',', '\.'\)\)(?:\s*\?\?\s*0(?:\.0)?)?");
  text = text.replaceAllMapped(genericParsePattern, (match) {
    final sourceExpression = match.group(1)!;
    final source = match.group(0)!;
    final hasFallback = source.contains('??');
    return hasFallback ? "MoneyFormatter.parse($sourceExpression) ?? 0" : "MoneyFormatter.parse($sourceExpression)";
  });

  return text;
}

String _addInputFormatters(String text) {
  final moneyControllers = <String>{
    'newBalanceController',
    'balanceController',
    'limitController',
    'targetController',
    'currentController',
    'controller',
  };

  for (final controller in moneyControllers) {
    text = _addFormatterToTextFieldsForController(text, controller);
  }
  return text;
}

String _addFormatterToTextFieldsForController(String text, String controllerName) {
  final buffer = StringBuffer();
  var cursor = 0;

  while (true) {
    final start = text.indexOf('TextField(', cursor);
    if (start == -1) {
      buffer.write(text.substring(cursor));
      break;
    }

    final end = _findCallEnd(text, start);
    if (end == -1) {
      buffer.write(text.substring(cursor));
      break;
    }

    buffer.write(text.substring(cursor, start));
    var block = text.substring(start, end);
    final isTargetController = block.contains('controller: $controllerName');
    final isMoneyField = block.contains('TextInputType.numberWithOptions(decimal: true)') ||
        block.contains("keyboardType: TextInputType.numberWithOptions(decimal: true)") ||
        block.contains("keyboardType: const TextInputType.numberWithOptions(decimal: true)");

    if (isTargetController && isMoneyField && !block.contains('MoneyInputFormatter')) {
      block = _injectInputFormatter(block);
    }

    buffer.write(block);
    cursor = end;
  }

  return buffer.toString();
}

int _findCallEnd(String text, int start) {
  var depth = 0;
  for (var i = start; i < text.length; i++) {
    final char = text[i];
    if (char == '(') depth++;
    if (char == ')') {
      depth--;
      if (depth == 0) {
        var end = i + 1;
        if (end < text.length && text[end] == ',') end++;
        return end;
      }
    }
  }
  return -1;
}

String _injectInputFormatter(String block) {
  final keyboardConst = "keyboardType: const TextInputType.numberWithOptions(decimal: true)";
  final keyboardNonConst = "keyboardType: TextInputType.numberWithOptions(decimal: true)";

  if (block.contains(keyboardConst)) {
    return block.replaceFirst(keyboardConst, "$keyboardConst,\n                inputFormatters: const [MoneyInputFormatter()]");
  }
  if (block.contains(keyboardNonConst)) {
    return block.replaceFirst(keyboardNonConst, "$keyboardNonConst,\n                inputFormatters: const [MoneyInputFormatter()]");
  }
  return block;
}
