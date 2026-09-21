import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/auth_repository.dart';
import '../providers/session_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:go_router/go_router.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _rankController = TextEditingController();
  final _jurisdictionController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Operator Registration')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.red.shade100,
                    child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                  ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _idController,
                  decoration: const InputDecoration(
                    labelText: 'Operator ID',
                    hintText: 'e.g. DL-001',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (!RegExp(r'^[A-Z]{2,}-\d+$').hasMatch(value)) {
                      return 'Format must be JURISDICTION-NUMBER (e.g. DL-001)';
                    }
                    if (value.length > 12) return 'Max 12 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _rankController,
                  decoration: const InputDecoration(
                    labelText: 'Rank',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _jurisdictionController,
                  decoration: const InputDecoration(
                    labelText: 'Jurisdiction Code',
                    hintText: 'e.g. DL',
                    border: OutlineInputBorder(),
                  ),
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _pinController,
                  decoration: const InputDecoration(
                    labelText: 'PIN (Min 6 digits)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  validator: _validatePIN,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPinController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm PIN',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  validator: (value) {
                    if (value != _pinController.text) return 'PINs do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator()
                      : const Text('Register & Secure Key'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    if (context.mounted) {
                      context.go('/login');
                    }
                  },
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _validatePIN(String? value) {
    if (value == null || value.length < 6) return 'Minimum 6 digits required';
    if (!RegExp(r'^\d+$').hasMatch(value)) return 'Must contain only digits';
    
    // No run of 3+ identical digits
    for (int i = 0; i < value.length - 2; i++) {
      if (value[i] == value[i+1] && value[i+1] == value[i+2]) {
        return 'Cannot contain 3 identical consecutive digits (e.g. 111)';
      }
    }
    
    // No run of 3+ sequential digits
    for (int i = 0; i < value.length - 2; i++) {
      final a = int.parse(value[i]);
      final b = int.parse(value[i+1]);
      final c = int.parse(value[i+2]);
      if (b == a + 1 && c == b + 1) return 'Cannot contain sequential digits (e.g. 123)';
      if (b == a - 1 && c == b - 1) return 'Cannot contain sequential digits (e.g. 321)';
    }
    
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = AuthRepository();
      
      final wrapKey = await authRepo.registerOperator(
        operatorId: _idController.text.toUpperCase(),
        name: _nameController.text,
        rank: _rankController.text,
        jurisdiction: _jurisdictionController.text.toUpperCase(),
        pin: _pinController.text,
      );

      // Session established
      await ref.read(sessionProvider.notifier).establishSession(_idController.text.toUpperCase(), wrapKey);
      
      // We will rebuild the app root because firstRunProvider will update (or auth state will change)
      // We also trigger a reload if needed, but sessionProvider should trigger router.
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
