import 'package:diasorganize/data/models/financial_category_model.dart';
import 'package:diasorganize/data/models/financial_subcategory_model.dart';
import 'package:diasorganize/data/models/transaction_model.dart';
import 'package:diasorganize/features/finance/finance_screen_data.dart';
import 'package:flutter_test/flutter_test.dart';

FinancialTransaction tx({
  required String title,
  required double amount,
  int? categoryId,
  int? subcategoryId,
  String status = 'pending',
}) {
  return FinancialTransaction(
    title: title,
    amount: amount,
    type: 'expense',
    transactionDate: '2026-04-10T00:00:00.000',
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    status: status,
    createdAt: '2026-04-01T00:00:00.000',
    updatedAt: '2026-04-01T00:00:00.000',
  );
}

void main() {
  group('FinanceScreenData with subcategories', () {
    final category = FinancialCategory(
      id: 1,
      name: 'Transporte',
      type: 'expense',
      color: '0xFF2196F3',
      icon: 'directions_car',
      createdAt: '2026-04-01T00:00:00.000',
      updatedAt: '2026-04-01T00:00:00.000',
    );
    final uber = FinancialSubcategory(
      id: 10,
      categoryId: 1,
      name: 'Uber',
      createdAt: '2026-04-01T00:00:00.000',
      updatedAt: '2026-04-01T00:00:00.000',
    );
    final bus = FinancialSubcategory(
      id: 11,
      categoryId: 1,
      name: 'Ônibus',
      createdAt: '2026-04-01T00:00:00.000',
      updatedAt: '2026-04-01T00:00:00.000',
    );

    test('filtra transações por subcategoria', () {
      final data = FinanceScreenData.build(
        selectedMonth: DateTime(2026, 4, 1),
        transactions: [
          tx(title: 'Corrida app', amount: 40, categoryId: 1, subcategoryId: 10),
          tx(title: 'Passagem', amount: 8, categoryId: 1, subcategoryId: 11),
        ],
        categories: [category],
        subcategories: [uber, bus],
        debts: const [],
        filterType: 'all',
        filterStatus: 'all',
        filterCategory: null,
        filterSubcategory: 10,
        searchQuery: '',
      );

      expect(data.filteredTransactions.length, 1);
      expect(data.filteredTransactions.first.title, 'Corrida app');
    });

    test('busca textual encontra nome da subcategoria', () {
      final data = FinanceScreenData.build(
        selectedMonth: DateTime(2026, 4, 1),
        transactions: [
          tx(title: 'Corrida app', amount: 40, categoryId: 1, subcategoryId: 10),
          tx(title: 'Passagem', amount: 8, categoryId: 1, subcategoryId: 11),
        ],
        categories: [category],
        subcategories: [uber, bus],
        debts: const [],
        filterType: 'all',
        filterStatus: 'all',
        filterCategory: null,
        filterSubcategory: null,
        searchQuery: 'uber',
      );

      expect(data.filteredTransactions.length, 1);
      expect(data.filteredTransactions.first.subcategoryId, 10);
    });

    test('identifica maior subcategoria de gasto pago', () {
      final data = FinanceScreenData.build(
        selectedMonth: DateTime(2026, 4, 1),
        transactions: [
          tx(title: 'Corrida 1', amount: 40, categoryId: 1, subcategoryId: 10, status: 'paid'),
          tx(title: 'Corrida 2', amount: 50, categoryId: 1, subcategoryId: 10, status: 'paid'),
          tx(title: 'Passagem', amount: 8, categoryId: 1, subcategoryId: 11, status: 'paid'),
        ],
        categories: [category],
        subcategories: [uber, bus],
        debts: const [],
        filterType: 'all',
        filterStatus: 'all',
        filterCategory: null,
        filterSubcategory: null,
        searchQuery: '',
      );

      expect(data.topExpenseSubcategory?.name, 'Uber');
      expect(data.summary.topExpenseSubcategoryAmount, 90);
    });
  });
}
