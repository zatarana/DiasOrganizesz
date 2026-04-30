import 'dart:io';

void main() {
  _patchProvidersTransactions();
  _patchQuickTransactionSheet();
  _patchCreateTransactionScreen();
  _validate();
  stdout.writeln('Salvamento de inputs blindado contra loading infinito.');
}

void _patchProvidersTransactions() {
  final file = File('lib/domain/providers.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }

  var text = file.readAsStringSync();
  if (!text.startsWith("import 'dart:async';")) {
    text = "import 'dart:async';\n$text";
  }

  final start = text.indexOf('class TransactionNotifier extends StateNotifier<List<FinancialTransaction>> {');
  final end = text.indexOf('final financialCategoriesProvider =', start);
  if (start == -1 || end == -1) {
    stderr.writeln('ERRO: não foi possível localizar TransactionNotifier para patch.');
    exit(1);
  }

  text = text.replaceRange(start, end, _transactionNotifierClass());
  file.writeAsStringSync(text);
}

String _transactionNotifierClass() => r'''
class TransactionNotifier extends StateNotifier<List<FinancialTransaction>> {
  final DatabaseHelper db;
  final Ref ref;
  TransactionNotifier(this.db, this.ref) : super([]) {
    loadTransactions();
  }

  bool _isOverdue(FinancialTransaction transaction) {
    if (transaction.status != 'pending') return false;
    final rawDate = transaction.dueDate ?? transaction.transactionDate;
    final date = DateTime.tryParse(rawDate);
    if (date == null) return false;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final due = DateTime(date.year, date.month, date.day);
    return due.isBefore(today);
  }

  Future<void> loadTransactions() async {
    final transactions = await db.getTransactions();
    final updatedTransactions = <FinancialTransaction>[];
    final affectedDebtIds = <int>{};

    for (final transaction in transactions) {
      if (_isOverdue(transaction)) {
        final updated = transaction.copyWith(status: 'overdue', updatedAt: DateTime.now().toIso8601String());
        await db.updateTransaction(updated);
        updatedTransactions.add(updated);
        if (updated.debtId != null) affectedDebtIds.add(updated.debtId!);
      } else {
        updatedTransactions.add(transaction);
        if (transaction.debtId != null) affectedDebtIds.add(transaction.debtId!);
      }
    }

    state = updatedTransactions;
    for (final debtId in affectedDebtIds) {
      await _checkDebtStatus(debtId);
    }
  }

  Future<void> addTransaction(FinancialTransaction transaction) async {
    final newTransaction = await db.createTransaction(transaction).timeout(const Duration(seconds: 10));
    state = [newTransaction, ...state];
    _syncTransactionReminderSafely(newTransaction);
    _checkDebtStatusSafely(newTransaction.debtId);
    ref.invalidate(realAccountBalanceProvider);
  }

  Future<void> updateTransaction(FinancialTransaction transaction) async {
    final previous = state.where((t) => t.id == transaction.id).cast<FinancialTransaction?>().firstOrNull;
    await db.updateTransaction(transaction).timeout(const Duration(seconds: 10));
    state = [for (final t in state) if (t.id == transaction.id) transaction else t];
    _syncTransactionReminderSafely(transaction);

    final affectedDebtIds = <int>{};
    if (previous?.debtId != null) affectedDebtIds.add(previous!.debtId!);
    if (transaction.debtId != null) affectedDebtIds.add(transaction.debtId!);
    for (final debtId in affectedDebtIds) {
      _checkDebtStatusSafely(debtId);
    }
    ref.invalidate(realAccountBalanceProvider);
  }

  Future<void> removeTransaction(int id) async {
    final transaction = state.where((t) => t.id == id).cast<FinancialTransaction?>().firstOrNull;
    await db.deleteTransaction(id).timeout(const Duration(seconds: 10));
    state = state.where((t) => t.id != id).toList();
    unawaited(NotificationService().cancelNotification(NotificationService().transactionReminderId(id)).catchError((error, stack) {
      debugPrint('Falha ao cancelar lembrete de transação: $error');
    }));
    _checkDebtStatusSafely(transaction?.debtId);
    ref.invalidate(realAccountBalanceProvider);
  }

  Future<void> clearCanceledTransactions() async {
    final canceled = state.where((t) => t.status == 'canceled').toList();
    final affectedDebtIds = canceled.where((t) => t.debtId != null).map((t) => t.debtId!).toSet();
    for (final t in canceled) {
      if (t.id == null) continue;
      await db.deleteTransaction(t.id!).timeout(const Duration(seconds: 10));
      unawaited(NotificationService().cancelNotification(NotificationService().transactionReminderId(t.id!)).catchError((error, stack) {
        debugPrint('Falha ao cancelar lembrete de transação cancelada: $error');
      }));
    }
    state = state.where((t) => t.status != 'canceled').toList();
    for (final debtId in affectedDebtIds) {
      _checkDebtStatusSafely(debtId);
    }
    ref.invalidate(realAccountBalanceProvider);
  }

  void _syncTransactionReminderSafely(FinancialTransaction t) {
    final settings = ref.read(appSettingsProvider);
    final daysBefore = int.tryParse(settings[AppSettingKeys.debtsReminderDaysBefore] ?? '0') ?? 0;
    unawaited(NotificationService()
        .syncTransactionReminder(t, debtsReminderDaysBefore: daysBefore)
        .timeout(const Duration(seconds: 4))
        .catchError((error, stack) {
      debugPrint('Falha ao sincronizar lembrete de transação: $error');
    }));
  }

  void _checkDebtStatusSafely(int? debtId) {
    if (debtId == null) return;
    unawaited(_checkDebtStatus(debtId).timeout(const Duration(seconds: 6)).catchError((error, stack) {
      debugPrint('Falha ao sincronizar status da dívida: $error');
    }));
  }

  Future<void> _checkDebtStatus(int? debtId) async {
    if (debtId == null) return;

    final debts = ref.read(debtsProvider);
    final idx = debts.indexWhere((d) => d.id == debtId);
    if (idx == -1) return;

    final debt = debts[idx];
    if (debt.status == 'canceled' || debt.status == 'paused') return;

    final debtTransactions = state.where((t) => t.debtId == debtId && t.status != 'canceled').toList();
    if (debtTransactions.isEmpty) {
      if (debt.status == 'paid' || debt.status == 'overdue') {
        await ref.read(debtsProvider.notifier).updateDebt(debt.copyWith(status: 'active', updatedAt: DateTime.now().toIso8601String()));
      }
      return;
    }

    final totalAbatido = debtTransactions.where((t) => t.status == 'paid').fold<double>(0, (sum, transaction) => sum + transaction.amount + (transaction.discountAmount ?? 0));
    final isFullyPaidByValue = totalAbatido + 0.01 >= debt.totalAmount;
    final hasOverdue = debtTransactions.any((t) => t.status == 'overdue');

    String newStatus;
    if (isFullyPaidByValue) {
      newStatus = 'paid';
    } else if (hasOverdue) {
      newStatus = 'overdue';
    } else {
      newStatus = 'active';
    }

    if (newStatus != debt.status) {
      await ref.read(debtsProvider.notifier).updateDebt(debt.copyWith(status: newStatus, updatedAt: DateTime.now().toIso8601String()));
    }
  }
}

''';

void _patchQuickTransactionSheet() {
  final file = File('lib/features/finance/widgets/quick_transaction_bottom_sheet.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }

  var text = file.readAsStringSync();
  if (!text.startsWith("import 'dart:async';")) {
    text = "import 'dart:async';\n$text";
  }

  final start = text.indexOf('  Future<void> _save() async {');
  final end = text.indexOf('\n  void _openFullForm()', start);
  if (start == -1 || end == -1) {
    stderr.writeln('ERRO: não foi possível localizar _save do lançamento rápido.');
    exit(1);
  }

  text = text.replaceRange(start, end, r'''  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = MoneyFormatter.parse(_amountController.text);
    if (amount == null || amount <= 0) return;

    setState(() => _isSaving = true);
    try {
      final now = DateTime.now().toIso8601String();
      final transaction = FinancialTransaction(
        title: _titleController.text.trim(),
        amount: amount,
        type: _type,
        transactionDate: now,
        dueDate: now,
        paidDate: now,
        categoryId: _categoryId,
        status: 'paid',
        paymentMethod: 'Lançamento rápido',
        createdAt: now,
        updatedAt: now,
      );
      await ref.read(transactionsProvider.notifier).addTransaction(transaction).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lançamento rápido salvo.')));
      Navigator.pop(context, true);
    } on TimeoutException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O salvamento demorou demais. Tente novamente.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível salvar: $error')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
''');

  text = text.replaceAll(
    "  void _openFullForm() {\n    Navigator.pop(context, false);\n    Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateTransactionScreen()));\n  }",
    "  void _openFullForm() {\n    final navigator = Navigator.of(context);\n    navigator.pop(false);\n    Future.microtask(() => navigator.push(MaterialPageRoute(builder: (_) => const CreateTransactionScreen())));\n  }",
  );

  file.writeAsStringSync(text);
}

void _patchCreateTransactionScreen() {
  final file = File('lib/features/finance/create_transaction_screen.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }

  var text = file.readAsStringSync();
  if (!text.startsWith("import 'dart:async';")) {
    text = "import 'dart:async';\n$text";
  }

  text = text.replaceAll(
    'await ref.read(transactionsProvider.notifier).updateTransaction(transaction);',
    'await ref.read(transactionsProvider.notifier).updateTransaction(transaction).timeout(const Duration(seconds: 10));',
  );
  text = text.replaceAll(
    'await ref.read(transactionsProvider.notifier).addTransaction(transaction);',
    'await ref.read(transactionsProvider.notifier).addTransaction(transaction).timeout(const Duration(seconds: 10));',
  );

  if (!text.contains('Não foi possível salvar a movimentação')) {
    text = text.replaceFirst(
      '      if (mounted) Navigator.pop(context);\n    } finally {',
      r'''      if (mounted) Navigator.pop(context);
    } on TimeoutException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('O salvamento demorou demais. Tente novamente.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não foi possível salvar a movimentação: $error')));
      }
    } finally {''',
    );
  }

  file.writeAsStringSync(text);
}

void _validate() {
  final providers = File('lib/domain/providers.dart').readAsStringSync();
  final quick = File('lib/features/finance/widgets/quick_transaction_bottom_sheet.dart').readAsStringSync();
  final full = File('lib/features/finance/create_transaction_screen.dart').readAsStringSync();

  final required = <String>[
    "import 'dart:async';",
    'db.createTransaction(transaction).timeout(const Duration(seconds: 10))',
    '_syncTransactionReminderSafely(newTransaction);',
    '_checkDebtStatusSafely(newTransaction.debtId);',
    'finally {\n      if (mounted) setState(() => _isSaving = false);',
    'Não foi possível salvar:',
    'Não foi possível salvar a movimentação',
    'Future.microtask(() => navigator.push',
  ];

  final combined = '$providers\n$quick\n$full';
  for (final check in required) {
    if (!combined.contains(check)) {
      stderr.writeln('ERRO salvamento inputs: faltou requisito obrigatório.');
      exit(1);
    }
  }
}
