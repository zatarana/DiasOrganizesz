import 'package:diasorganize/data/database/financial_goal_store.dart';
import 'package:diasorganize/data/models/financial_goal_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> openGoalProjectLinkTestDatabase() async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
  await FinancialGoalStore.ensureTables(db);
  return db;
}

FinancialGoal goal({
  required String name,
  int? projectId,
  bool isArchived = false,
}) {
  final now = DateTime(2026, 4, 1).toIso8601String();
  return FinancialGoal(
    name: name,
    targetAmount: 1000,
    currentAmount: 100,
    projectId: projectId,
    isArchived: isArchived,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('FinancialGoalStore project link', () {
    test('getGoalsForProject retorna apenas objetivos do projeto informado', () async {
      final db = await openGoalProjectLinkTestDatabase();

      await FinancialGoalStore.upsertGoal(db, goal(name: 'Projeto A - orçamento', projectId: 10));
      await FinancialGoalStore.upsertGoal(db, goal(name: 'Projeto B - orçamento', projectId: 20));
      await FinancialGoalStore.upsertGoal(db, goal(name: 'Meta solta'));

      final goals = await FinancialGoalStore.getGoalsForProject(db, 10);

      expect(goals.length, 1);
      expect(goals.first.name, 'Projeto A - orçamento');
      expect(goals.first.projectId, 10);
      await db.close();
    });

    test('getGoalsForProject respeita arquivamento por padrão', () async {
      final db = await openGoalProjectLinkTestDatabase();

      await FinancialGoalStore.upsertGoal(db, goal(name: 'Ativo', projectId: 10));
      await FinancialGoalStore.upsertGoal(db, goal(name: 'Arquivado', projectId: 10, isArchived: true));

      final activeOnly = await FinancialGoalStore.getGoalsForProject(db, 10);
      final all = await FinancialGoalStore.getGoalsForProject(db, 10, includeArchived: true);

      expect(activeOnly.length, 1);
      expect(activeOnly.first.name, 'Ativo');
      expect(all.length, 2);
      await db.close();
    });
  });
}
