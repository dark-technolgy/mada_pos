import 'package:drift/drift.dart' show OrderingTerm;

import '../../../core/database/database.dart';

class CustomersService {
  const CustomersService();

  Future<List<Customer>> loadCustomers(AppDatabase db) {
    return (db.select(
      db.customers,
    )..orderBy([(customer) => OrderingTerm.asc(customer.name)])).get();
  }

  List<Customer> filterCustomers({
    required List<Customer> customers,
    required String searchQuery,
  }) {
    final normalizedQuery = searchQuery.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return customers.toList(growable: false);
    }

    return customers
        .where((customer) {
          return customer.name.toLowerCase().contains(normalizedQuery) ||
              (customer.phone?.toLowerCase().contains(normalizedQuery) ??
                  false) ||
              (customer.email?.toLowerCase().contains(normalizedQuery) ??
                  false);
        })
        .toList(growable: false);
  }

  Future<void> deleteCustomer(AppDatabase db, int customerId) {
    return (db.delete(
      db.customers,
    )..where((customer) => customer.id.equals(customerId))).go();
  }
}
