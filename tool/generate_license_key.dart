// ignore_for_file: avoid_print

import 'dart:io';

import 'package:mada_pos/core/constants/app_constants.dart';
import 'package:mada_pos/core/license/license_service.dart';

/// Vendor tool: generate a license key for a customer device ID.
/// Usage: dart run tool/generate_license_key.dart DEVICE_ID
void main(List<String> args) {
  if (args.isEmpty) {
    print('Usage: dart run tool/generate_license_key.dart <DEVICE_ID>');
    print('');
    print('The customer copies Device ID from the activation screen.');
    print('Secret: ${AppConstants.licenseSecret} (change in app_constants.dart)');
    exit(1);
  }

  final deviceId = args.first.trim().toUpperCase();
  final key = LicenseService.generateKeyForDevice(deviceId);
  print('Device ID: $deviceId');
  print('License key: $key');
}
