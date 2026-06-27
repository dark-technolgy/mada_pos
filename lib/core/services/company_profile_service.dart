import '../database/database.dart';

class CompanyProfile {
  const CompanyProfile({
    required this.name,
    required this.phone,
    required this.address,
    this.logoPath,
  });

  final String name;
  final String phone;
  final String address;
  final String? logoPath;
}

class CompanyProfileService {
  const CompanyProfileService();

  Future<CompanyProfile> load(AppDatabase db) async {
    final rows = await db.select(db.settings).get();
    final map = {for (final row in rows) row.key: row.value};

    return CompanyProfile(
      name: map['company_name'] ?? 'Mada Smart POS',
      phone: map['company_phone'] ?? '',
      address: map['company_address'] ?? '',
      logoPath: map['company_logo_path'],
    );
  }
}
