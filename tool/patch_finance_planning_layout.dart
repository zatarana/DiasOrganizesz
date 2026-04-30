import 'dart:io';

void main() {
  final file = File('lib/features/finance/finance_planning_screen.dart');
  if (!file.existsSync()) {
    stderr.writeln('Arquivo não encontrado: ${file.path}');
    exit(1);
  }

  var text = file.readAsStringSync();
  text = _fixTopActions(text);
  text = _fixAccountCards(text);
  text = _fixTransferButtonLabel(text);
  _validate(text);

  file.writeAsStringSync(text);
  stdout.writeln('Layout do Planejamento Financeiro ajustado para telas estreitas.');
}

String _fixTopActions(String text) {
  if (text.contains("_planningActionsWrap")) return text;

  const oldBlock = '''        Row(
          children: [
            Expanded(child: ElevatedButton.icon(onPressed: () => _showAccountDialog(), icon: const Icon(Icons.add), label: const Text('Adicionar conta'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: _openTransfers, icon: const Icon(Icons.swap_horiz), label: const Text('Transferências'))),
          ],
        ),''';

  const newBlock = '''        LayoutBuilder(
          builder: (context, constraints) => _planningActionsWrap(
            maxWidth: constraints.maxWidth,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showAccountDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Adicionar conta', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              OutlinedButton.icon(
                onPressed: _openTransfers,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Transferências', maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),''';

  if (!text.contains(oldBlock)) {
    stderr.writeln('ERRO layout financeiro: bloco de ações de contas não localizado.');
    exit(1);
  }
  text = text.replaceFirst(oldBlock, newBlock);

  const helperAnchor = '  Widget _budgetsTab() {';
  const helper = r'''
  Widget _planningActionsWrap({required double maxWidth, required List<Widget> children}) {
    final useSingleColumn = maxWidth < 390;
    if (useSingleColumn) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            SizedBox(height: 52, child: children[i]),
            if (i != children.length - 1) const SizedBox(height: 8),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          Expanded(child: SizedBox(height: 52, child: children[i])),
          if (i != children.length - 1) const SizedBox(width: 10),
        ],
      ],
    );
  }

''';

  if (!text.contains(helperAnchor)) {
    stderr.writeln('ERRO layout financeiro: não foi possível inserir helper de ações.');
    exit(1);
  }
  return text.replaceFirst(helperAnchor, '$helper$helperAnchor');
}

String _fixTransferButtonLabel(String text) {
  // Evita quebra agressiva em telas pequenas quando o layout ainda usa duas colunas.
  return text.replaceAll("label: const Text('Transferências'))", "label: const Text('Transferências', maxLines: 1, overflow: TextOverflow.ellipsis))");
}

