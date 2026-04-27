import 'dart:io';

void main() {
  final file = File('lib/features/finance/finance_planning_screen.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }

  var text = file.readAsStringSync();

  if (!text.contains('void _disposeControllersAfterDialog(List<TextEditingController> controllers)')) {
    const anchor = '''  Future<void> _setDefaultAccount(int? accountId) async {
    await ref.read(appSettingsProvider.notifier).setValue(defaultFinancialAccountSettingKey, accountId?.toString() ?? '');
    if (!mounted) return;
    setState(() => _defaultAccountId = accountId);
  }
''';

    const helper = '''  Future<void> _setDefaultAccount(int? accountId) async {
    await ref.read(appSettingsProvider.notifier).setValue(defaultFinancialAccountSettingKey, accountId?.toString() ?? '');
    if (!mounted) return;
    setState(() => _defaultAccountId = accountId);
  }

  void _disposeControllersAfterDialog(List<TextEditingController> controllers) {
    Future<void>.delayed(const Duration(milliseconds: 450), () {
      for (final controller in controllers) {
        controller.dispose();
      }
    });
  }
''';

    if (!text.contains(anchor)) {
      stderr.writeln('Âncora para inserir helper não encontrada.');
      exit(1);
    }
    text = text.replaceFirst(anchor, helper);
  }

  final replacements = <String, String>{
    '''    nameController.dispose();
    balanceController.dispose();''': '''    _disposeControllersAfterDialog([nameController, balanceController]);''',
    '''    nameController.dispose();
    limitController.dispose();
    monthController.dispose();''': '''    _disposeControllersAfterDialog([nameController, limitController, monthController]);''',
    '''    nameController.dispose();
    descriptionController.dispose();
    targetController.dispose();
    currentController.dispose();''': '''    _disposeControllersAfterDialog([nameController, descriptionController, targetController, currentController]);''',
    '''    controller.dispose();''': '''    _disposeControllersAfterDialog([controller]);''',
  };

  var changed = false;
  for (final entry in replacements.entries) {
    if (text.contains(entry.key)) {
      text = text.replaceAll(entry.key, entry.value);
      changed = true;
    }
  }

  file.writeAsStringSync(text);
  stdout.writeln(changed ? 'finance_planning_screen.dart corrigido.' : 'Nenhum dispose imediato restante encontrado.');
}
