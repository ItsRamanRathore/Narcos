import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:safe_device/safe_device.dart';
import 'package:opencv_dart/opencv_dart.dart' as cv;

import 'core/storage/sandbox_storage_service.dart';

import 'core/database/database_service.dart';
import 'core/theme/app_theme.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqflite;
import 'core/routing/router.dart';

// Buffer to store errors if DB is not ready
final List<FlutterErrorDetails> _errorBuffer = [];

void _logErrorToDb(FlutterErrorDetails details) async {
  try {
    final db = await DatabaseService().database.timeout(const Duration(seconds: 2));
    
    // Flush buffer if any
    for (final err in _errorBuffer) {
      await db.insert('audit_log', {
        'operator_id': null,
        'action': 'flutter_error',
        'detail': jsonEncode({
          'error': err.exceptionAsString(),
          'library': err.library,
        }),
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    }
    _errorBuffer.clear();

    await db.insert('audit_log', {
      'operator_id': null,
      'action': 'flutter_error',
      'detail': jsonEncode({
        'error': details.exceptionAsString(),
        'library': details.library,
      }),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  } catch (_) {
    _errorBuffer.add(details);
  }
}

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      
      // WIPE CORRUPTED DB ON EMULATOR
      try {
        final dbPath = await sqflite.getDatabasesPath();
        final path = [dbPath, 'narcos.db'].join('/');
        await sqflite.deleteDatabase(path);
      } catch (e) {
        debugPrint('Could not delete db: \$e');
      }
      
      DatabaseService.onDbOpen.add((db) async {
        if (_errorBuffer.isEmpty) return;
        final batch = db.batch();
        for (final err in _errorBuffer) {
          batch.insert('audit_log', {
            'operator_id': null,
            'action': 'flutter_error',
            'detail': jsonEncode({
              'error': err.exceptionAsString(),
              'library': err.library,
            }),
            'created_at': DateTime.now().millisecondsSinceEpoch,
          });
        }
        await batch.commit(noResult: true);
        _errorBuffer.clear();
      });

      // Cleanup stale temp captures on launch
      await SandboxStorageService().cleanupStaleTempCaptures();
      
      FlutterError.onError = (FlutterErrorDetails details) {
        debugPrint('FlutterError: ${details.exceptionAsString()}');
        _logErrorToDb(details);
        FlutterError.presentError(details);
      };

      PlatformDispatcher.instance.onError = (error, stack) {
        final details = FlutterErrorDetails(exception: error, stack: stack, library: 'platform_dispatcher');
        _logErrorToDb(details);
        return true;
      };
      
      runApp(const ProviderScope(child: ForensIQApp()));
    },
    (error, stack) {
      debugPrint('Uncaught error: $error\\n$stack');
      final details = FlutterErrorDetails(exception: error, stack: stack, library: 'runZonedGuarded');
      _logErrorToDb(details);
    },
  );
}

class ForensIQApp extends ConsumerStatefulWidget {
  const ForensIQApp({super.key});

  @override
  ConsumerState<ForensIQApp> createState() => _ForensIQAppState();
}

class _ForensIQAppState extends ConsumerState<ForensIQApp> {
  bool _isJailbroken = false;

  @override
  void initState() {
    super.initState();
    _checkJailbreak();
  }

  Future<void> _checkJailbreak() async {
    try {
      final isJailbroken = await SafeDevice.isJailBroken;
      final isDeveloperMode = await SafeDevice.isDevelopmentModeEnable;
      setState(() {
        _isJailbroken = isJailbroken || isDeveloperMode;
      });
    } catch (e) {
      // Ignore or log error
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'ForensIQ',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.dark, // Enforce dark mode by default
      routerConfig: router,
      builder: (context, child) {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              children: [
                if (_isJailbroken)
                  Container(
                    color: Colors.red,
                    width: double.infinity,
                    padding: const EdgeInsets.only(top: 40, bottom: 10),
                    child: const SafeArea(
                      bottom: false,
                      child: Text(
                        'WARNING: Device integrity compromised (Root/Jailbreak detected)',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                Expanded(child: child!),
              ],
            ),
          ),
        );
      },
    );
  }
}
