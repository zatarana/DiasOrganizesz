import 'package:diasorganize/data/models/financial_goal_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FinancialGoal model', () {
    test('toMap padrão mantém compatibilidade com stores antigos', () {
      final goal = FinancialGoal(
        name: 'Reserva',
        targetAmount: 1000,
        currentAmount: 100,
        accountId: 1,
        projectId: 99,
        isArchived: true,
        createdAt: '2026-04-01T00:00:00.000',
        updatedAt: '2026-04-01T00:00:00.000',
      );

      final map = goal.toMap();

      expect(map.containsKey('projectId'), false);
      expect(map.containsKey('isArchived'), false);
      expect(map['name'], 'Reserva');
      expect(map['targetAmount'], 1000);
      expect(map['accountId'], 1);
    });

    test('toMap com campos estendidos preserva projectId e isArchived', () {
      final goal = FinancialGoal(
        name: 'Projeto viagem',
        targetAmount: 5000,
        currentAmount: 1200,
        projectId: 42,
        isArchived: true,
        createdAt: '2026-04-01T00:00:00.000',
        updatedAt: '2026-04-01T00:00:00.000',
      );

      final map = goal.toMap(includeExtendedFields: true);

      expect(map['projectId'], 42);
      expect(map['isArchived'], 1);
    });
  });
}
