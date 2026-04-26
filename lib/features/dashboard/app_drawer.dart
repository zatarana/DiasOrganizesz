import 'package:flutter/material.dart';
import '../finance/finance_screen.dart';
import '../debts/debts_screen.dart';
import '../projects/projects_screen.dart';
import '../calendar/calendar_screen.dart';
import '../statistics/stats_screen.dart';
import '../settings/settings_screen.dart';
import '../categories/categories_screen.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text(
              'DiasOrganize V2',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Início (Resumo)'),
            onTap: () {
              Navigator.pop(context);
              // Already at home mostly, but can navigate to root
            },
          ),
          ListTile(
            leading: const Icon(Icons.attach_money),
            title: const Text('Finanças'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.money_off),
            title: const Text('Dívidas'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DebtsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.rocket_launch),
            title: const Text('Projetos'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProjectsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month),
            title: const Text('Calendário'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CalendarScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.category),
            title: const Text('Categorias'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const CategoriesScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.pie_chart),
            title: const Text('Estatísticas'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Configurações'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            },
          ),
        ],
      ),
    );
  }
}
