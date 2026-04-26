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

    final now = DateTime.now();

    final createdTasks = tasks.length;
    final completedTasks = tasks.where((t) => t.status == 'concluida').length;
    final pendingTasks = tasks.where((t) => t.status == 'pendente').length;
    final overdueTasks = tasks.where((t) => t.status == 'atrasada').length;
    final completionRate = createdTasks == 0 ? 0.0 : (completedTasks / createdTasks) * 100;

    final categoryCounts = <int, int>{};
    for (final t in tasks) {
      if (t.categoryId != null) {
        categoryCounts[t.categoryId!] = (categoryCounts[t.categoryId!] ?? 0) + 1;
      }
    }
    String topTaskCategory = '-';
    if (categoryCounts.isNotEmpty) {
      final topId = categoryCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      final idx = categories.indexWhere((c) => c.id == topId);
      if (idx != -1) topTaskCategory = categories[idx].name;
    }

    final monthTransactions = transactions.where((t) {
      final dt = DateTime.tryParse(t.transactionDate);
      return dt != null && dt.year == now.year && dt.month == now.month && t.status != 'canceled';
    }).toList();

    final receitasMes = monthTransactions.where((t) => t.type == 'income').fold<double>(0, (s, t) => s + t.amount);
    final despesasMes = monthTransactions.where((t) => t.type == 'expense').fold<double>(0, (s, t) => s + t.amount);
    final saldoMes = receitasMes - despesasMes;

    final expenseByCategory = <int, double>{};
    for (final t in monthTransactions.where((t) => t.type == 'expense')) {
      if (t.categoryId != null) {
        expenseByCategory[t.categoryId!] = (expenseByCategory[t.categoryId!] ?? 0) + t.amount;
      }
    }
    String topExpenseCategory = '-';
    if (expenseByCategory.isNotEmpty) {
      final topCatId = expenseByCategory.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      final idx = financialCategories.indexWhere((c) => c.id == topCatId);
      if (idx != -1) topExpenseCategory = financialCategories[idx].name;
    }

    final paymentCounts = <String, int>{};
    for (final t in monthTransactions) {
      final method = (t.paymentMethod == null || t.paymentMethod!.isEmpty) ? 'não informado' : t.paymentMethod!;
      paymentCounts[method] = (paymentCounts[method] ?? 0) + 1;
    }
    final mostUsedPayment = paymentCounts.isEmpty ? '-' : paymentCounts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    final totalPendente = monthTransactions.where((t) => t.status == 'pending' || t.status == 'overdue').fold<double>(0, (s, t) => s + t.amount);
    final totalPago = monthTransactions.where((t) => t.status == 'paid').fold<double>(0, (s, t) => s + t.amount);

    final debtTransactions = transactions.where((t) => t.debtId != null && t.status != 'canceled').toList();
    final totalDividas = debts.where((d) => d.status != 'canceled').fold<double>(0, (s, d) => s + d.totalAmount);
    final totalJaPago = debtTransactions.where((t) => t.status == 'paid').fold<double>(0, (s, t) => s + t.amount);
    final totalRestante = (totalDividas - totalJaPago).clamp(0, double.infinity).toDouble();
    final percentualQuitado = totalDividas == 0 ? 0.0 : (totalJaPago / totalDividas) * 100;
    final parcelasPagas = debtTransactions.where((t) => t.status == 'paid').length;
    final parcelasPendentes = debtTransactions.where((t) => t.status == 'pending').length;
    final parcelasAtrasadas = debtTransactions.where((t) => t.status == 'overdue').length;

    String debtMaxRemaining = '-';
    double debtMaxRemainingValue = -1;
    for (final d in debts.where((d) => d.status != 'canceled')) {
      final paidForDebt = debtTransactions.where((t) => t.debtId == d.id && t.status == 'paid').fold<double>(0, (s, t) => s + t.amount);
      final remaining = (d.totalAmount - paidForDebt).clamp(0, double.infinity).toDouble();
      if (remaining > debtMaxRemainingValue) {
        debtMaxRemainingValue = remaining;
        debtMaxRemaining = d.name;
      }
    }

    final projetosCriados = projects.length;
    final projetosAndamento = projects.where((p) => p.status == 'active').length;
    final projetosConcluidos = projects.where((p) => p.status == 'completed').length;
    final projetosPausados = projects.where((p) => p.status == 'paused').length;
    final projetosAtrasados = projects.where((p) {
      if (p.endDate == null || p.status == 'completed' || p.status == 'canceled') return false;
      final end = DateTime.tryParse(p.endDate!);
      return end != null && end.isBefore(now);
    }).length;
    final mediaProgresso = projects.isEmpty ? 0.0 : projects.fold<double>(0, (s, p) => s + p.progress) / projects.length;

    String projetoMaisProximo = '-';
    final withDue = projects.where((p) {
      if (p.endDate == null || p.status == 'completed' || p.status == 'canceled') return false;
      final end = DateTime.tryParse(p.endDate!);
      return end != null && end.isAfter(now);
    }).toList()
      ..sort((a, b) => DateTime.parse(a.endDate!).compareTo(DateTime.parse(b.endDate!)));
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
              _Metric('Receitas do mês', 'R\$ ${receitasMes.toStringAsFixed(2)}'),
              _Metric('Despesas do mês', 'R\$ ${despesasMes.toStringAsFixed(2)}'),
              _Metric('Saldo do mês', 'R\$ ${saldoMes.toStringAsFixed(2)}'),
              _Metric('Categoria com maior gasto', topExpenseCategory),
              _Metric('Forma de pagamento mais usada', mostUsedPayment),
              _Metric('Total pendente', 'R\$ ${totalPendente.toStringAsFixed(2)}'),
              _Metric('Total pago', 'R\$ ${totalPago.toStringAsFixed(2)}'),
            ]),
            _StatsList(items: [
              _Metric('Total em dívidas', 'R\$ ${totalDividas.toStringAsFixed(2)}'),
              _Metric('Total já pago', 'R\$ ${totalJaPago.toStringAsFixed(2)}'),
              _Metric('Total restante', 'R\$ ${totalRestante.toStringAsFixed(2)}'),
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
              _Metric('Saldo do mês', 'R\$ ${saldoMes.toStringAsFixed(2)}'),
              _Metric('Dívidas restantes', 'R\$ ${totalRestante.toStringAsFixed(2)}'),
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
            trailing: Text(item.value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}
