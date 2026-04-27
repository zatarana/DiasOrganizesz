import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:diasorganize/data/database/db_helper.dart';
import 'package:diasorganize/data/models/debt_model.dart';
import 'package:diasorganize/data/models/financial_account_model.dart';
import 'package:diasorganize/data/models/financial_goal_model.dart';
import 'package:diasorganize/data/models/project_model.dart';
import 'package:diasorganize/data/models/project_step_model.dart';
import 'package:diasorganize/data/models/task_model.dart';
import 'package:diasorganize/data/models/transaction_model.dart';

DateTime? _taskDueDateTime(Task task) {
  final date = DateTime.tryParse(task.date ?? '');
  if (date == null) return null;
  if (task.time == null) return DateTime(date.year, date.month, date.day, 23, 59, 59);
  final parts = task.time!.split(':');
  if (parts.length != 2) return DateTime(date.year, date.month, date.day, 23, 59, 59);
  return DateTime(date.year, date.month, date.day, int.tryParse(parts[0]) ?? 23, int.tryParse(parts[1]) ?? 59);
}

DateTime? _nextRecurringDate(Task task) {
  final current = DateTime.tryParse(task.date ?? '');
  if (current == null || task.parentTaskId != null) return null;
  switch (task.recurrenceType) {
    case 'daily':
      return current.add(const Duration(days: 1));
    case 'weekly':
      return current.add(const Duration(days: 7));
    case 'monthly':
      return DateTime(current.year, current.month + 1, current.day);
    default:
      return null;
  }
}

double _accountBalanceAfterTransactions(FinancialAccount account, List<FinancialTransaction> transactions) {
  final delta = transactions.where((t) => t.status == 'paid' && t.accountId == account.id).fold<double>(0, (sum, transaction) {
    if (transaction.type == 'income') return sum + transaction.amount;
    if (transaction.type == 'expense') return sum - transaction.amount;
    return sum;
  });
  return account.initialBalance + delta;
}

double _remainingDebt(Debt debt, List<FinancialTransaction> installments) {
  final paid = installments.where((t) => t.status == 'paid' && t.debtId == debt.id).fold<double>(0, (sum, t) => sum + t.amount + (t.discountAmount ?? 0));
  return (debt.totalAmount - paid).clamp(0, double.infinity).toDouble();
}

double _projectProgress(List<Task> tasks) {
  final valid = tasks.where((task) => task.status != 'canceled' && task.parentTaskId == null).toList();
  if (valid.isEmpty) return 0;
  return (valid.where((task) => task.status == 'concluida').length / valid.length) * 100;
}

