import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SUPERVISOR DASHBOARD',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 24),
          
          // Stats Row
          Row(
            children: [
              Expanded(child: _buildStatCard(context, 'Total Scans', '142', Icons.analytics, Colors.blue)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(context, 'Positives', '38', Icons.warning_amber_rounded, Colors.orange)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatCard(context, 'Inconclusive', '12', Icons.help_outline, Colors.grey)),
              const SizedBox(width: 16),
              Expanded(child: _buildStatCard(context, 'Alerts', '3', Icons.notifications_active, Colors.red)),
            ],
          ),
          
          const SizedBox(height: 32),
          Text(
            'RECENT ACTIVITY',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          
          _buildActivityItem(context, 'DL-001', 'Cocaine Detected', '2 mins ago', Colors.orange),
          _buildActivityItem(context, 'DL-045', 'Negative Result', '15 mins ago', Colors.green),
          _buildActivityItem(context, 'NY-112', 'Inconclusive (Low Confidence)', '1 hour ago', Colors.grey),
          
          const SizedBox(height: 32),
          Text(
            'KIT INVENTORY STATUS',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildInventoryItem(context, 'Marquis Reagent (V1)', 45, 100),
          _buildInventoryItem(context, 'Mecke Reagent', 12, 100, isLow: true),
          
          const SizedBox(height: 80), // spacing for bottom nav
        ],
      ),
    );
  }

  Widget _buildStatCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildActivityItem(BuildContext context, String operatorId, String action, String time, Color statusColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: statusColor.withOpacity(0.2),
            child: Icon(Icons.person, color: statusColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Operator \$operatorId', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                Text(action, style: TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
          Text(time, style: TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }
  
  Widget _buildInventoryItem(BuildContext context, String name, int count, int total, {bool isLow = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: Colors.white)),
              Text('\$count / \$total', style: TextStyle(color: isLow ? Colors.redAccent : Colors.white70, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: count / total,
            backgroundColor: Colors.white.withOpacity(0.1),
            color: isLow ? Colors.redAccent : Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}
