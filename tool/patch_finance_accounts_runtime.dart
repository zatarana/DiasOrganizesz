import 'dart:io';

void main() {
  _patchPlanningScreen();
  _patchMoneyFormatter();
  stdout.writeln('Correções runtime de contas financeiras aplicadas.');
}

void _patchPlanningScreen() {
  final file = File('lib/features/finance/finance_planning_screen.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }

  var text = file.readAsStringSync();

  // Saldo inicial/base e ajuste real podem ser negativos; orçamento/metas continuam positivos.
  text = text.replaceAll(
    r'''controller: newBalanceController,
                decoration: const InputDecoration(labelText: 'Novo saldo real', prefixText: 'R\$ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: const [MoneyInputFormatter()]''',
    r'''controller: newBalanceController,
                decoration: const InputDecoration(labelText: 'Novo saldo real', prefixText: 'R\$ '),
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                inputFormatters: const [MoneyInputFormatter(allowNegative: true)]''',
  );

  text = text.replaceAll(
    r'''TextField(controller: balanceController, decoration: const InputDecoration(labelText: 'Saldo inicial/base', helperText: 'O saldo atual será calculado com as transações pagas, transferências e reajustes desta conta.'), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: const [MoneyInputFormatter()])''',
    r'''TextField(controller: balanceController, decoration: const InputDecoration(labelText: 'Saldo inicial/base', helperText: 'Use negativo para conta devedora, cheque especial ou cartão.'), keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true), inputFormatters: const [MoneyInputFormatter(allowNegative: true)])''',
  );

  // Fallback para versões multiline do campo de saldo inicial/base.
  text = text.replaceAll(
    'keyboardType: const TextInputType.numberWithOptions(decimal: true),\n                inputFormatters: const [MoneyInputFormatter()],',
    'keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),\n                inputFormatters: const [MoneyInputFormatter(allowNegative: true)],',
  );

  // Evita dispose imediato durante o fechamento animado do AlertDialog, que pode disparar _dependents.isEmpty.
  text = text.replaceAll('    newBalanceController.dispose();\n    reasonController.dispose();\n    notesController.dispose();\n', '');
  text = text.replaceAll('    nameController.dispose();\n    balanceController.dispose();\n', '');

  if (!text.contains('MoneyInputFormatter(allowNegative: true)')) {
    stderr.writeln('ERRO: saldo negativo não foi habilitado nas contas financeiras.');
    exit(1);
  }
  if (text.contains('newBalanceController.dispose();') || text.contains('balanceController.dispose();')) {
    stderr.writeln('ERRO: dispose imediato dos controllers de conta ainda existe.');
    exit(1);
  }

  file.writeAsStringSync(text);
}

void _patchMoneyFormatter() {
  final file = File('lib/core/utils/money_formatter.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }

  final text = file.readAsStringSync();
  for (final check in [
    'final bool allowNegative;',
    'const MoneyInputFormatter({this.allowNegative = false});',
    "final isNegative = allowNegative && newValue.text.contains('-');",
    'return negative ? -parsed : parsed;',
  ]) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO: MoneyFormatter sem suporte completo a negativo. Faltou: $check');
      exit(1);
    }
  }
}
