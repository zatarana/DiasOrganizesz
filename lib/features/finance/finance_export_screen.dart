import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/providers.dart';
import 'finance_csv_exporter.dart';
import 'finance_debit_credit_report.dart';
import 'finance_monthly_evolution_report.dart';

class FinanceExportScreen extends ConsumerStatefulWidget {
  const FinanceExportScreen({super.key});

  @override
  ConsumerState<FinanceExportScreen> createState() => _FinanceExportScreenState();
}

class _FinanceExportScreenState extends ConsumerState<FinanceExportScreen> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  int _monthsBack = 6;
  String _selectedExport = 'transactions';
  String _csv = '';

  DateTime get _startMonth => DateTime(_selectedMonth.year, _selectedMonth.month - _monthsBack + 1, 1);

  void _previousMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1, 1));
  void _nextMonth() => setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1));
  void _currentMonth() {
    final now = DateTime.now();
    setState(() => _selectedMonth = DateTime(now.year, now.month, 1));
  }

  void _generateCsv() {
    final transactions = ref.read(transactionsProvider);
    String csv;
    switch (_selectedExport) {
      case 'monthlyEvolution':
        final report = FinanceMonthlyEvolutionReport.fromTransactions(
          transactions: transactions,
          startMonth: _startMonth,
          endMonth: _selectedMonth,
        );
        csv = FinanceCsvExporter.monthlyEvolutionToCsv(report);
        break;
      case 'debitCredit':
        final report = FinanceDebitCreditReport.fromTransactions(transactions: transactions, month: _selectedMonth);
        csv = FinanceCsvExporter.debitCreditToCsv(report);
        break;
      case 'transactions':
      default:
        csv = FinanceCsvExporter.transactionsToCsv(transactions);
        break;
    }
    setState(() => _csv = csv);
  }

  Future<void> _copyCsv() async {
    if (_csv.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: _csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV copiado para a área de transferência.')));
  }

  String _monthLabel(DateTime month) => DateFormat('MMMM yyyy', 'pt_BR').format(month).toUpperCase();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Exportação CSV')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tipo de exportação', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedExport,
                    items: const [
                      DropdownMenuItem(value: 'transactions', child: Text('Todas as transações')),
                      DropdownMenuItem(value: 'monthlyEvolution', child: Text('Evolução mensal')),
                      DropdownMenuItem(value: 'debitCredit', child: Text('Débito vs crédito')),
                    ],
                    onChanged: (value) => setState(() {
                      _selectedExport = value ?? 'transactions';
                      _csv = '';
                    }),
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                  ),
                  if (_selectedExport != 'transactions') ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        IconButton(icon: const Icon(Icons.chevron_left), onPressed: _previousMonth),
                        Expanded(
                          child: InkWell(
                            onTap: _currentMonth,
                            child: Text(
                              _selectedExport == 'monthlyEvolution'
                                  ? '${DateFormat('MMM/yyyy', 'pt_BR').format(_startMonth).toUpperCase()} — ${DateFormat('MMM/yyyy', 'pt_BR').format(_selectedMonth).toUpperCase()}'
                                  : _monthLabel(_selectedMonth),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        IconButton(icon: const Icon(Icons.chevron_right), onPressed: _nextMonth),
                      ],
                    ),
                    if (_selectedExport == 'monthlyEvolution') ...[
                      const SizedBox(height: 8),
                      SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(value: 3, label: Text('3m')),
                          ButtonSegment(value: 6, label: Text('6m')),
                          ButtonSegment(value: 12, label: Text('12m')),
                        ],
                        selected: {_monthsBack},
                        onSelectionChanged: (selection) => setState(() {
                          _monthsBack = selection.first;
                          _csv = '';
                        }),
                      ),
                    ],
                  ],
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _generateCsv,
                    icon: const Icon(Icons.table_view),
                    label: const Text('Gerar CSV'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_csv.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Expanded(child: Text('Prévia do CSV', style: TextStyle(fontWeight: FontWeight.bold))),
                        IconButton(onPressed: _copyCsv, icon: const Icon(Icons.copy), tooltip: 'Copiar CSV'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SelectableText(
                        _csv,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('Escolha o tipo de exportação e toque em Gerar CSV.', style: TextStyle(color: Colors.grey)),
              ),
            ),
        ],
      ),
    );
  }
}
