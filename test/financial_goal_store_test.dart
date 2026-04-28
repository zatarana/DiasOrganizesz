import 'package:diasorganize/data/database/financial_goal_store.dart';
import 'package:diasorganize/data/models/financial_goal_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openFinancialGoalTestDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
  await FinancialGoalStore.ensureTables(db);
  return db;
}

FinancialGoal goal({
  int? id,
  String name = 'Reserva de emergência',
  double targetAmount = 10000,
  double currentAmount = 0,
  String status = 'active',
  bool isArchived = false,
}) {
  final now = DateTime(2026, 4, 1).toIso8601String();
  return FinancialGoal(
    id: id,
    name: name,
    description: 'Guardar dinheiro para segurança financeira',
    targetAmount: targetAmount,
    currentAmount: currentAmount,
    accountId: 1,
    targetDate: DateTime(2026, 12, 31).toIso8601String(),
    status: status,
    isArchived: isArchived,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('FinancialGoalStore', () {
    test('upsertGoal cria e edita objetivo financeiro', () async {
      final db = await openFinancialGoalTestDatabase();
      final id = await FinancialGoalStore.upsertGoal(db, goal());

      await FinancialGoalStore.upsertGoal(
        db,
        goal(id: id).copyWith(
          name: 'Reserva ampliada',
          targetAmount: 15000,
          currentAmount: 2500,
          updatedAt: DateTime(2026, 4, 2).toIso8601String(),
        ),
      );

      final goals = await FinancialGoalStore.getGoals(db);
      expect(goals.length, 1);
      expect(goals.first.name, 'Reserva ampliada');
      expect(goals.first.targetAmount, 15000);
      expect(goals.first.currentAmount, 2500);
      await db.close();
    });

    test('upsertGoal valida nome, alvo e valor atual', () async {
      final db = await openFinancialGoalTestDatabase();

      await expectLater(FinancialGoalStore.upsertGoal(db, goal(name: '')), throwsArgumentError);
      await expectLater(FinancialGoalStore.upsertGoal(db, goal(targetAmount: 0)), throwsArgumentError);
      await expectLater(FinancialGoalStore.upsertGoal(db, goal(currentAmount: -1)), throwsArgumentError);
      await db.close();
    });

    test('archiveGoal remove da listagem padrão e mantém em includeArchived', () async {
      final db = await openFinancialGoalTestDatabase();
      final id = await FinancialGoalStore.upsertGoal(db, goal());

      await FinancialGoalStore.archiveGoal(db, id);

      final activeGoals = await FinancialGoalStore.getGoals(db);
      final allGoals = await FinancialGoalStore.getGoals(db, includeArchived: true);

      expect(activeGoals, isEmpty);
      expect(allGoals.length, 1);
      expect(allGoals.first.isArchived, true);
      await db.close();
    });

    test('updateGoalProgress atualiza progresso e conclui ao atingir valor alvo', () async {
      final db = await openFinancialGoalTestDatabase();
      final id = await FinancialGoalStore.upsertGoal(db, goal(targetAmount: 1000, currentAmount: 100));

      await FinancialGoalStore.updateGoalProgress(db, id, 1000);

      final updated = (await FinancialGoalStore.getGoals(db)).first;
      expect(updated.currentAmount, 1000);
      expect(updated.status, 'completed');
      await db.close();
    });

    test('updateGoalProgress reativa objetivo concluído se progresso cair abaixo do alvo', () async {
      final db = await openFinancialGoalTestDatabase();
      final id = await FinancialGoalStore.upsertGoal(db, goal(targetAmount: 1000, currentAmount: 1000, status: 'completed'));

      await FinancialGoalStore.updateGoalProgress(db, id, 800);

      final updated = (await FinancialGoalStore.getGoals(db)).first;
      expect(updated.currentAmount, 800);
      expect(updated.status, 'active');
      await db.close();
    });

    test('updateGoalProgress bloqueia valor negativo e objetivo inexistente', () async {
      final db = await openFinancialGoalTestDatabase();

      await expectLater(FinancialGoalStore.updateGoalProgress(db, 999, 100), throwsArgumentError);

      final id = await FinancialGoalStore.upsertGoal(db, goal());
      await expectLater(FinancialGoalStore.updateGoalProgress(db, id, -1), throwsArgumentError);
      await db.close();
    });

    test('exportTables e resetGoalData funcionam', () async {
      final db = await openFinancialGoalTestDatabase();
      await FinancialGoalStore.upsertGoal(db, goal());

      final exported = await FinancialGoalStore.exportTables(db);
      expect((exported['financial_goals'] as List).length, 1);

      await FinancialGoalStore.resetGoalData(db);
      expect(await FinancialGoalStore.getGoals(db, includeArchived: true), isEmpty);
      await db.close();
    });
  });
}
