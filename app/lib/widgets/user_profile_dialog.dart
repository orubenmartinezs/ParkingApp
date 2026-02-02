import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_models.dart';
import '../services/auth_service.dart';
import '../database/database_helper.dart';
import '../services/sync_service.dart';

class UserProfileDialog extends StatefulWidget {
  final User user;

  const UserProfileDialog({super.key, required this.user});

  @override
  State<UserProfileDialog> createState() => _UserProfileDialogState();
}

class _UserProfileDialogState extends State<UserProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _pinController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name);
    _pinController = TextEditingController(text: widget.user.pin);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedUser = widget.user.copyWith(
        name: _nameController.text.trim(),
        pin: _pinController.text.trim(),
        isSynced: false, // Mark for sync
      );

      await DatabaseHelper.instance.updateUser(updatedUser);
      
      // Update local auth state if it's the current user
      final currentUser = AuthService.instance.currentUser;
      if (currentUser != null && currentUser.id == updatedUser.id) {
        // We might need a method in AuthService to update the session user
        // For now, simple re-login or just local state update if AuthService exposed it
        // Assuming AuthService keeps reference, but it's better to trigger sync
      }

      if (mounted) {
        context.read<SyncService>().syncData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado correctamente')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mi Perfil'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.account_circle, size: 64, color: Colors.blue),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) =>
                  value == null || value.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pinController,
              decoration: const InputDecoration(
                labelText: 'PIN de Acceso',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
                helperText: '4 dígitos numéricos',
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Requerido';
                if (value.length != 4) return 'Debe ser de 4 dígitos';
                if (int.tryParse(value) == null) return 'Solo números';
                return null;
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Rol: ${widget.user.role}',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveChanges,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar Cambios'),
        ),
      ],
    );
  }
}
