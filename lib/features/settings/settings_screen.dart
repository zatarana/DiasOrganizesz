import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';
import '../categories/categories_screen.dart';
import '../finance/finance_categories_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  bool _settingBool(Map<String, String> settings, String key, {bool fallback = false}) {
    return (settings[key] ?? '$fallback') == 'true';
  }

  int _settingInt(Map<String, String> settings, String key, {int fallback = 0}) {
    return int.tryParse(settings[key] ?? '$fallback') ?? fallback;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appSettings = ref.watch(appSettingsProvider);
    final currency = appSettings[AppSettingKeys.defaultCurrency] ?? 'BRL';
    final projectSort = appSettings[AppSettingKeys.projectsDefaultSort] ?? 'created_desc';

    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        children: [
          const Padding(padding: EdgeInsets.all(16), child: Text('Geral', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Categorias'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Tema'),
            subtitle: Text(
              ref.watch(themeModeProvider) == ThemeMode.system 
                  ? 'Sistema' 
                  : (ref.watch(themeModeProvider) == ThemeMode.dark ? 'Escuro' : 'Claro')
            ),
            trailing: const Icon(Icons.expand_more),
            onTap: () {
              showModalBottomSheet(
                context: context,
                builder: (ctx) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('Sistema'),
                      trailing: ref.watch(themeModeProvider) == ThemeMode.system ? const Icon(Icons.check, color: Colors.blue) : null,
                      onTap: () {
                        ref.read(themeModeProvider.notifier).setTheme(ThemeMode.system);
                        Navigator.pop(ctx);
                      },
                    ),
                    ListTile(
                      title: const Text('Claro'),
                      trailing: ref.watch(themeModeProvider) == ThemeMode.light ? const Icon(Icons.check, color: Colors.blue) : null,
                      onTap: () {
                        ref.read(themeModeProvider.notifier).setTheme(ThemeMode.light);
                        Navigator.pop(ctx);
                      },
                    ),
                    ListTile(
                      title: const Text('Escuro'),
                      trailing: ref.watch(themeModeProvider) == ThemeMode.dark ? const Icon(Icons.check, color: Colors.blue) : null,
                      onTap: () {
                        ref.read(themeModeProvider.notifier).setTheme(ThemeMode.dark);
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                )
              );
            },
          ),
          const Divider(),
          const Padding(padding: EdgeInsets.all(16), child: Text('Finanças', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Gerenciar categorias financeiras'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceCategoriesScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Moeda padrão'),
            subtitle: Text(currency == 'USD' ? 'Dólar (USD)' : 'Real (BRL)'),
            trailing: const Icon(Icons.expand_more),
            onTap: () {
              showModalBottomSheet(
                context: context,
                builder: (ctx) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('Real (BRL)'),
                      trailing: currency == 'BRL' ? const Icon(Icons.check, color: Colors.blue) : null,
                      onTap: () async {
                        await ref.read(appSettingsProvider.notifier).setValue(AppSettingKeys.defaultCurrency, 'BRL');
                        Navigator.pop(ctx);
                      },
                    ),
                    ListTile(
                      title: const Text('Dólar (USD)'),
                      trailing: currency == 'USD' ? const Icon(Icons.check, color: Colors.blue) : null,
                      onTap: () async {
                        await ref.read(appSettingsProvider.notifier).setValue(AppSettingKeys.defaultCurrency, 'USD');
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
              );
            },
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
            onTap: () async {
              await ref.read(transactionsProvider.notifier).clearCanceledTransactions();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Movimentações canceladas removidas.')));
            },
          ),
          const Divider(),
          const Padding(padding: EdgeInsets.all(16), child: Text('Dívidas', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
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
            onTap: () async {
              final controller = TextEditingController(text: (appSettings[AppSettingKeys.debtsReminderDaysBefore] ?? '0'));
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
                        Navigator.pop(ctx);
                      },
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.cleaning_services),
            title: const Text('Limpar dívidas canceladas'),
            onTap: () async {
              await ref.read(debtsProvider.notifier).clearCanceledDebts();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dívidas canceladas removidas.')));
            },
          ),
          const Divider(),
          const Padding(padding: EdgeInsets.all(16), child: Text('Projetos', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
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
            subtitle: Text(
              projectSort == 'deadline_asc'
                  ? 'Prazo mais próximo'
                  : projectSort == 'progress_desc'
                      ? 'Maior progresso'
                      : projectSort == 'name_asc'
                          ? 'Nome (A-Z)'
                          : 'Mais recentes',
            ),
            trailing: const Icon(Icons.expand_more),
            onTap: () {
              showModalBottomSheet(
                context: context,
                builder: (ctx) => Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _projectSortOption(ctx, ref, projectSort, 'created_desc', 'Mais recentes'),
                    _projectSortOption(ctx, ref, projectSort, 'deadline_asc', 'Prazo mais próximo'),
                    _projectSortOption(ctx, ref, projectSort, 'progress_desc', 'Maior progresso'),
                    _projectSortOption(ctx, ref, projectSort, 'name_asc', 'Nome (A-Z)'),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.dashboard_outlined),
            title: const Text('Mostrar projetos na Home'),
            value: _settingBool(appSettings, AppSettingKeys.homeShowProjectsCard, fallback: true),
            onChanged: (val) => ref.read(appSettingsProvider.notifier).setValue(AppSettingKeys.homeShowProjectsCard, '$val'),
          ),
          const Divider(),
          const Padding(padding: EdgeInsets.all(16), child: Text('Privacidade', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
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
            subtitle: const Text('Oculta valores com asteriscos (R\$ ******)'),
            value: _settingBool(appSettings, AppSettingKeys.financeDiscreteMode),
            onChanged: (val) => ref.read(appSettingsProvider.notifier).setValue(AppSettingKeys.financeDiscreteMode, '$val'),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.lock_outline),
            title: const Text('Bloqueio visual simples dos valores'),
            subtitle: const Text('Permite revelar valores na Home com um toque'),
            value: _settingBool(appSettings, AppSettingKeys.financeVisualLock),
            onChanged: (val) => ref.read(appSettingsProvider.notifier).setValue(AppSettingKeys.financeVisualLock, '$val'),
          ),
          const Divider(),
          const Padding(padding: EdgeInsets.all(16), child: Text('Gerenciamento', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.delete_sweep),
            title: const Text('Limpar Concluídas'),
            subtitle: const Text('Remove todas as tarefas já marcadas como concluídas'),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirmar Exclusão'),
                  content: const Text('Deseja realmente remover todas as tarefas concluídas? Esta ação não pode ser desfeita.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                    TextButton(
                      onPressed: () {
                        ref.read(tasksProvider.notifier).clearCompletedTasks();
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tarefas limpas com sucesso!')));
                      }, 
                      child: const Text('Excluir', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.warning, color: Colors.red),
            title: const Text('Resetar Aplicativo', style: TextStyle(color: Colors.red)),
            subtitle: const Text('Apaga todas as tarefas e dados.'),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Resetar Tudo?'),
                  content: const Text('Deseja apagar todas as tarefas? As categorias padrões serão mantidas.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                    TextButton(
                      onPressed: () async {
                        final tasks = ref.read(tasksProvider);
                        for (var t in tasks) {
                           if (t.id != null) await ref.read(tasksProvider.notifier).removeTask(t.id!);
                        }
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aplicativo resetado.')));
                      },
                      child: const Text('Apagar Tudo', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),
          const Padding(padding: EdgeInsets.all(16), child: Text('Sistema', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.data_usage),
            title: const Text('Uso de Dados'),
            subtitle: const Text('Offline-first habilitado. Tudo salvo localmente no SQLite.'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Sobre'),
            subtitle: const Text('DiasOrganize v1.0.0\nCompilado offline via GitHub Actions'),
            onTap: () {},
          ),
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
        Navigator.pop(ctx);
      },
    );
  }
}
