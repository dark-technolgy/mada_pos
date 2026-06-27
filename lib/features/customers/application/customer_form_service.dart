import 'package:drift/drift.dart' show Value;

import '../../../core/database/database.dart';

class CustomerFormPayload {
  const CustomerFormPayload({
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
    required this.isActive,
  });

  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
  final bool isActive;
}

class CustomerFormService {
  const CustomerFormService();

  Future<Customer?> loadCustomer(AppDatabase db, int customerId) {
    return (db.select(
      db.customers,
    )..where((customer) => customer.id.equals(customerId))).getSingleOrNull();
  }

  Future<void> saveCustomer(
    AppDatabase db, {
    required CustomerFormPayload payload,
    int? customerId,
  }) async {
    if (customerId != null) {
      await (db.update(
        db.customers,
      )..where((customer) => customer.id.equals(customerId))).write(
        CustomersCompanion(
          name: Value(payload.name),
          phone: Value(payload.phone),
          email: Value(payload.email),
          address: Value(payload.address),
          notes: Value(payload.notes),
          isActive: Value(payload.isActive),
          updatedAt: Value(DateTime.now()),
        ),
      );
      return;
    }

    await db
        .into(db.customers)
        .insert(
          CustomersCompanion.insert(
            name: payload.name,
            phone: Value(payload.phone),
            email: Value(payload.email),
            address: Value(payload.address),
            notes: Value(payload.notes),
            isActive: Value(payload.isActive),
          ),
        );
  }
}
