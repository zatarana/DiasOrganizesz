import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml');
  final screen = File('lib/features/finance/finance_screen.dart');

  if (!pubspec.existsSync() || !screen.existsSync()) {
    stderr.writeln('ERRO Etapa 6: arquivos esperados não encontrados.');
    exit(1);
  }

  final pubspecText = pubspec.readAsStringSync();
  final screenText = screen.readAsStringSync();

  final checks = <String>[
    "import 'package:flutter_slidable/flutter_slidable.dart';",
    'Widget _buildQuickFilterBar()',
    "_quickFilterChip('Todas'",
    "_quickFilterChip('Receitas'",
    "_quickFilterChip('Despesas'",
    "_quickFilterChip('Pagas'",
    "_quickFilterChip('Pendentes'",
    "_quickFilterChip('Atrasadas'",
    'Slidable(',
    'ActionPane(',
    'SlidableAction(',
    'DrawerMotion()',
    "label: isPaid ? 'Desmarcar' : 'Pagar'",
    "label: 'Editar'",
    "label: 'Excluir'",
    'showQuickTransactionBottomSheet(context)',
  ];

  if (!pubspecText.contains('flutter_slidable:')) {
    stderr.writeln('ERRO Etapa 6: pubspec.yaml sem flutter_slidable.');
    exit(1);
  }

  for (final check in checks) {
    if (!screenText.contains(check)) {
      stderr.writeln('ERRO Etapa 6: FinanceScreen incompleta. Faltou: $check');
      exit(1);
    }
  }

  if (screenText.contains('Dismissible(') || screenText.contains('DismissDirection.horizontal')) {
    stderr.writeln('ERRO Etapa 6: Dismissible antigo ainda aparece.');
    exit(1);
  }

  stdout.writeln('Etapa 6 OK: FinanceScreen usa filtros rápidos e Slidable.');
}
