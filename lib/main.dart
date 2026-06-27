import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:window_manager/window_manager.dart';
import 'app.dart';
import 'core/constants/app_constants.dart';
import 'core/logging/app_logger.dart';
import 'core/setup/windows_prerequisites.dart';
import 'features/backup/application/auto_backup_service.dart';
import 'shared/providers/app_providers.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  await AppLogger.init();
  await WindowsPrerequisites.ensureInstalled();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      AppLogger.log(
        'FlutterError: ${details.exceptionAsString()}',
        error: details.exception,
        stackTrace: details.stack,
      ),
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(AppLogger.log('Uncaught error', error: error, stackTrace: stack));
    return true;
  };

  // Window configuration for desktop
  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1400, 900),
    minimumSize: Size(1100, 700),
    center: true,
    title: 'Mada Smart POS - مدى للمبيعات الذكية',
    backgroundColor: Colors.transparent,
    titleBarStyle: TitleBarStyle.normal,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const ProviderScope(child: WindowCloseHandler(child: MadaApp())));
}

class WindowCloseHandler extends ConsumerStatefulWidget {
  const WindowCloseHandler({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<WindowCloseHandler> createState() => _WindowCloseHandlerState();
}

class _WindowCloseHandlerState extends ConsumerState<WindowCloseHandler>
    with WindowListener {
  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    windowManager.setPreventClose(true);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    final db = ref.read(databaseProvider);
    // Runs a backup on close if enabled in settings, ignoring the time interval
    await const AutoBackupService().runIfDue(db, ignoreInterval: true);
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
