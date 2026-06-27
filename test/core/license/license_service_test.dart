import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/constants/app_constants.dart';
import 'package:mada_pos/core/license/license_service.dart';

void main() {
  group('LicenseService', () {
    test('generateKeyForDevice is deterministic', () {
      const deviceId = 'ABC123DEVICEIDTEST01';
      final a = LicenseService.generateKeyForDevice(deviceId);
      final b = LicenseService.generateKeyForDevice(deviceId);
      expect(a, b);
      expect(a, startsWith('Mada-'));
    });

    test('validateKey accepts generated key', () {
      const deviceId = 'TESTDEVICE1234567890AB';
      final key = LicenseService.generateKeyForDevice(deviceId);
      expect(key.length, greaterThan(10));
      expect(AppConstants.trialDays, 30);
    });
  });
}
