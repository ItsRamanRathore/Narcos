import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/database/database_service.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../auth/providers/session_provider.dart';
import '../../auth/domain/auth_repository.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final SecureStorageService _secureStorage = SecureStorageService();
  final LocalAuthentication _localAuth = LocalAuthentication();
  
  Map<String, dynamic>? _operatorData;
  bool _biometricEnabled = false;
  bool _canCheckBiometrics = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final session = ref.read(sessionProvider);
    final operatorId = session.operatorId;
    if (operatorId == null) return;

    final db = await DatabaseService().database;
    final result = await db.query('credentials', where: 'operator_id = ?', whereArgs: [operatorId]);
    
    if (result.isNotEmpty) {
      final canAuth = await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
      final hasBiometricKey = await _secureStorage.hasBiometricWrapKey(operatorId);
      
      setState(() {
        _operatorData = result.first;
        _canCheckBiometrics = canAuth;
        _biometricEnabled = hasBiometricKey;
      });
    }
  }

  Future<void> _toggleBiometrics(bool enable) async {
    final session = ref.read(sessionProvider);
    final operatorId = session.operatorId;
    final wrapKey = session.wrapKey;
    if (operatorId == null || wrapKey == null) return;

    if (enable) {
      final success = await _secureStorage.enrollBiometricWrapKey(operatorId, wrapKey);
      if (success) {
        setState(() => _biometricEnabled = true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometrics enabled')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to enable biometrics')));
      }
    } else {
      await _secureStorage.clearBiometricWrapKey(operatorId);
      setState(() => _biometricEnabled = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biometrics disabled')));
    }
  }

  Future<void> _showChangePinDialog() async {
    final session = ref.read(sessionProvider);
    final operatorId = session.operatorId;
    if (operatorId == null) return;

    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();

    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        bool isSubmitting = false;
        String? errorMessage;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Change PIN'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorMessage != null)
                      Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                    TextFormField(
                      controller: oldPinController,
                      decoration: const InputDecoration(labelText: 'Current PIN'),
                      obscureText: true,
                      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                    ),
                    TextFormField(
                      controller: newPinController,
                      decoration: const InputDecoration(labelText: 'New PIN'),
                      obscureText: true,
                      validator: (v) => v == null || v.length < 6 ? 'Min 6 chars' : null,
                    ),
                    TextFormField(
                      controller: confirmPinController,
                      decoration: const InputDecoration(labelText: 'Confirm New PIN'),
                      obscureText: true,
                      validator: (v) => v != newPinController.text ? 'Does not match' : null,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setStateDialog(() {
                            isSubmitting = true;
                            errorMessage = null;
                          });

                          try {
                            final authRepo = AuthRepository();
                            final newWrapKey = await authRepo.changePin(
                              operatorId: operatorId,
                              oldPin: oldPinController.text,
                              newPin: newPinController.text,
                            );

                            // Update session with new wrap key
                            await ref.read(sessionProvider.notifier).establishSession(operatorId, newWrapKey);

                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('PIN changed successfully!')),
                              );
                              // Biometrics are disabled upon PIN change for security.
                              if (_biometricEnabled) {
                                this.setState(() => _biometricEnabled = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Biometrics disabled. Please re-enable them.')),
                                );
                              }
                            }
                          } catch (e) {
                            setStateDialog(() {
                              isSubmitting = false;
                              errorMessage = e.toString();
                            });
                          }
                        },
                  child: isSubmitting ? const CircularProgressIndicator() : const Text('Change PIN'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_operatorData == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CircleAvatar(
            radius: 50,
            child: Icon(Icons.person, size: 50),
          ),
          const SizedBox(height: 16),
          Text(
            _operatorData!['name'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          Text(
            _operatorData!['operator_id'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.badge),
            title: const Text('Rank'),
            subtitle: Text(_operatorData!['rank'] as String? ?? 'N/A'),
          ),
          ListTile(
            leading: const Icon(Icons.location_on),
            title: const Text('Jurisdiction'),
            subtitle: Text(_operatorData!['jurisdiction'] as String? ?? 'N/A'),
          ),
          const Divider(),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: const Text('Biometric Unlock'),
            subtitle: Text(_canCheckBiometrics ? 'Use biometrics to login' : 'Not supported on this device'),
            value: _biometricEnabled,
            onChanged: _canCheckBiometrics ? _toggleBiometrics : null,
          ),
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text('Change PIN'),
            onTap: _showChangePinDialog,
          ),
        ],
      ),
    );
  }
}
