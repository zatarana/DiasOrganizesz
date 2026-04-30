import 'dart:io';

void main() {
  final file = File('lib/features/finance/finance_hub_screen.dart');
  if (!file.existsSync()) {
    stderr.writeln('ERRO Etapa 8: finance_hub_screen.dart não encontrado.');
    exit(1);
  }

  final text = file.readAsStringSync();
  final checks = [
    "AppBar(title: const Text('Ferramentas financeiras'))",
    'Ferramentas de gestão',
    'O dashboard principal fica na aba Finanças',
    'Configurar e organizar',
    'Planejar',
    'Analisar e exportar',
    'FinanceBudgetsScreen',
    'FinancePlanningScreen',
    'FinancialGoalsScreen',
    'FinanceReportsScreen',
    'FinanceExportScreen',
  ];

  for (final check in checks) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO Etapa 8: hub financeiro incompleto. Faltou: $check');
      exit(1);
    }
  }

  if (text.contains("AppBar(title: const Text('Central Financeira'))") || text.contains('Tudo que move seu dinheiro, em um só lugar')) {
    stderr.writeln('ERRO Etapa 8: texto antigo de central/dashboard ainda aparece.');
    exit(1);
  }

  stdout.writeln('Etapa 8 OK: FinanceHubScreen reposicionado como ferramentas financeiras.');
}
