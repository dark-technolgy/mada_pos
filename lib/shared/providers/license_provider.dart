import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/license/license_service.dart';
import 'app_providers.dart';

final licenseInfoProvider = FutureProvider<LicenseInfo>((ref) async {
  final db = ref.watch(databaseProvider);
  return const LicenseService().load(db);
});
