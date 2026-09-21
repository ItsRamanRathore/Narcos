import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// Removed flutter_lucide import
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/widgets/offline_indicator.dart';
import '../auth/providers/session_provider.dart';
import '../dashboard/presentation/dashboard_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final role = session.role ?? 'OPERATOR';

    final tabs = _getTabsForRole(role);
    final pages = _getPagesForRole(role);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('ForensIQ', style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(sessionProvider.notifier).logout();
            },
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B0B1A), Color(0xFF05050C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          Column(
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 56), // AppBar spacing
              const OfflineIndicator(),
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: pages,
                ),
              ),
            ],
          ),
          
          // Floating Glass Nav Bar
          Positioned(
            bottom: 32,
            left: 24,
            right: 24,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(tabs.length, (index) {
                      final isSelected = _currentIndex == index;
                      final item = tabs[index];
                      return GestureDetector(
                        onTap: () => setState(() => _currentIndex = index),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedContainer(
                          duration: 300.ms,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                color: isSelected ? Theme.of(context).primaryColor : Colors.white54,
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ).animate().fadeIn().slideX(begin: 0.2),
                              ]
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ).animate().slideY(begin: 1.0, curve: Curves.easeOutCirc, duration: 800.ms),
          ),
        ],
      ),
    );
  }

  List<_NavItem> _getTabsForRole(String role) {
    final base = [
      _NavItem(icon: Icons.camera_alt, label: 'Capture'),
      _NavItem(icon: Icons.list, label: 'Log'),
    ];
    if (role == 'SUPERVISOR' || role == 'ADMIN') {
      base.add(_NavItem(icon: Icons.dashboard, label: 'Dashboard'));
    }
    return base;
  }

  List<Widget> _getPagesForRole(String role) {
    final base = <Widget>[
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.3)),
              ),
              child: Icon(Icons.qr_code_scanner, size: 64, color: Theme.of(context).primaryColor),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .scale(duration: 2.seconds, begin: const Offset(1, 1), end: const Offset(1.1, 1.1)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.push('/capture'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
              ),
              child: const Text('START CAPTURE'),
            ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
          ],
        ),
      ),
      Center(child: Text('Log Screen Placeholder', style: Theme.of(context).textTheme.titleLarge)),
    ];

    if (role == 'SUPERVISOR' || role == 'ADMIN') {
      base.add(const DashboardScreen());
    }

    return base;
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  _NavItem({required this.icon, required this.label});
}
