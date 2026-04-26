import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/providers.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final categories = ref.watch(categoriesProvider);
    final transactions = ref.watch(transactionsProvider);
    final financialCategories = ref.watch(financialCategoriesProvider);
    final debts = ref.watch(debtsProvider);
    final projects = ref.watch(projectsProvider);
    final appSettings = ref.watch(appSettingsProvider);

    final now = DateTime.now();
    final currency = appSettings[AppSettingKeys.defaultCurrency] ?? 'BRL';
    final hideFinancialValues = (appSettings[AppSettingKeys.financeDiscreteMode] ?? 'false') == 'true';

    String money(num value) {
      if (hideFinancialValues) return currency == 'USD' ? '\$ ******' : 'R\$ ******';
      final prefix = currency == 'USD' ? '\$' : 'R\$';
      return '$prefix ${value.toDouble().toStringAsFixed(2)}';
    }

    DateTime? expectedDate(transaction) => DateTime.tryParse(transaction.dueDate ?? transaction.transactionDate);
    DateTime? paidDate(transaction) => transaction.paidDate == null ? null : DateTime.tryParse(transaction.paidDate!);
    bool sameMonth(DateTime? date) => date != null && date.year == now.year && date.month == now.month;

    final validTasks = tasks.where((t) => t.status != 'canceled').toList();
    final createdTasks = validTasks.length;
    final completedTasks = validTasks.where((t) => t.status == 'concluida').length;
    final pendingTasks = validTasks.where((t) => t.status == 'pendente').length;
    final overdueTasks = validTasks.where((t) => t.status == 'atrasada').length;
    final completionRate = createdTasks == 0 ? 0.0 : (completedTasks / createdTasks) * 100;

    final categoryCounts = <int, int>{};
    for (final task in validTasks) {
      if (task.categoryId != null) categoryCounts[task.categoryId!] = (categoryCounts[task.categoryId!] ?? 0) + 1;
    }
    String topTaskCategory = '-';
    if (categoryCounts.isNotEmpty) {
      final topId = categoryCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      final idx = categories.indexWhere((category) => category.id == topId);
      if (idx != -1) topTaskCategory = categories[idx].name;
    }

    double receitasPrevistas = 0;
    double despesasPrevistas = 0;
    double receitasPagas = 0;
    double despesasPagas = 0;
    double totalPendente = 0;
    double totalPago = 0;
    final expenseByCategory = <int, double>{};
    final paymentCounts = <String, int>{};

    for (final transaction in transactions.where((t) => t.status != 'canceled')) {
      final expected = expectedDate(transaction);
      final paid = paidDate(transaction);
      final expectedInMonth = sameMonth(expected);
      final paidInMonth = transaction.status == 'paid' && (sameMonth(paid) || (paid == null && expectedInMonth));

      if (expectedInMonth) {
        if (transaction.type == 'income') {
          receitasPrevistas += transaction.amount;
        } else if (transaction.type == 'expense') {
          despesasPrevistas += transaction.amount;
          if (transaction.categoryId != null) {
            expenseByCategory[transaction.categoryId!] = (expenseByCategory[transaction.categoryId!] ?? 0) + transaction.amount;
          }
        }
        if (transaction.status == 'pending' || transaction.status == 'overdue') totalPendente += transaction.amount;
      }

      if (paidInMonth) {
        if (transaction.type == 'income') {
          receitasPagas += transaction.amount;
        } else if (transaction.type == 'expense') {
          despesasPagas += transaction.amount;
        }
        totalPago += transaction.amount;
        final method = (transaction.paymentMethod == null || transaction.paymentMethod!.isEmpty) ? 'não informado' : transaction.paymentMethod!;
        paymentCounts[method] = (paymentCounts[method] ?? 0) + 1;
      }
    }

    final saldoPrevisto = receitasPrevistas - despesasPrevistas;
    final saldoRealizado = receitasPagas - despesasPagas;

    String topExpenseCategory = '-';
    if (expenseByCategory.isNotEmpty) {
      final topCatId = expenseByCategory.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      final idx = financialCategories.indexWhere((category) => category.id == topCatId);
      if (idx != -1) topExpenseCategory = financialCategories[idx].name;
    }

    final mostUsedPayment = paymentCounts.isEmpty ? '-' : paymentCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    final debtTransactions = transactions.where((t) => t.debtId != null && t.status != 'canceled').toList();
    final totalDividas = debts.where((debt) => debt.status != 'canceled').fold<double>(0, (sum, debt) => sum + debt.totalAmount);
    final totalPagoEmDividas = debtTransactions.where((transaction) => transaction.status == 'paid').fold<double>(0, (sum, transaction) => sum + transaction.amount);
    final totalDescontosDividas = debtTransactions.where((transaction) => transaction.status == 'paid').fold<double>(0, (sum, transaction) => sum + (transaction.discountAmount ?? 0));
    final totalAbatidoDividas = totalPagoEmDividas + totalDescontosDividas;
    final totalRestante = (totalDividas - totalAbatidoDividas).clamp(0, double.infinity).toDouble();
    final percentualQuitado = totalDividas == 0 ? 0.0 : ((totalAbatidoDividas / totalDividas) * 100).clamp(0, 100).toDouble();
    final parcelasPagas = debtTransactions.where((transaction) => transaction.status == 'paid').length;
    final parcelasPendentes = debtTransactions.where((transaction) => transaction.status == 'pending').length;
    final parcelasAtrasadas = debtTransactions.where((transaction) => transaction.status == 'overdue').length;

    String debtMaxRemaining = '-';
    double debtMaxRemainingValue = -1;
    for (final debt in debts.where((debt) => debt.status != 'canceled')) {
      final abatido = debtTransactions.where((transaction) => transaction.debtId == debt.id && transaction.status == 'paid').fold<double>(0, (sum, transaction) => sum + transaction.amount + (transaction.discountAmount ?? 0));
      final remaining = (debt.totalAmount - abatido).clamp(0, double.infinity).toDouble();
      if (remaining > debtMaxRemainingValue) {
        debtMaxRemainingValue = remaining;
        debtMaxRemaining = debt.name;
      }
    }

    final projetosValidos = projects.where((project) => project.status != 'canceled').toList();
    final projetosCriados = projetosValidos.length;
    final projetosAndamento = projetosValidos.where((project) => project.status == 'active').length;
    final projetosConcluidos = projetosValidos.where((project) => project.status == 'completed').length;
    final projetosPausados = projetosValidos.where((project) => project.status == 'paused').length;
    final projetosAtrasados = projetosValidos.where((project) {
      if (project.endDate == null || project.status == 'completed') return false;
      final end = DateTime.tryParse(project.endDate!);
      return end != null && end.isBefore(now);
    }).length;
    final mediaProgresso = projetosValidos.isEmpty ? 0.0 : projetosValidos.fold<double>(0, (sum, project) => sum + project.progress) / projetosValidos.length;

    String projetoMaisProximo = '-';
    final withDue = projetosValidos.where((project) {
      if (project.endDate == null || project.status == 'completed') return false;
      final end = DateTime.tryParse(project.endDate!);
      return end != null && end.isAfter(now);
    }).toList()
      ..sort((a, b) {
        final ad = DateTime.tryParse(a.endDate!);
        final bd = DateTime.tryParse(b.endDate!);
        if (ad == null && bd == null) return 0;
        if (ad == null) return 1;
        if (bd == null) return -1;
        return ad.compareTo(bd);
      });
    if (withDue.isNotEmpty) projetoMaisProximo = withDue.first.name;

    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Estatísticas'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Produtividade'),
              Tab(text: 'Finanças'),
              Tab(text: 'Dívidas'),
              Tab(text: 'Projetos'),
              Tab(text: 'Resumo geral'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _StatsList(items: [
              _Metric('Tarefas criadas', '$createdTasks'),
              _Metric('Tarefas concluídas', '$completedTasks'),
              _Metric('Tarefas pendentes', '$pendingTasks'),
              _Metric('Tarefas atrasadas', '$overdueTasks'),
              _Metric('Taxa de conclusão', '${completionRate.toStringAsFixed(1)}%'),
              _Metric('Categoria com mais tarefas', topTaskCategory),
            ]),
            _StatsList(items: [
              _Metric('Receitas previstas do mês', money(receitasPrevistas)),
              _Metric('Despesas previstas do mês', money(despesasPrevistas)),
              _Metric('Saldo previsto', money(saldoPrevisto)),
              _Metric('Receitas pagas/recebidas', money(receitasPagas)),
              _Metric('Despesas pagas', money(despesasPagas)),
              _Metric('Saldo realizado', money(saldoRealizado)),
              _Metric('Categoria com maior gasto previsto', topExpenseCategory),
              _Metric('Forma de pagamento mais usada', mostUsedPayment),
              _Metric('Total pendente previsto', money(totalPendente)),
              _Metric('Total realizado', money(totalPago)),
            ]),
            _StatsList(items: [
              _Metric('Total em dívidas', money(totalDividas)),
              _Metric('Pago em dinheiro', money(totalPagoEmDividas)),
              _Metric('Descontos abatidos', money(totalDescontosDividas)),
              _Metric('Total abatido', money(totalAbatidoDividas)),
              _Metric('Total restante', money(totalRestante)),
              _Metric('Percentual quitado', '${percentualQuitado.toStringAsFixed(1)}%'),
              _Metric('Parcelas pagas', '$parcelasPagas'),
              _Metric('Parcelas pendentes', '$parcelasPendentes'),
              _Metric('Parcelas atrasadas', '$parcelasAtrasadas'),
              _Metric('Dívida com maior valor restante', debtMaxRemaining),
            ]),
            _StatsList(items: [
              _Metric('Projetos criados', '$projetosCriados'),
              _Metric('Projetos em andamento', '$projetosAndamento'),
              _Metric('Projetos concluídos', '$projetosConcluidos'),
              _Metric('Projetos pausados', '$projetosPausados'),
              _Metric('Projetos atrasados', '$projetosAtrasados'),
              _Metric('Média de progresso', '${mediaProgresso.toStringAsFixed(1)}%'),
              _Metric('Projeto mais próximo do prazo', projetoMaisProximo),
            ]),
            _StatsList(items: [
              _Metric('Tarefas totais', '$createdTasks'),
              _Metric('Saldo previsto do mês', money(saldoPrevisto)),
              _Metric('Saldo realizado do mês', money(saldoRealizado)),
              _Metric('Dívidas restantes', money(totalRestante)),
              _Metric('Projetos em andamento', '$projetosAndamento'),
              _Metric('Média progresso projetos', '${mediaProgresso.toStringAsFixed(1)}%'),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Metric {
  final String label;
  final String value;
  _Metric(this.label, this.value);
}

class _StatsList extends StatelessWidget {
  final List<_Metric> items;
  const _StatsList({required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(item.label),
            trailing: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 170),
              child: Text(
                item.value,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.end,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      },
    );
  }
}
