import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'session_provider.dart';

class AppLifecycleObserver extends WidgetsBindingObserver {
  final WidgetRef ref;
  int? _backgroundedAt;

  AppLifecycleObserver(this.ref);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // App going to background — record timestamp
        _backgroundedAt = DateTime.now().millisecondsSinceEpoch;
        ref.read(sessionProvider.notifier).updateActivity();
        break;
        
      case AppLifecycleState.resumed:
        // App coming back — check elapsed time
        if (_backgroundedAt != null) {
          final elapsed = DateTime.now().millisecondsSinceEpoch - _backgroundedAt!;
          if (elapsed > 15 * 60 * 1000) { // 15 minutes
            ref.read(sessionProvider.notifier).lockSession();
          }
        }
        _backgroundedAt = null;
        break;
        
      case AppLifecycleState.detached:
        // App process killed — session memory gone. Rely on SQLite state next launch.
        break;
        
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Briefly inactive or hidden (phone call, etc.) — do not lock
        break;
    }
  }
}
