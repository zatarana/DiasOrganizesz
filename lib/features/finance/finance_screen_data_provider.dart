import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/providers.dart';
import 'finance_screen_data.dart';

class FinanceScreenFilters {
  final DateTime selectedMonth;
  final String filterType;
  final String filterStatus;
  final int? filterCategory;
  final String searchQuery;

  const FinanceScreenFilters({
    required this.selectedMonth,
    required this.filterType,
    required this.filterStatus,
    required this.filterCategory,
    required this.searchQuery,
  });

  FinanceScreenFilters copyWith({
    DateTime? selectedMonth,
    String? filterType,
    String? filterStatus,
    int? filterCategory,
    bool clearFilterCategory = false,
    String? searchQuery,
  }) {
    return FinanceScreenFilters(
      selectedMonth: selectedMonth ?? this.selectedMonth,
      filterType: filterType ?? this.filterType,
      filterStatus: filterStatus ?? this.filterStatus,
      filterCategory: clearFilterCategory ? null : (filterCategory ?? this.filterCategory),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FinanceScreenFilters &&
        other.selectedMonth.year == selectedMonth.year &&
        other.selectedMonth.month == selectedMonth.month &&
        other.filterType == filterType &&
        other.filterStatus == filterStatus &&
        other.filterCategory == filterCategory &&
        other.searchQuery == searchQuery;
  }

  @override
  int get hashCode => Object.hash(
        selectedMonth.year,
        selectedMonth.month,
        filterType,
        filterStatus,
        filterCategory,
        searchQuery,
      );
}

final financeScreenDataProvider = Provider.family<FinanceScreenData, FinanceScreenFilters>((ref, filters) {
  final transactions = ref.watch(transactionsProvider);
  final categories = ref.watch(financialCategoriesProvider);
  final debts = ref.watch(debtsProvider);

  return FinanceScreenData.build(
    selectedMonth: filters.selectedMonth,
    transactions: transactions,
    categories: categories,
    debts: debts,
    filterType: filters.filterType,
    filterStatus: filters.filterStatus,
    filterCategory: filters.filterCategory,
    searchQuery: filters.searchQuery,
  );
});
