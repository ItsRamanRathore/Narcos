import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ReachabilityState {
  unknown,
  online,
  offline,
}

class ReachabilityNotifier extends Notifier<ReachabilityState> {
  final Connectivity _connectivity = Connectivity();
  Timer? _reachabilityTimer;
  StreamSubscription? _connectivitySubscription;

  @override
  ReachabilityState build() {
    // Check reachability immediately on init
    _checkReachability();

    // Start 30-second polling
    _startTimer();

    // Listen to network interface changes
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _checkReachability();
    });

    ref.onDispose(() {
      _reachabilityTimer?.cancel();
      _connectivitySubscription?.cancel();
    });

    return ReachabilityState.unknown;
  }

  void _startTimer() {
    _reachabilityTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkReachability(),
    );
  }

  Future<void> _checkReachability() async {
    try {
      final results = await _connectivity.checkConnectivity();
      if (!results.contains(ConnectivityResult.none)) {
        state = ReachabilityState.online;
      } else {
        state = ReachabilityState.offline;
      }
    } catch (_) {
      state = ReachabilityState.offline;
    }
  }
}

final reachabilityStateProvider = NotifierProvider<ReachabilityNotifier, ReachabilityState>(() {
  return ReachabilityNotifier();
});
