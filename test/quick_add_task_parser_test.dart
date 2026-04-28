import 'package:diasorganize/features/tasks/quick_add_task_sheet.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QuickAddTaskParser', () {
    final now = DateTime(2026, 4, 28, 10);

    test('interpreta hoje, horário e prioridade alta', () {
      final result = QuickAddTaskParser.parse('pagar conta hoje 09:30 #alta', now: now);

      expect(result.title, 'pagar conta');
      expect(result.date, DateTime(2026, 4, 28));
      expect(result.time, '09:30');
      expect(result.priority, 'alta');
    });

    test('interpreta amanhã e prioridade baixa', () {
      final result = QuickAddTaskParser.parse('ligar para oficina amanhã 8h15 #baixa', now: now);

      expect(result.title, 'ligar para oficina');
      expect(result.date, DateTime(2026, 4, 29));
      expect(result.time, '08:15');
      expect(result.priority, 'baixa');
    });

    test('usa data de contexto quando texto não informa data', () {
      final result = QuickAddTaskParser.parse(
        'revisar proposta',
        now: now,
        fallbackDate: DateTime(2026, 5, 2, 18),
      );

      expect(result.title, 'revisar proposta');
      expect(result.date, DateTime(2026, 5, 2));
      expect(result.time, null);
      expect(result.priority, 'media');
    });

    test('interpreta próxima semana', () {
      final result = QuickAddTaskParser.parse('comprar material semana que vem', now: now);

      expect(result.title, 'comprar material');
      expect(result.date, DateTime(2026, 5, 5));
    });

    test('mantém Inbox quando não há data nem contexto', () {
      final result = QuickAddTaskParser.parse('ideia solta', now: now);

      expect(result.title, 'ideia solta');
      expect(result.date, null);
      expect(result.time, null);
      expect(result.priority, 'media');
    });

    test('usa prioridade padrão quando texto não define prioridade', () {
      final result = QuickAddTaskParser.parse('organizar mesa', now: now, defaultPriority: 'alta');

      expect(result.title, 'organizar mesa');
      expect(result.priority, 'alta');
    });

    test('prioridade explícita no texto sobrescreve prioridade padrão', () {
      final result = QuickAddTaskParser.parse('organizar mesa #baixa', now: now, defaultPriority: 'alta');

      expect(result.title, 'organizar mesa');
      expect(result.priority, 'baixa');
    });

    test('prioridade padrão inválida cai para média', () {
      final result = QuickAddTaskParser.parse('organizar mesa', now: now, defaultPriority: 'urgente');

      expect(result.priority, 'media');
    });
  });
}
