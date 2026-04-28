import 'dart:io';

void main() {
  final file = File('lib/features/finance/create_transaction_screen.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }

  var text = file.readAsStringSync();

  const original = '''                TextField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    hintText: 'Ex: essencial, casa, trabalho',
                    helperText: 'Separe por vírgulas para facilitar filtros e relatórios futuros.',
                    border: OutlineInputBorder(),
                  ),
                ),
''';

  const replacement = '''                TextField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags',
                    hintText: 'Ex: essencial, casa, trabalho',
                    helperText: 'Separe por vírgulas. As tags aparecem abaixo como prévia.',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _tagsController,
                  builder: (context, value, _) {
                    final tags = value.text
                        .split(',')
                        .map((tag) => tag.trim())
                        .where((tag) => tag.isNotEmpty)
                        .toSet()
                        .toList();
                    if (tags.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: tags.map((tag) => InputChip(label: Text(tag), visualDensity: VisualDensity.compact)).toList(),
                      ),
                    );
                  },
                ),
''';

  if (!text.contains(replacement)) {
    if (!text.contains(original)) {
      stderr.writeln('ERRO: bloco original de Tags não encontrado para aplicar prévia visual.');
      exit(1);
    }
    text = text.replaceFirst(original, replacement);
  }

  if (!text.contains('ValueListenableBuilder<TextEditingValue>') || !text.contains('InputChip(label: Text(tag)')) {
    stderr.writeln('ERRO: prévia visual de tags não foi aplicada corretamente.');
    exit(1);
  }

  file.writeAsStringSync(text);
  stdout.writeln('create_transaction_screen.dart tag UX patch aplicado.');
}
