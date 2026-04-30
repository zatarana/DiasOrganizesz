import 'dart:io';

void main() {
  _fixHome();
  _fixReports();
  _fixQuickTransaction();
  _fixTasksEntry();
  _fixSavePatcher();
  _fixTransactionSchema();
  _fixPlanningCards();
  _fixFinanceDashboardPlanningRefresh();
  stdout.writeln('Correções finais pré-analyzer aplicadas.');
}

void _fixHome() {
  final file = File('lib/features/dashboard/home_screen.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();
  text = text.replaceAll("import 'package:intl/intl.dart';\n", '');
  text = text.replaceAll(
    'floatingActionButton: const UniversalQuickActionButton(),',
    'floatingActionButton: _currentIndex == 0 ? const UniversalQuickActionButton() : null,',
  );
  final lines = text.split('\n');
  text = lines.where((line) => !line.trim().startsWith('onLongPress: () => _showUniversalActions(context),')).join('\n');

  if (text.contains('final _homeExtraDataProvider = FutureProvider<_HomeExtraData>((ref) async {') &&
      !text.contains('ref.watch(transactionsProvider);\n  final db = await ref.watch(dbProvider).database;')) {
    text = text.replaceFirst(
      'final _homeExtraDataProvider = FutureProvider<_HomeExtraData>((ref) async {\n  final db = await ref.watch(dbProvider).database;',
      'final _homeExtraDataProvider = FutureProvider<_HomeExtraData>((ref) async {\n  ref.watch(transactionsProvider);\n  final db = await ref.watch(dbProvider).database;',
    );
  }
  if (text.contains('final balance = await FinancePlanningStore.getActiveAccountsBalance(db);') &&
      !text.contains('await FinancePlanningStore.recalculateAllAccountBalances(db);')) {
    text = text.replaceFirst(
      'final balance = await FinancePlanningStore.getActiveAccountsBalance(db);',
      'await FinancePlanningStore.recalculateAllAccountBalances(db);\n  final balance = await FinancePlanningStore.getActiveAccountsBalance(db);',
    );
  }

  if (text.contains('onLongPress: () => _showUniversalActions(context),')) {
    stderr.writeln('ERRO: onLongPress inválido no FloatingActionButton.');
    exit(1);
  }
  file.writeAsStringSync(text);
}

void _fixReports() {
  final file = File('lib/features/finance/finance_reports_screen.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();
  if (!text.contains("import 'dart:ui' as ui;")) {
    text = "import 'dart:ui' as ui;\n$text";
  }
  text = text.replaceAll('TextDirection.ltr', 'ui.TextDirection.ltr');
  while (text.contains('ui.ui.TextDirection.ltr')) {
    text = text.replaceAll('ui.ui.TextDirection.ltr', 'ui.TextDirection.ltr');
  }
  file.writeAsStringSync(text);
}

void _fixQuickTransaction() {
  final file = File('lib/features/finance/widgets/quick_transaction_bottom_sheet.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();
  text = text.replaceAll('inputFormatters: const [', 'inputFormatters: [');
  text = text.replaceAll('children: const [', 'children: [');

  if (!text.contains("import '../../../data/database/finance_planning_store.dart';")) {
    text = text.replaceFirst(
      "import '../../../core/utils/money_formatter.dart';",
      "import '../../../core/utils/money_formatter.dart';\nimport '../../../data/database/finance_planning_store.dart';",
    );
  }
  if (!text.contains("import '../../../data/models/financial_account_model.dart';")) {
    text = text.replaceFirst(
      "import '../../../data/models/financial_category_model.dart';",
      "import '../../../data/models/financial_account_model.dart';\nimport '../../../data/models/financial_category_model.dart';",
    );
  }

  if (!text.contains('List<FinancialAccount> _accounts = [];')) {
    text = text.replaceFirst(
      '  int? _categoryId;\n  bool _isSaving = false;',
      '  int? _categoryId;\n  int? _accountId;\n  bool _loadingAccounts = true;\n  bool _isSaving = false;\n  List<FinancialAccount> _accounts = [];',
    );
  }

  if (!text.contains('Future<void> _loadAccounts() async')) {
    text = text.replaceFirst(
      '  @override\n  void dispose() {',
      '''  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    final dbHelper = ref.read(dbProvider);
    final db = await dbHelper.database;
    final accounts = await FinancePlanningStore.getAccounts(db, recalculateBeforeRead: true);
    final defaultSetting = await dbHelper.getSetting(defaultFinancialAccountSettingKey);
    final defaultAccountId = int.tryParse(defaultSetting?.value ?? '');
    final activeAccounts = accounts.where((account) => !account.isArchived).toList();
    int? selectedAccountId;
    if (defaultAccountId != null && activeAccounts.any((account) => account.id == defaultAccountId)) {
      selectedAccountId = defaultAccountId;
    } else if (activeAccounts.isNotEmpty) {
      selectedAccountId = activeAccounts.first.id;
    }
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _accountId = selectedAccountId;
      _loadingAccounts = false;
    });
  }

  List<FinancialAccount> _selectableQuickAccounts() {
    return _accounts.where((account) => !account.isArchived).toList();
  }

  @override
  void dispose() {''',
    );
  }

  text = text.replaceAll(
    'Valor, título e categoria. Para parcelas, contas e recorrência, use Mais detalhes.',
    'Valor, título, categoria e conta. Para parcelas e recorrência, use Mais detalhes.',
  );

  if (!text.contains('final safeAccountId = _selectableQuickAccounts().any((account) => account.id == _accountId) ? _accountId : null;')) {
    text = text.replaceFirst(
      '    if (amount == null || amount <= 0) return;\n\n    setState(() => _isSaving = true);',
      '''    if (amount == null || amount <= 0) return;

    final safeAccountId = _selectableQuickAccounts().any((account) => account.id == _accountId) ? _accountId : null;
    if (_loadingAccounts) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aguarde o carregamento das contas.')));
      return;
    }
    if (safeAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione ou cadastre uma conta para atualizar o saldo.')));
      return;
    }

    setState(() => _isSaving = true);''',
    );
  }

  if (!text.contains('accountId: safeAccountId,')) {
    text = text.replaceFirst(
      "        categoryId: _categoryId,\n        status: 'paid',",
      "        categoryId: _categoryId,\n        accountId: safeAccountId,\n        status: 'paid',",
    );
  }

  if (!text.contains('final accounts = _selectableQuickAccounts();')) {
    text = text.replaceFirst(
      '    final categories = _categoriesForType(ref.watch(financialCategoriesProvider));\n    if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) _categoryId = null;',
      '    final categories = _categoriesForType(ref.watch(financialCategoriesProvider));\n    final accounts = _selectableQuickAccounts();\n    final safeAccountId = accounts.any((account) => account.id == _accountId) ? _accountId : null;\n    if (_categoryId != null && !categories.any((c) => c.id == _categoryId)) _categoryId = null;',
    );
  }

  if (!text.contains("labelText: 'Conta'")) {
    text = text.replaceFirst(
      '''              DropdownButtonFormField<int?>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.category_outlined), border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Sem categoria')),
                  ...categories.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                ],
                onChanged: _isSaving ? null : (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 16),''',
      '''              DropdownButtonFormField<int?>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: 'Categoria', prefixIcon: Icon(Icons.category_outlined), border: OutlineInputBorder()),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Sem categoria')),
                  ...categories.map((c) => DropdownMenuItem<int?>(value: c.id, child: Text(c.name))),
                ],
                onChanged: _isSaving ? null : (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: safeAccountId,
                decoration: const InputDecoration(labelText: 'Conta', prefixIcon: Icon(Icons.account_balance_wallet_outlined), border: OutlineInputBorder()),
                items: [
                  if (accounts.isEmpty) const DropdownMenuItem<int?>(value: null, child: Text('Nenhuma conta cadastrada')),
                  ...accounts.map((account) => DropdownMenuItem<int?>(value: account.id, child: Text(account.name))),
                ],
                onChanged: _isSaving || _loadingAccounts ? null : (value) => setState(() => _accountId = value),
                validator: (_) => safeAccountId == null ? 'Selecione uma conta.' : null,
              ),
              const SizedBox(height: 16),''',
    );
  }

  for (final check in [
    "import '../../../data/database/finance_planning_store.dart';",
    "import '../../../data/models/financial_account_model.dart';",
    'Future<void> _loadAccounts() async',
    'List<FinancialAccount> _accounts = [];',
    'accountId: safeAccountId,',
    "labelText: 'Conta'",
    'Selecione ou cadastre uma conta para atualizar o saldo.',
  ]) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO: lançamento rápido sem vínculo de conta. Faltou: $check');
      exit(1);
    }
  }

  file.writeAsStringSync(text);
}

void _fixTasksEntry() {
  final file = File('lib/features/tasks/tasks_entry_screen.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();
  final slashN = String.fromCharCode(92) + 'n';

  // Evita que o Dart interprete "$slashNclass" como uma única variável
  // inexistente durante a execução do patch no GitHub Actions.
  text = text.replaceAll('}' + slashN + slashN + 'class _CompactSmartLists', '}\n\nclass _CompactSmartLists');
  text = text.replaceAll('}' + slashN + 'class _CompactSmartLists', '}\n\nclass _CompactSmartLists');
  text = text.replaceAll(slashN + 'class _CompactSmartLists', '\nclass _CompactSmartLists');
  file.writeAsStringSync(text);
}

void _fixSavePatcher() {
  final file = File('tool/patch_input_save_reliability.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();
  final marker = String.fromCharCode(36) + 'check';
  if (text.contains(marker)) {
    text = text.replaceAll(marker, 'requisito obrigatório');
  }
  file.writeAsStringSync(text);
}

void _fixTransactionSchema() {
  final file = File('lib/data/database/db_helper.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();

  text = text.replaceAll('static const int schemaVersion = 18;', 'static const int schemaVersion = 19;');

  const upgrade18 = '''    if (oldVersion < 18) {
      await _ensureTaskColumns(db);
    }
''';
  const upgrade19 = '''    if (oldVersion < 18) {
      await _ensureTaskColumns(db);
    }
    if (oldVersion < 19) {
      await _ensureFinancialTransactionColumns(db);
    }
''';
  if (!text.contains('if (oldVersion < 19)')) {
    text = text.replaceFirst(upgrade18, upgrade19);
  }

  const ensureAnchor = "    await _addColumnIfMissing(db, 'transactions', 'accountId INTEGER');\n";
  const ensureExtra = "    await _addColumnIfMissing(db, 'transactions', 'subcategoryId INTEGER');\n"
      "    await _addColumnIfMissing(db, 'transactions', 'creditCardId INTEGER');\n"
      "    await _addColumnIfMissing(db, 'transactions', 'creditCardInvoiceId INTEGER');\n"
      "    await _addColumnIfMissing(db, 'transactions', 'creditCardPaymentInvoiceId INTEGER');\n";
  if (!text.contains("_addColumnIfMissing(db, 'transactions', 'subcategoryId INTEGER')")) {
    text = text.replaceFirst(ensureAnchor, '$ensureAnchor$ensureExtra');
  }

  if (!text.contains('        subcategoryId INTEGER,')) {
    text = text.replaceFirst('        categoryId INTEGER,\n', '        categoryId INTEGER,\n        subcategoryId INTEGER,\n');
  }
  if (!text.contains('        creditCardId INTEGER,')) {
    text = text.replaceFirst(
      '        debtId INTEGER,\n        installmentNumber INTEGER,\n',
      '        debtId INTEGER,\n        creditCardId INTEGER,\n        creditCardInvoiceId INTEGER,\n        creditCardPaymentInvoiceId INTEGER,\n        installmentNumber INTEGER,\n',
    );
  }

  for (final check in [
    'static const int schemaVersion = 19;',
    "_addColumnIfMissing(db, 'transactions', 'subcategoryId INTEGER')",
    "_addColumnIfMissing(db, 'transactions', 'creditCardId INTEGER')",
    "_addColumnIfMissing(db, 'transactions', 'creditCardInvoiceId INTEGER')",
    "_addColumnIfMissing(db, 'transactions', 'creditCardPaymentInvoiceId INTEGER')",
    '        subcategoryId INTEGER,',
    '        creditCardId INTEGER,',
    '        creditCardInvoiceId INTEGER,',
    '        creditCardPaymentInvoiceId INTEGER,',
  ]) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO: schema de transações incompleto. Faltou: $check');
      exit(1);
    }
  }

  file.writeAsStringSync(text);
}

void _fixPlanningCards() {
  final file = File('lib/features/finance/finance_dashboard_planning.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();

  text = text.replaceAll('          height: 126,', '          height: 146,');
  text = text.replaceAll('        width: 205,', '        width: 198,');
  text = text.replaceAll('        child: Card(\n          elevation: 0,', '        child: Card(\n          margin: EdgeInsets.zero,\n          elevation: 0,');
  text = text.replaceAll('          child: Card(\n          elevation: 0,', '          child: Card(\n          margin: EdgeInsets.zero,\n          elevation: 0,');
  text = text.replaceAll('              padding: const EdgeInsets.all(14),\n              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n                CircleAvatar(backgroundColor: color.withValues(alpha: 0.12), child: Icon(Icons.account_balance_wallet_outlined, color: color)),\n                const Spacer(),', '              padding: const EdgeInsets.all(12),\n              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [\n                CircleAvatar(radius: 18, backgroundColor: color.withValues(alpha: 0.12), child: Icon(Icons.account_balance_wallet_outlined, color: color, size: 20)),\n                const SizedBox(height: 8),');
  text = text.replaceAll('style: TextStyle(color: color, fontWeight: FontWeight.w900)),\n              ])', 'style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 16)),\n              ])');

  for (final check in [
    'height: 146',
    'margin: EdgeInsets.zero',
    'CircleAvatar(radius: 18',
    'fontSize: 16',
  ]) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO: cards de contas ainda podem gerar overflow. Faltou: $check');
      exit(1);
    }
  }

  file.writeAsStringSync(text);
}

void _fixFinanceDashboardPlanningRefresh() {
  final file = File('lib/features/finance/finance_entry_screen.dart');
  if (!file.existsSync()) return;
  var text = file.readAsStringSync();

  if (text.contains('final _financeDashboardPlanningProvider = FutureProvider<_FinanceDashboardPlanningData>((ref) async {') &&
      !text.contains('ref.watch(transactionsProvider);\n  final db = await ref.watch(dbProvider).database;')) {
    text = text.replaceFirst(
      'final _financeDashboardPlanningProvider = FutureProvider<_FinanceDashboardPlanningData>((ref) async {\n  final db = await ref.watch(dbProvider).database;',
      'final _financeDashboardPlanningProvider = FutureProvider<_FinanceDashboardPlanningData>((ref) async {\n  ref.watch(transactionsProvider);\n  final db = await ref.watch(dbProvider).database;',
    );
  }

  if (text.contains('final _financeDashboardPlanningProvider = FutureProvider<_FinanceDashboardPlanningData>((ref) async {') &&
      !text.contains('ref.watch(transactionsProvider);')) {
    stderr.writeln('ERRO: dashboard financeiro não observa alterações de transações.');
    exit(1);
  }

  file.writeAsStringSync(text);
}
