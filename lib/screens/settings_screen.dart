import 'package:flutter/material.dart';
import 'categories_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações')),
      body: ListView(
        children: [
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
            subtitle: const Text('Sistema'),
            trailing: const Icon(Icons.expand_more),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.data_usage),
            title: const Text('Uso de Dados'),
            subtitle: const Text('Offline-first habilitado. Tudo salvo localmente.'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('Sobre'),
            subtitle: const Text('DiasOrganize v1.0.0\nCompilado via GitHub Actions'),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
