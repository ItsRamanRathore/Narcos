import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database_service.dart';
import '../../core/routing/router.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _steps = [
    {
      'title': 'Setup Dual Zones',
      'body': 'Place the reference card in the upper zone, and the test kit in the lower zone.',
      'icon': 'dashboard_customize'
    },
    {
      'title': 'Quality Gates',
      'body': 'Wait for the blur, lighting, and card detection indicators to turn green before capturing.',
      'icon': 'fact_check'
    },
    {
      'title': 'Trust & Security',
      'body': 'Your result is cryptographically signed and GPS-stamped automatically. No manual entry needed.',
      'icon': 'security'
    },
    {
      'title': 'Offline Sync',
      'body': 'Records sync automatically when connected. An offline indicator will show pending records in the field.',
      'icon': 'cloud_sync'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome'),
        actions: [
          TextButton(
            onPressed: _completeOnboarding,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _steps.length,
              itemBuilder: (context, index) {
                final step = _steps[index];
                return Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getIconForStep(step['icon']!),
                        size: 100,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 48),
                      Text(
                        step['title']!,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        step['body']!,
                        style: const TextStyle(fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: List.generate(
                    _steps.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                      ),
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(120, 56),
                  ),
                  onPressed: () {
                    if (_currentPage == _steps.length - 1) {
                      _completeOnboarding();
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Text(_currentPage == _steps.length - 1 ? 'Get Started' : 'Next'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForStep(String iconName) {
    switch (iconName) {
      case 'dashboard_customize':
        return Icons.dashboard_customize;
      case 'fact_check':
        return Icons.fact_check;
      case 'security':
        return Icons.security;
      case 'cloud_sync':
        return Icons.cloud_sync;
      default:
        return Icons.info;
    }
  }

  Future<void> _completeOnboarding() async {
    final dbService = DatabaseService();
    final db = await dbService.database;
    await db.update(
      'app_preferences',
      {'value': '1'},
      where: 'key = ?',
      whereArgs: ['onboarding_complete'],
    );
    // Refresh router
    if (mounted) {
      context.go('/home'); // Force navigation to home, guard will also let it pass now
    }
  }
}
