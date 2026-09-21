import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
// Removed flutter_lucide import

import '../domain/auth_repository.dart';
import '../providers/session_provider.dart';
import '../../../core/security/secure_storage_service.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _pinController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Gradient/Mesh
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0B0B1A), Color(0xFF16162C), Color(0xFF000000)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          
          // Floating glowing orbs for background effect
          Positioned(
            top: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).primaryColor.withOpacity(0.15),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .scale(duration: 4.seconds, begin: const Offset(1, 1), end: const Offset(1.2, 1.2)),
          ),
          Positioned(
            bottom: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
              ),
            ).animate(onPlay: (controller) => controller.repeat(reverse: true))
             .scale(duration: 5.seconds, begin: const Offset(1, 1), end: const Offset(1.3, 1.3)),
          ),
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Icon(Icons.fingerprint, size: 80, color: Theme.of(context).primaryColor)
                        .animate(onPlay: (controller) => controller.repeat(reverse: true))
                        .shimmer(duration: 2.seconds, color: Colors.white)
                        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 2.seconds, curve: Curves.easeInOut),
                      const SizedBox(height: 16),
                      Text(
                        'ForensIQ',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          letterSpacing: 8,
                        ),
                      ).animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),
                      Text(
                        'FIELD APP',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).primaryColor,
                          letterSpacing: 4,
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2),
                      
                      const SizedBox(height: 48),

                      // Glassmorphism Card
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.1)),
                            ),
                            child: Column(
                              children: [
                                if (_errorMessage != null)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    margin: const EdgeInsets.only(bottom: 16),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                                        const SizedBox(width: 8),
                                        Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent))),
                                      ],
                                    ),
                                    ).animate().fadeIn().shake(hz: 4),

                                TextFormField(
                                  controller: _idController,
                                  decoration: const InputDecoration(
                                    labelText: 'Operator ID',
                                    prefixIcon: Icon(Icons.person),
                                  ),
                                  textCapitalization: TextCapitalization.characters,
                                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                                ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),
                                
                                const SizedBox(height: 16),
                                
                                TextFormField(
                                  controller: _pinController,
                                  decoration: const InputDecoration(
                                    labelText: 'PIN',
                                    prefixIcon: Icon(Icons.lock),
                                  ),
                                  keyboardType: TextInputType.number,
                                  obscureText: true,
                                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                                ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1),
                                
                                const SizedBox(height: 32),
                                
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  child: _isLoading
                                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                      : const Text('INITIALIZE'),
                                ).animate().fadeIn(delay: 600.ms).scale(),
                                
                                const SizedBox(height: 24),
                                
                                InkWell(
                                  onTap: _isLoading ? null : _biometricLogin,
                                  borderRadius: BorderRadius.circular(16),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.face, color: Theme.of(context).primaryColor),
                                        const SizedBox(width: 8),
                                        Text('BIOMETRIC UNLOCK', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                                      ],
                                    ),
                                  ),
                                ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () {
                                    if (context.mounted) {
                                      context.go('/registration');
                                    }
                                  },
                                  child: const Text("Don't have an account? Register"),
                                ).animate().fadeIn(delay: 800.ms),
                              ],
                            ),
                          ),
                        ),
                      ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final authRepo = AuthRepository();
      final operatorId = _idController.text.toUpperCase();
      final wrapKey = await authRepo.login(operatorId, _pinController.text);
      await ref.read(sessionProvider.notifier).establishSession(operatorId, wrapKey);
      final secureStorage = SecureStorageService();
      await secureStorage.enrollBiometricWrapKey(operatorId, wrapKey);
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _biometricLogin() async {
    final operatorId = _idController.text.toUpperCase();
    if (operatorId.isEmpty) {
      setState(() => _errorMessage = 'Enter Operator ID first to use biometrics');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final secureStorage = SecureStorageService();
      final wrapKey = await secureStorage.getBiometricWrapKey(operatorId);
      if (wrapKey != null) {
        await ref.read(sessionProvider.notifier).establishSession(operatorId, wrapKey);
      } else {
        setState(() => _errorMessage = 'Biometric unlock failed or not enrolled. Please use PIN.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Biometrics error: \$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
