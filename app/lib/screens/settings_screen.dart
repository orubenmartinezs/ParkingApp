import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../services/config_service.dart';
import '../services/log_service.dart';
import '../database/database_helper.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _urlController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: ConfigService.instance.apiUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      // Try to fetch schema or just a simple ping
      final response = await Dio().get(
        '$url/schema.php',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      if (mounted) {
        if (response.statusCode == 200) {
          // Connection Successful

          // Check if we need to initialize DB
          // First, we must temporarily update ConfigService so DatabaseHelper uses the new URL
          await ConfigService.instance.setApiUrl(url);

          final users = await DatabaseHelper.instance.getAllUsers();
          if (users.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Conexión OK. Inicializando base de datos...'),
                backgroundColor: Colors.blue,
              ),
            );

            await DatabaseHelper.instance.fetchInitialData();

            final usersAfter = await DatabaseHelper.instance.getAllUsers();
            if (usersAfter.isNotEmpty) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '✅ Base de datos sincronizada correctamente.',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      '⚠️ Conexión OK, pero no hay usuarios remotos.',
                    ),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Conexión Exitosa y Base de Datos lista'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Servidor respondió: ${response.statusCode}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Falló la conexión: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La URL no puede estar vacía')),
      );
      return;
    }

    // Basic validation
    if (!url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La URL debe comenzar con http:// o https://'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ConfigService.instance.setApiUrl(url);
      LogService().info('URL de servidor actualizada a: $url');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Configuración guardada. Reinicia la app para aplicar cambios críticos.',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      LogService().error('Error guardando configuración: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Servidor Remoto',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Configure la dirección IP o URL del servidor backend. Si su IP cambia, actualícela aquí.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'URL del API',
                border: OutlineInputBorder(),
                hintText: 'http://192.168.1.100:8000/api',
                helperText: 'Ejemplo: http://192.168.100.12:8000/api',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _testConnection,
                icon: const Icon(Icons.wifi_find),
                label: const Text('Probar Conexión'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Guardar Cambios'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
