import 'dart:convert';

class InvoiceListFilterState {
  const InvoiceListFilterState({
    this.searchQuery = '',
    this.statusFilter = 'all',
    this.paymentFilter = 'all',
    this.currencyFilter = 'all',
    this.dateFilter = 'all',
    this.customFromDate,
    this.customToDate,
    this.discountOnly = false,
    this.sortField = 'date',
    this.sortAscending = false,
  });

  static const defaults = InvoiceListFilterState();
  static const _unset = Object();

  final String searchQuery;
  final String statusFilter;
  final String paymentFilter;
  final String currencyFilter;
  final String dateFilter;
  final DateTime? customFromDate;
  final DateTime? customToDate;
  final bool discountOnly;
  final String sortField;
  final bool sortAscending;

  bool get hasActiveFilters {
    return searchQuery.isNotEmpty ||
        statusFilter != defaults.statusFilter ||
        paymentFilter != defaults.paymentFilter ||
        currencyFilter != defaults.currencyFilter ||
        dateFilter != defaults.dateFilter ||
        customFromDate != null ||
        customToDate != null ||
        discountOnly != defaults.discountOnly ||
        sortField != defaults.sortField ||
        sortAscending != defaults.sortAscending;
  }

  InvoiceListFilterState copyWith({
    String? searchQuery,
    String? statusFilter,
    String? paymentFilter,
    String? currencyFilter,
    String? dateFilter,
    Object? customFromDate = _unset,
    Object? customToDate = _unset,
    bool? discountOnly,
    String? sortField,
    bool? sortAscending,
  }) {
    return InvoiceListFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      paymentFilter: paymentFilter ?? this.paymentFilter,
      currencyFilter: currencyFilter ?? this.currencyFilter,
      dateFilter: dateFilter ?? this.dateFilter,
      customFromDate: identical(customFromDate, _unset)
          ? this.customFromDate
          : customFromDate as DateTime?,
      customToDate: identical(customToDate, _unset)
          ? this.customToDate
          : customToDate as DateTime?,
      discountOnly: discountOnly ?? this.discountOnly,
      sortField: sortField ?? this.sortField,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'searchQuery': searchQuery,
      'statusFilter': statusFilter,
      'paymentFilter': paymentFilter,
      'currencyFilter': currencyFilter,
      'dateFilter': dateFilter,
      'customFromDate': customFromDate?.toIso8601String(),
      'customToDate': customToDate?.toIso8601String(),
      'discountOnly': discountOnly,
      'sortField': sortField,
      'sortAscending': sortAscending,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory InvoiceListFilterState.fromJsonString(String? rawValue) {
    if (rawValue == null || rawValue.isEmpty) {
      return defaults;
    }

    try {
      final data = jsonDecode(rawValue) as Map<String, dynamic>;
      return InvoiceListFilterState(
        searchQuery: data['searchQuery'] as String? ?? defaults.searchQuery,
        statusFilter: data['statusFilter'] as String? ?? defaults.statusFilter,
        paymentFilter:
            data['paymentFilter'] as String? ?? defaults.paymentFilter,
        currencyFilter:
            data['currencyFilter'] as String? ?? defaults.currencyFilter,
        dateFilter: data['dateFilter'] as String? ?? defaults.dateFilter,
        customFromDate: _parseDate(data['customFromDate'] as String?),
        customToDate: _parseDate(data['customToDate'] as String?),
        discountOnly: data['discountOnly'] as bool? ?? defaults.discountOnly,
        sortField: data['sortField'] as String? ?? defaults.sortField,
        sortAscending: data['sortAscending'] as bool? ?? defaults.sortAscending,
      );
    } catch (_) {
      return defaults;
    }
  }

  static DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }
}