void main() {
  group('Database/versioning', () {
    test('schema version is centralized and current', () {
      expect(DatabaseHelper.schemaVersion, 16);
    });

    test('backup metadata can reference the database schema version', () {
      final payload = jsonEncode({
        'app': 'DiasOrganize',
        'backupFormatVersion': 2,
        'databaseVersion': DatabaseHelper.schemaVersion,
        'tables': <String, Object?>{},
      });

      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      expect(decoded['databaseVersion'], DatabaseHelper.schemaVersion);
      expect(decoded['databaseVersion'], 16);
    });
  });

  group('Tasks', () {
    test('serializes recurrence and subtask fields', () {
      final task = Task(
        id: 1,
        title: 'Revisar edital',
        parentTaskId: 99,
        recurrenceType: 'weekly',
        priority: 'alta',
        date: '2026-04-27',
        time: '08:30',
        status: 'pendente',
        reminderEnabled: true,
        createdAt: '2026-04-26',
        updatedAt: '2026-04-26',
      );

      final restored = Task.fromMap(task.toMap());
      expect(restored.parentTaskId, 99);
      expect(restored.recurrenceType, 'weekly');
      expect(restored.time, '08:30');
    });

    test('calculates next recurrence only for parent recurring tasks', () {
      final daily = Task(title: 'Beber água', priority: 'media', date: '2026-04-27', status: 'concluida', reminderEnabled: false, recurrenceType: 'daily', createdAt: '2026-04-27', updatedAt: '2026-04-27');
      final weekly = daily.copyWith(recurrenceType: 'weekly');
      final monthly = daily.copyWith(recurrenceType: 'monthly');
      final subtask = daily.copyWith(parentTaskId: 7);

      expect(_nextRecurringDate(daily), DateTime(2026, 4, 28));
      expect(_nextRecurringDate(weekly), DateTime(2026, 5, 4));
      expect(_nextRecurringDate(monthly), DateTime(2026, 5, 27));
      expect(_nextRecurringDate(subtask), isNull);
    });

    test('detects overdue task based on date and time', () {
      final task = Task(title: 'Pagar conta', priority: 'alta', date: '2026-04-20', time: '10:00', status: 'pendente', reminderEnabled: false, createdAt: '2026-04-20', updatedAt: '2026-04-20');
      final due = _taskDueDateTime(task);
      expect(due, DateTime(2026, 4, 20, 10, 0));
      expect(due!.isBefore(DateTime(2026, 4, 20, 11, 0)), isTrue);
    });
  });

  group('Finance/accounts', () {
    test('real account balance comes from accounts plus paid transaction deltas only once', () {
      final account = FinancialAccount(id: 1, name: 'Carteira', type: 'wallet', initialBalance: 1000, currentBalance: 1000, createdAt: '2026-04-01', updatedAt: '2026-04-01');
      final transactions = [
        FinancialTransaction(title: 'Salário', amount: 500, type: 'income', transactionDate: '2026-04-02', accountId: 1, status: 'paid', isFixed: false, recurrenceType: 'none', createdAt: '2026-04-02', updatedAt: '2026-04-02'),
        FinancialTransaction(title: 'Mercado', amount: 150, type: 'expense', transactionDate: '2026-04-03', accountId: 1, status: 'paid', isFixed: false, recurrenceType: 'none', createdAt: '2026-04-03', updatedAt: '2026-04-03'),
        FinancialTransaction(title: 'Prevista', amount: 200, type: 'income', transactionDate: '2026-04-04', accountId: 1, status: 'pending', isFixed: false, recurrenceType: 'none', createdAt: '2026-04-04', updatedAt: '2026-04-04'),
      ];

      expect(_accountBalanceAfterTransactions(account, transactions), 1350);
    });

    test('financial goal keeps optional linked account', () {
      final goal = FinancialGoal(name: 'Reserva', targetAmount: 10000, currentAmount: 1500, accountId: 1, status: 'active', createdAt: '2026-04-01', updatedAt: '2026-04-01');
      final restored = FinancialGoal.fromMap(goal.toMap());
      expect(restored.accountId, 1);
      expect(restored.currentAmount, 1500);
    });
  });

  group('Debts', () {
    test('paid installments reduce remaining debt and discount counts as reduction', () {
      final debt = Debt(id: 10, name: 'Notebook', totalAmount: 1200, installmentCount: 3, installmentAmount: 400, status: 'active', createdAt: '2026-04-01', updatedAt: '2026-04-01');
      final installments = [
        FinancialTransaction(title: 'Parcela 1', amount: 400, type: 'expense', transactionDate: '2026-04-10', debtId: 10, status: 'paid', discountAmount: 20, isFixed: false, recurrenceType: 'none', createdAt: '2026-04-10', updatedAt: '2026-04-10'),
        FinancialTransaction(title: 'Parcela 2', amount: 400, type: 'expense', transactionDate: '2026-05-10', debtId: 10, status: 'pending', isFixed: false, recurrenceType: 'none', createdAt: '2026-05-10', updatedAt: '2026-05-10'),
      ];

      expect(_remainingDebt(debt, installments), 780);
    });

    test('debt becomes paid when paid installments cover total amount', () {
      final debt = Debt(id: 11, name: 'Curso', totalAmount: 800, installmentCount: 2, installmentAmount: 400, status: 'active', createdAt: '2026-04-01', updatedAt: '2026-04-01');
      final installments = [
        FinancialTransaction(title: 'Parcela 1', amount: 400, type: 'expense', transactionDate: '2026-04-10', debtId: 11, status: 'paid', isFixed: false, recurrenceType: 'none', createdAt: '2026-04-10', updatedAt: '2026-04-10'),
        FinancialTransaction(title: 'Parcela 2', amount: 400, type: 'expense', transactionDate: '2026-05-10', debtId: 11, status: 'paid', isFixed: false, recurrenceType: 'none', createdAt: '2026-05-10', updatedAt: '2026-05-10'),
      ];

      final status = _remainingDebt(debt, installments) <= 0 ? 'paid' : 'active';
      expect(status, 'paid');
    });
  });

  group('Projects', () {
    test('project sessions are task lists through projectStepId', () {
      final project = Project(id: 1, name: 'App', status: 'active', createdAt: '2026-04-01', updatedAt: '2026-04-01');
      final session = ProjectStep(id: 2, projectId: 1, title: 'Fazer', orderIndex: 0, status: 'pending', createdAt: '2026-04-01', updatedAt: '2026-04-01');
      final task = Task(title: 'Criar tela', projectId: project.id, projectStepId: session.id, priority: 'media', status: 'pendente', reminderEnabled: false, createdAt: '2026-04-01', updatedAt: '2026-04-01');

      expect(session.projectId, project.id);
      expect(task.projectStepId, session.id);
    });

    test('project progress ignores subtasks and canceled tasks', () {
      final tasks = [
        Task(title: 'Principal concluída', projectId: 1, priority: 'media', status: 'concluida', reminderEnabled: false, createdAt: '2026-04-01', updatedAt: '2026-04-01'),
        Task(title: 'Principal pendente', projectId: 1, priority: 'media', status: 'pendente', reminderEnabled: false, createdAt: '2026-04-01', updatedAt: '2026-04-01'),
        Task(title: 'Subtarefa', parentTaskId: 99, projectId: 1, priority: 'media', status: 'pendente', reminderEnabled: false, createdAt: '2026-04-01', updatedAt: '2026-04-01'),
        Task(title: 'Cancelada', projectId: 1, priority: 'media', status: 'canceled', reminderEnabled: false, createdAt: '2026-04-01', updatedAt: '2026-04-01'),
      ];

      expect(_projectProgress(tasks), 50);
    });
  });
}