String _fixAccountCards(String text) {
  if (text.contains('_AccountPlanningCard(')) return text;

  const oldBlock = r'''            return Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Colors.blue.withValues(alpha: 0.12), child: Icon(account.ignoreInTotals ? Icons.visibility_off : _accountIcon(account.type), color: account.ignoreInTotals ? Colors.grey : Colors.blue)),
                title: Row(
                  children: [
                    Expanded(child: Text(account.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    if (isDefault) const Chip(label: Text('Padrão'), visualDensity: VisualDensity.compact),
                    if (account.ignoreInTotals) const Padding(padding: EdgeInsets.only(left: 4), child: Chip(label: Text('Fora total'), visualDensity: VisualDensity.compact)),
                  ],
                ),
                subtitle: Text([
                  '${_accountTypeLabel(account.type)}${account.isArchived ? ' • arquivada' : ''}${account.ignoreInTotals ? ' • não soma no saldo total' : ''}',
                  'Base: ${_money(account.initialBalance)}',
                  if (latestAdjustment != null) 'Último ajuste: ${latestAdjustment.delta >= 0 ? '+' : ''}${_money(latestAdjustment.delta)} em ${_safeDateLabel(latestAdjustment.adjustmentDate)}',
                ].join('\n')),
                trailing: SizedBox(
                  width: 150,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(child: Text(_money(account.currentBalance), overflow: TextOverflow.ellipsis, style: TextStyle(fontWeight: FontWeight.bold, color: account.ignoreInTotals ? Colors.grey : null))),
                      PopupMenuButton<String>(
                        onSelected: (action) => _handleAccountAction(account, action),
                        itemBuilder: (context) => [
                          const PopupMenuItem(value: 'edit', child: Text('Editar conta')),
                          PopupMenuItem(value: 'default', enabled: !account.isArchived, child: Text(isDefault ? 'Remover padrão' : 'Definir como padrão')),
                          PopupMenuItem(value: 'adjust', enabled: account.id != null && !account.isArchived, child: const Text('Reajustar saldo')),
                          PopupMenuItem(value: 'history', enabled: account.id != null, child: const Text('Histórico de ajustes')),
                        ],
                      ),
                    ],
                  ),
                ),
                onTap: () => _showAccountDialog(account: account),
              ),
            );''';

  const newBlock = r'''            return _AccountPlanningCard(
              account: account,
              isDefault: isDefault,
              latestAdjustment: latestAdjustment,
              money: _money,
              safeDateLabel: _safeDateLabel,
              accountTypeLabel: _accountTypeLabel,
              accountIcon: _accountIcon,
              onTap: () => _showAccountDialog(account: account),
              onAction: (action) => _handleAccountAction(account, action),
            );''';

  if (!text.contains(oldBlock)) {
    stderr.writeln('ERRO layout financeiro: card de conta antigo não localizado.');
    exit(1);
  }
  text = text.replaceFirst(oldBlock, newBlock);

  const insertAnchor = 'class _EmptyState extends StatelessWidget {';
  const widgetSource = r'''
class _AccountPlanningCard extends StatelessWidget {
  final FinancialAccount account;
  final bool isDefault;
  final FinancialBalanceAdjustment? latestAdjustment;
  final String Function(num value) money;
  final String Function(String? value) safeDateLabel;
  final String Function(String type) accountTypeLabel;
  final IconData Function(String type) accountIcon;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;

  const _AccountPlanningCard({
    required this.account,
    required this.isDefault,
    required this.latestAdjustment,
    required this.money,
    required this.safeDateLabel,
    required this.accountTypeLabel,
    required this.accountIcon,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final muted = account.ignoreInTotals || account.isArchived;
    final iconColor = muted ? Colors.grey : Colors.blue;
    final detailParts = <String>[
      accountTypeLabel(account.type),
      if (account.isArchived) 'arquivada',
      if (account.ignoreInTotals) 'fora do saldo total',
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                backgroundColor: iconColor.withValues(alpha: 0.12),
                child: Icon(account.ignoreInTotals ? Icons.visibility_off : accountIcon(account.type), color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (isDefault) const _CompactAccountBadge(label: 'Padrão'),
                        if (account.ignoreInTotals) const _CompactAccountBadge(label: 'Fora total'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(detailParts.join(' • '), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('Base: ${money(account.initialBalance)}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (latestAdjustment != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Último ajuste: ${latestAdjustment!.delta >= 0 ? '+' : ''}${money(latestAdjustment!.delta)} em ${safeDateLabel(latestAdjustment!.adjustmentDate)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 96),
                child: Text(
                  money(account.currentBalance),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(fontWeight: FontWeight.w900, color: muted ? Colors.grey : null),
                ),
              ),
              PopupMenuButton<String>(
                onSelected: onAction,
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar conta')),
                  PopupMenuItem(value: 'default', enabled: !account.isArchived, child: Text(isDefault ? 'Remover padrão' : 'Definir como padrão')),
                  PopupMenuItem(value: 'adjust', enabled: account.id != null && !account.isArchived, child: const Text('Reajustar saldo')),
                  PopupMenuItem(value: 'history', enabled: account.id != null, child: const Text('Histórico de ajustes')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactAccountBadge extends StatelessWidget {
  final String label;
  const _CompactAccountBadge({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.45)),
          ),
          child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
        ),
      );
}

''';

  if (!text.contains(insertAnchor)) {
    stderr.writeln('ERRO layout financeiro: não foi possível inserir widget de conta.');
    exit(1);
  }
  return text.replaceFirst(insertAnchor, '$widgetSource$insertAnchor');
}

void _validate(String text) {
  for (final check in [
    '_planningActionsWrap',
    '_AccountPlanningCard',
    '_CompactAccountBadge',
    "Text('Transferências', maxLines: 1",
  ]) {
    if (!text.contains(check)) {
      stderr.writeln('ERRO layout financeiro: patch incompleto. Faltou: $check');
      exit(1);
    }
  }

  if (text.contains('RIGHT OVERFLOWED') || text.contains('BOTTOM OVERFLOWED')) {
    stderr.writeln('ERRO layout financeiro: marcador de overflow indevido encontrado.');
    exit(1);
  }
}
