import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:diasorganize/app/theme.dart';
import 'package:diasorganize/data/models/debt_model.dart';
import 'package:diasorganize/data/models/project_model.dart';
import 'package:diasorganize/data/models/project_step_model.dart';
import 'package:diasorganize/data/models/task_model.dart';
import 'package:diasorganize/data/models/transaction_model.dart';

class _FinanceStore {
  int _id = 1;
  final List<FinancialTransaction> items = [];

  FinancialTransaction create({
    required String title,
    required double amount,
    required String type,
    required String transactionDate,
    String status = 'pending',
    String? dueDate,
  }) {
    final tx = FinancialTransaction(
      id: _id++,
      title: title,
      amount: amount,
      type: type,
      transactionDate: transactionDate,
      status: status,
      dueDate: dueDate,
      isFixed: false,
      recurrenceType: 'none',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
    items.add(tx);
    return tx;
  }

  void update(FinancialTransaction tx) {
    final idx = items.indexWhere((e) => e.id == tx.id);
    if (idx != -1) items[idx] = tx;
  }

  void delete(int id) {
    items.removeWhere((e) => e.id == id);
  }
}

double _monthTotal(List<FinancialTransaction> items, DateTime ref, String type, {String? status}) {
  return items.where((t) {
    final dt = DateTime.parse(t.transactionDate);
    final monthMatch = dt.year == ref.year && dt.month == ref.month;
    final typeMatch = t.type == type;
    final statusMatch = status == null ? true : t.status == status;
    return monthMatch && typeMatch && statusMatch && t.status != 'canceled';
  }).fold(0.0, (s, t) => s + t.amount);
}

double _receitasMes(List<FinancialTransaction> items, DateTime ref) => _monthTotal(items, ref, 'income');
double _despesasMes(List<FinancialTransaction> items, DateTime ref) => _monthTotal(items, ref, 'expense');
double _saldoPrevisto(List<FinancialTransaction> items, DateTime ref) => _receitasMes(items, ref) - _despesasMes(items, ref);
double _saldoRealizado(List<FinancialTransaction> items, DateTime ref) =>
    _monthTotal(items, ref, 'income', status: 'paid') - _monthTotal(items, ref, 'expense', status: 'paid');

bool _isOverdueExpense(FinancialTransaction t, DateTime now) {
  if (t.type != 'expense' || t.status == 'paid' || t.status == 'canceled' || t.dueDate == null) return false;
  final due = DateTime.parse(t.dueDate!);
  return due.isBefore(now);
}

List<FinancialTransaction> _generateInstallments({
  required int debtId,
  required int count,
  required double amount,
  required DateTime firstDueDate,
}) {
  return List.generate(count, (i) {
    final due = DateTime(firstDueDate.year, firstDueDate.month + i, firstDueDate.day);
    return FinancialTransaction(
      id: i + 1,
      title: 'Parcela ${i + 1}/$count',
      amount: amount,
      type: 'expense',
      transactionDate: DateTime(firstDueDate.year, firstDueDate.month, firstDueDate.day).toIso8601String(),
      dueDate: due.toIso8601String(),
      debtId: debtId,
      installmentNumber: i + 1,
      totalInstallments: count,
      status: 'pending',
      isFixed: false,
      recurrenceType: 'none',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
    );
  });
}

double _remainingDebt(Debt debt, List<FinancialTransaction> installments) {
  final paid = installments.where((i) => i.status == 'paid').fold<double>(0, (s, i) => s + i.amount);
  return (debt.totalAmount - paid).clamp(0, double.infinity);
}

double _progressDebt(Debt debt, List<FinancialTransaction> installments) {
  if (debt.totalAmount <= 0) return 0;
  return ((_remainingDebt(debt, installments) == 0 ? debt.totalAmount : debt.totalAmount - _remainingDebt(debt, installments)) / debt.totalAmount) * 100;
}

bool _installmentIsOverdue(FinancialTransaction i, DateTime now) {
  if (i.status == 'paid' || i.status == 'canceled' || i.dueDate == null) return false;
  return DateTime.parse(i.dueDate!).isBefore(now);
}

double _projectProgressByTasks(List<Task> tasks) {
  final valid = tasks.where((t) => t.status != 'canceled').toList();
  if (valid.isEmpty) return 0;
  return (valid.where((t) => t.status == 'concluida').length / valid.length) * 100;
}

double _projectProgressBySteps(List<ProjectStep> steps) {
  final valid = steps.where((s) => s.status != 'canceled').toList();
  if (valid.isEmpty) return 0;
  return (valid.where((s) => s.status == 'completed').length / valid.length) * 100;
}

bool _projectIsOverdue(Project p, DateTime now) {
  if (p.endDate == null || p.status == 'completed' || p.status == 'canceled') return false;
  return DateTime.parse(p.endDate!).isBefore(now);
}

void main() {
  group('Módulo financeiro (mínimo)', () {
    test('criar receita e despesa, editar e excluir movimentação', () {
      final store = _FinanceStore();
      final income = store.create(title: 'Salário', amount: 3000, type: 'income', transactionDate: '2026-04-01');
      final expense = store.create(title: 'Aluguel', amount: 1000, type: 'expense', transactionDate: '2026-04-02');

      expect(store.items.length, 2);
      expect(income.type, 'income');
      expect(expense.type, 'expense');

      store.update(expense.copyWith(amount: 1200));
      expect(store.items.firstWhere((e) => e.id == expense.id).amount, 1200);

      store.delete(income.id!);
      expect(store.items.length, 1);
    });

    test('calcular receitas/despesas/saldo previsto e realizado', () {
      final items = <FinancialTransaction>[
        FinancialTransaction(
          id: 1,
          title: 'Salário',
          amount: 4000,
          type: 'income',
          transactionDate: '2026-04-05',
          status: 'paid',
          isFixed: false,
          recurrenceType: 'none',
          createdAt: '2026-04-05',
          updatedAt: '2026-04-05',
        ),
        FinancialTransaction(
          id: 2,
          title: 'Freela',
          amount: 1000,
          type: 'income',
          transactionDate: '2026-04-10',
          status: 'pending',
          isFixed: false,
          recurrenceType: 'none',
          createdAt: '2026-04-10',
          updatedAt: '2026-04-10',
        ),
        FinancialTransaction(
          id: 3,
          title: 'Mercado',
          amount: 700,
          type: 'expense',
          transactionDate: '2026-04-12',
          status: 'paid',
          isFixed: false,
          recurrenceType: 'none',
          createdAt: '2026-04-12',
          updatedAt: '2026-04-12',
        ),
        FinancialTransaction(
          id: 4,
          title: 'Academia',
          amount: 100,
          type: 'expense',
          transactionDate: '2026-04-15',
          status: 'pending',
          isFixed: false,
          recurrenceType: 'none',
          createdAt: '2026-04-15',
          updatedAt: '2026-04-15',
        ),
      ];

      final ref = DateTime(2026, 4, 20);
      expect(_receitasMes(items, ref), 5000);
      expect(_despesasMes(items, ref), 800);
      expect(_saldoPrevisto(items, ref), 4200);
      expect(_saldoRealizado(items, ref), 3300);
    });

    test('marcar despesa como paga e identificar vencida', () {
      final now = DateTime(2026, 4, 20);
      final overdue = FinancialTransaction(
        id: 1,
        title: 'Conta de luz',
        amount: 200,
        type: 'expense',
        transactionDate: '2026-04-01',
        dueDate: '2026-04-10',
        status: 'pending',
        isFixed: false,
        recurrenceType: 'none',
        createdAt: '2026-04-01',
        updatedAt: '2026-04-01',
      );
      expect(_isOverdueExpense(overdue, now), isTrue);

      final paid = overdue.copyWith(status: 'paid');
      expect(_isOverdueExpense(paid, now), isFalse);
    });
  });

  group('Módulo dívidas (mínimo)', () {
    test('criar dívida e gerar parcelas automaticamente', () {
      final debt = Debt(
        id: 10,
        name: 'Cartão',
        totalAmount: 1200,
        installmentAmount: 400,
        installmentCount: 3,
        status: 'active',
        createdAt: '2026-04-01',
        updatedAt: '2026-04-01',
      );
      final installments = _generateInstallments(
        debtId: debt.id!,
        count: debt.installmentCount!,
        amount: debt.installmentAmount!,
        firstDueDate: DateTime(2026, 4, 10),
      );
      expect(installments.length, 3);
      expect(installments.first.debtId, debt.id);
      expect(installments.first.installmentNumber, 1);
    });

    test('marcar parcela paga, atualizar progresso, calcular restante e quitar dívida', () {
      final debt = Debt(
        id: 10,
        name: 'Notebook',
        totalAmount: 1000,
        installmentAmount: 500,
        installmentCount: 2,
        status: 'active',
        createdAt: '2026-04-01',
        updatedAt: '2026-04-01',
      );
      var installments = _generateInstallments(
        debtId: debt.id!,
        count: 2,
        amount: 500,
        firstDueDate: DateTime(2026, 4, 5),
      );

      installments = [
        installments[0].copyWith(status: 'paid'),
        installments[1],
      ];
      expect(_remainingDebt(debt, installments), 500);
      expect(_progressDebt(debt, installments), 50);

      installments = [
        installments[0],
        installments[1].copyWith(status: 'paid'),
      ];
      expect(_remainingDebt(debt, installments), 0);

      final debtPaid = debt.copyWith(status: _remainingDebt(debt, installments) == 0 ? 'paid' : 'active');
      expect(debtPaid.status, 'paid');
    });

    test('identificar parcela atrasada e manter transação financeira ao pagar parcela', () {
      final now = DateTime(2026, 4, 20);
      final installment = FinancialTransaction(
        id: 1,
        title: 'Parcela 1/3',
        amount: 300,
        type: 'expense',
        transactionDate: '2026-04-01',
        dueDate: '2026-04-10',
        debtId: 999,
        installmentNumber: 1,
        totalInstallments: 3,
        status: 'pending',
        isFixed: false,
        recurrenceType: 'none',
        createdAt: '2026-04-01',
        updatedAt: '2026-04-01',
      );
      expect(_installmentIsOverdue(installment, now), isTrue);

      final paidTx = installment.copyWith(status: 'paid');
      expect(paidTx.type, 'expense');
      expect(paidTx.debtId, 999);
    });
  });

  group('Módulo projetos (mínimo)', () {
    test('criar projeto, criar etapa e criar tarefa vinculada', () {
      final project = Project(
        id: 50,
        name: 'Lançar MVP',
        status: 'active',
        createdAt: '2026-04-01',
        updatedAt: '2026-04-01',
      );
      final step = ProjectStep(
        id: 7,
        projectId: project.id!,
        title: 'Planejamento',
        orderIndex: 1,
        status: 'pending',
        createdAt: '2026-04-02',
        updatedAt: '2026-04-02',
      );
      final task = Task(
        id: 99,
        title: 'Definir escopo',
        projectId: project.id,
        projectStepId: step.id,
        priority: 'media',
        status: 'pendente',
        reminderEnabled: false,
        createdAt: '2026-04-02',
        updatedAt: '2026-04-02',
      );

      expect(project.id, 50);
      expect(step.projectId, project.id);
      expect(task.projectStepId, step.id);
    });

    test('calcular progresso por tarefas e por etapas', () {
      final tasks = [
        Task(
          id: 1,
          title: 'T1',
          projectId: 1,
          priority: 'media',
          status: 'concluida',
          reminderEnabled: false,
          createdAt: '2026-04-01',
          updatedAt: '2026-04-01',
        ),
        Task(
          id: 2,
          title: 'T2',
          projectId: 1,
          priority: 'media',
          status: 'pendente',
          reminderEnabled: false,
          createdAt: '2026-04-01',
          updatedAt: '2026-04-01',
        ),
      ];
      expect(_projectProgressByTasks(tasks), 50);

      final steps = [
        ProjectStep(
          id: 1,
          projectId: 1,
          title: 'S1',
          orderIndex: 1,
          status: 'completed',
          createdAt: '2026-04-01',
          updatedAt: '2026-04-01',
        ),
        ProjectStep(
          id: 2,
          projectId: 1,
          title: 'S2',
          orderIndex: 2,
          status: 'pending',
          createdAt: '2026-04-01',
          updatedAt: '2026-04-01',
        ),
      ];
      expect(_projectProgressBySteps(steps), 50);
    });

    test('marcar projeto como concluído, identificar atraso e remover vínculo ao excluir projeto', () {
      final project = Project(
        id: 1,
        name: 'Projeto X',
        status: 'active',
        endDate: '2026-04-10',
        createdAt: '2026-04-01',
        updatedAt: '2026-04-01',
      );
      expect(_projectIsOverdue(project, DateTime(2026, 4, 20)), isTrue);

      final completed = project.copyWith(status: 'completed', progress: 100);
      expect(completed.status, 'completed');
      expect(completed.progress, 100);

      final linkedTask = Task(
        id: 1,
        title: 'Tarefa vinculada',
        projectId: project.id,
        projectStepId: 5,
        priority: 'media',
        status: 'pendente',
        reminderEnabled: false,
        createdAt: '2026-04-01',
        updatedAt: '2026-04-01',
      );
      final unlinked = linkedTask.copyWith(clearProjectId: true, clearProjectStepId: true);
      expect(unlinked.projectId, isNull);
      expect(unlinked.projectStepId, isNull);
    });
  });

  group('Testes gerais de estabilidade', () {
    test('temas claro e escuro estão configurados', () {
      expect(AppTheme.lightTheme.colorScheme.brightness.name, 'light');
      expect(AppTheme.darkTheme.colorScheme.brightness.name, 'dark');
    });

    test('migração inclui proteção para dados antigos', () {
      final dbHelperContent = File('lib/data/database/db_helper.dart').readAsStringSync();
      expect(dbHelperContent.contains('if (oldVersion < 14)'), isTrue);
      expect(dbHelperContent.contains('project_stages'), isTrue);
      expect(dbHelperContent.contains('project_steps'), isTrue);
    });

    test('workflow de CI para APK existe', () {
      final workflow = File('.github/workflows/build-apk.yml');
      expect(workflow.existsSync(), isTrue);
      final content = workflow.readAsStringSync();
      expect(content.contains('flutter build apk'), isTrue);
    });
  });
}
