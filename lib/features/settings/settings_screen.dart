import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/backup/backup_service.dart';
import '../../core/notifications/notification_service.dart';
import '../../data/database/finance_planning_store.dart';
import '../../domain/providers.dart';
import 'categories_screen.dart';
import '../finance/finance_categories_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  bool _settingBool(Map<String, String> settings, String key, {bool fallback = false}) {
    return (settings[key] ?? '$fallback') == 'true';
  }

  int _settingInt(Map<String, String> settings, String key, {int fallback = 0}) {
    return int.tryParse(settings[key] ?? '$fallback') ?? fallback;
  }

  Future<void> _resetCoreData(WidgetRef ref) async {
    await NotificationService().cancelAllNotifications();
    final dbHelper = ref.read(dbProvider);
    await dbHelper.resetCoreData();
    await FinancePlanningStore.resetPlanningData(await dbHelper.database);
    await ref.read(tasksProvider.notifier).loadTasks();
    await ref.read(transactionsProvider.notifier).loadTransactions();
    await ref.read(debtsProvider.notifier).loadDebts();
    await ref.read(projectsProvider.notifier).loadProjects();
    await ref.read(financialCategoriesProvider.notifier).loadCategories();
    ref.invalidate(allProjectStepsProvider);
  }

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      final path = await BackupService().exportJson(ref.read(dbProvider));
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Backup exportado'),
            content: SelectableText('Arquivo salvo em:\n$path'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro ao exportar backup: $error')));
      }
    }
  }

  Future<void> _confirmClearCanceledTransactions(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar movimentações canceladas?'),
        content: const Text('Isso removerá permanentemente transações com status cancelado. As dívidas vinculadas serão recalculadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(transactionsProvider.notifier).clearCanceledTransactions();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimentações canceladas removidas.')));
    }
  }

  Future<void> _confirmClearCanceledDebts(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limpar dívidas canceladas?'),
        content: const Text('Isso removerá permanentemente dívidas canceladas e desvinculará suas parcelas no financeiro.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Limpar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await ref.read(debtsProvider.notifier).clearCanceledDebts();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dívidas canceladas removidas.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appSettings = ref.watch(appSettingsProvider);
    final currency = appSettings[AppSettingKeys.defaultCurrency] ?? 'BRL';
    final projectSort = appSettings[AppSettingKeys.projectsDefaultSort] ?? 'created_desc';
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        children: [
          _section('Geral'),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Categorias'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Tema'),
            subtitle: Text(themeMode == ThemeMode.system ? 'Sistema' : (themeMode == ThemeMode.dark ? 'Escuro' : 'Claro')),
            trailing: const Icon(Icons.expand_more),
            onTap: () => _showThemeSheet(context, ref, themeMode),
          ),
          const Divider(),
          _section('Finanças'),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Gerenciar categorias financeiras'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceCategoriesScreen())),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Moeda padrão'),
            subtitle: Text(currency == 'USD' ? 'Dólar (USD)' : 'Real (BRL)'),
            trailing: const Icon(Icons.expand_more),
            onTap: () => _showCurrencySheet(context, ref, currency),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.visibility),
            title: const Text('Exibir valores financeiros na Home'),
            value: _settingBool(appSettings, AppSettingKeys.homeShowFinancialValues, fallback: true),
            onChanged: (val) => ref.read(appSettingsProvider.notifier).setValue(AppSettingKeys.homeShowFinancialValues, '$val'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever),
            title: const Text('Limpar movimentações canceladas'),
            subtitle: const Text('Remove transações com status cancelado'),
            onTap: () => _confirmClearCanceledTransactions(context, ref),
          ),
          const Divider(),
          _section('Dívidas'),
          SwitchListTile(
            secondary: const Icon(Icons.payments_outlined),
            title: const Text('Exibir dívidas quitadas'),
            value: _settingBool(appSettings, AppSettingKeys.debtsShowPaid, fallback: true),
            onChanged: (val) => ref.read(appSettingsProvider.notifier).setValue(AppSettingKeys.debtsShowPaid, '$val'),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_active_outlined),
            title: const Text('Ativar lembretes de parcelas por padrão'),
            value: _settingBool(appSettings, AppSettingKeys.debtsRemindersDefault),
            onChanged: (val) => ref.read(appSettingsProvider.notifier).setValue(AppSettingKeys.debtsRemindersDefault, '$val'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Avisar vencimento com antecedência'),
            subtitle: Text('${_settingInt(appSettings, AppSettingKeys.debtsReminderDaysBefore)} dia(s) antes'),
            trailing: const Icon(Icons.edit),
            onTap: () => _showDaysBeforeDialog(context, ref, appSettings),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cleaning_services),
            title: const Text('Limpar dívidas canceladas'),
            subtitle: const Text('Remove dívidas canceladas e desvincula parcelas'),
            onTap: () => _confirmClearCanceledDebts(context, ref),
          ),
          const Divider(),
          _section('Projetos'),
          SwitchListTile(
            secondary: const Icon(Icons.check_circle_outline),
            title: const Text('Exibir projetos concluídos'),
            value: _settingBool(appSettings, AppSettingKeys.projectsShowCompleted, fallback: true),
            onChanged: (val) => ref.read(appSettingsProvider.notifier).setValue(AppSettingKeys.projectsShowCompleted, '$val'),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.pause_circle_outline),
            title: const Text('Exibir projetos pausados'),
            value: _settingBool(appSettings, AppSettingKeys.projectsShowPaused, fallback: true),
            onChanged: (val) => ref.read(appSettingsProvider.notifier).setValue(AppSettingKeys.projectsShowPaused, '$val'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.sort),
            title: const Text('Ordenação padrão dos projetos'),
            subtitle: Text(_projectSortLabel(projectSort)),
            trailing: const Icon(Icons.expand_more),
            onTap: () => _showProjectSortSheet(context, ref, projectSort),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.dashboard_outlined),
            title: const Text('Mostrar projetos na Home'),
            value: _settingBool(appSettings, AppSettingKeys.homeShowProjectsCard, fallback: true),
            onChanged: (val) => ref.read(appSettingsProvider.notifier).setValue(AppSettingKeys.homeShowProjectsCard, '$val'),
          ),
          const Divider(),
          _section('Privacidade'),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off),
            title: const Text('Ocultar valores financeiros na tela inicial'),
            value: _settingBool(appSettings, AppSettingKeys.privacyHideHomeValues),
            onChanged: (val) => ref.read(appSettingsProvider.notifier).setValue(AppSettingKeys.privacyHideHomeValues, '$val'),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.shield_moon_outlined),
            title: const Text('Modo discreto para finanças'),
            subtitle: Text('Oculta valores com asteriscos (${currency == 'USD' ? '\$ ******' : 'R\$ ******'})'),
            value: _settingBool(appSettings, AppSettingKeys.financeDiscreteMode),
            onChanged: (val) => ref.read(appSettingsProvider.notifier).setValue(AppSettingKeys.financeDiscreteMode, '$val'),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('Bloqueio visual simples dos valores'),
            subtitle: const Text('Permite revelar valores na Home com um toque quando o modo discreto estiver desligado'),
            value: _settingBool(appSettings, AppSettingKeys.financeVisualLock),
            onChanged: (val) => ref.read(appSettingsProvider.notifier).setValue(AppSettingKeys.financeVisualLock, '$val'),
          ),
          const Divider(),
          _section('Gerenciamento'),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Exportar backup JSON'),
            subtitle: const Text('Cria uma cópia local dos dados principais antes de testes ou reset'),
            onTap: () => _exportBackup(context, ref),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('Limpar tarefas concluídas'),
            subtitle: const Text('Remove somente tarefas marcadas como concluídas'),
            onTap: () => _confirmClearCompletedTasks(context, ref),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.warning, color: Colors.red),
            title: const Text('Resetar dados principais', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Apaga tarefas, finanças, dívidas, projetos, contas, orçamentos e metas. Faça backup antes.'),
            onTap: () => _confirmResetCoreData(context, ref),
          ),
          const Divider(),
          _section('Sistema'),
          const ListTile(
            leading: Icon(Icons.data_usage),
            title: Text('Uso de Dados'),
            subtitle: Text('Offline-first habilitado. Tudo salvo localmente no SQLite.'),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.info),
            title: Text('Sobre'),
            subtitle: Text('DiasOrganize v1.0.0\nCompilado offline via GitHub Actions'),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Text(title, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
    );
  }

  void _showThemeSheet(BuildContext context, WidgetRef ref, ThemeMode selected) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _themeOption(ctx, ref, selected, ThemeMode.system, 'Sistema'),
          _themeOption(ctx, ref, selected, ThemeMode.light, 'Claro'),
          _themeOption(ctx, ref, selected, ThemeMode.dark, 'Escuro'),
        ],
      ),
    );
  }

  Widget _themeOption(BuildContext ctx, WidgetRef ref, ThemeMode selected, ThemeMode value, String label) {
    return ListTile(
      title: Text(label),
      trailing: selected == value ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () async {
        await ref.read(themeModeProvider.notifier).setTheme(value);
        if (ctx.mounted) Navigator.pop(ctx);
      },
    );
  }

  void _showCurrencySheet(BuildContext context, WidgetRef ref, String selected) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _settingOption(ctx, ref, selected, 'BRL', 'Real (BRL)', AppSettingKeys.defaultCurrency),
          _settingOption(ctx, ref, selected, 'USD', 'Dólar (USD)', AppSettingKeys.defaultCurrency),
        ],
      ),
    );
  }

  Widget _settingOption(BuildContext ctx, WidgetRef ref, String selected, String value, String label, String key) {
    return ListTile(
      title: Text(label),
      trailing: selected == value ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () async {
        await ref.read(appSettingsProvider.notifier).setValue(key, value);
        if (ctx.mounted) Navigator.pop(ctx);
      },
    );
  }

  Future<void> _showDaysBeforeDialog(BuildContext context, WidgetRef ref, Map<String, String> settings) async {
    final controller = TextEditingController(text: settings[AppSettingKeys.debtsReminderDaysBefore] ?? '0');
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dias de antecedência'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Ex: 2'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final value = int.tryParse(controller.text.trim()) ?? 0;
              await ref.read(appSettingsProvider.notifier).setValue(AppSettingKeys.debtsReminderDaysBefore, '${value < 0 ? 0 : value}');
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  String _projectSortLabel(String sort) {
    switch (sort) {
      case 'deadline_asc':
        return 'Prazo mais próximo';
      case 'progress_desc':
        return 'Maior progresso';
      case 'name_asc':
        return 'Nome (A-Z)';
      default:
        return 'Mais recentes';
    }
  }

  void _showProjectSortSheet(BuildContext context, WidgetRef ref, String selected) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _projectSortOption(ctx, ref, selected, 'created_desc', 'Mais recentes'),
          _projectSortOption(ctx, ref, selected, 'deadline_asc', 'Prazo mais próximo'),
          _projectSortOption(ctx, ref, selected, 'progress_desc', 'Maior progresso'),
          _projectSortOption(ctx, ref, selected, 'name_asc', 'Nome (A-Z)'),
        ],
      ),
    );
  }

  Widget _projectSortOption(BuildContext ctx, WidgetRef ref, String selected, String value, String label) {
    return ListTile(
      title: Text(label),
      trailing: selected == value ? const Icon(Icons.check, color: Colors.blue) : null,
      onTap: () async {
        await ref.read(appSettingsProvider.notifier).setValue(AppSettingKeys.projectsDefaultSort, value);
        if (ctx.mounted) Navigator.pop(ctx);
      },
    );
  }

  void _confirmClearCompletedTasks(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar exclusão'),
        content: const Text('Deseja remover todas as tarefas concluídas? Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              await ref.read(tasksProvider.notifier).clearCompletedTasks();
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarefas concluídas removidas.')));
              }
            },
            child: const Text('Excluir', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmResetCoreData(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Resetar dados principais?'),
        content: const Text('Isto apagará tarefas, movimentações financeiras, dívidas, projetos, etapas, contas, orçamentos e metas. Categorias e configurações serão mantidas. Recomenda-se exportar um backup JSON antes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _resetCoreData(ref);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Dados principais resetados. Categorias e configurações foram mantidas.')),
                );
              }
            },
            child: const Text('Resetar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
