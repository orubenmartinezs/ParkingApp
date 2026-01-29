import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/config_models.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../database/database_helper.dart';
import '../services/sync_service.dart';
import '../widgets/connection_status_bar.dart';
import 'settings_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _pinController = TextEditingController();
  List<User> _users = [];
  User? _selectedUser;
  bool _isLoading = true;
  bool _isObscure = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    // Listen to SyncService to reload users after sync
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final syncService = Provider.of<SyncService>(context, listen: false);
      syncService.addListener(_onSyncChange);
    });
  }

  @override
  void dispose() {
    final syncService = Provider.of<SyncService>(context, listen: false);
    syncService.removeListener(_onSyncChange);
    _pinController.dispose();
    super.dispose();
  }

  void _onSyncChange() {
    final syncService = Provider.of<SyncService>(context, listen: false);
    // Reload users when sync finishes
    if (!syncService.isSyncing) {
      _loadUsers();
    }
  }

  Future<void> _loadUsers() async {
    try {
      final users = await DatabaseHelper.instance.getActiveUsers();
      if (mounted) {
        setState(() {
          _users = users;
          if (users.isNotEmpty) {
            _selectedUser = users.first;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading users: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error cargando usuarios: $e';
        });
      }
    }
  }

  Future<void> _handleLogin() async {
    if (_selectedUser == null) return;

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    final success = await AuthService.instance.login(
      _selectedUser!.id,
      _pinController.text,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (!success) {
          _errorMessage = 'PIN incorrecto';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1565C0), // Blue background
      body: Stack(
        children: [
          Positioned(
            top: 40,
            right: 16,
            child: IconButton(
              icon: const Icon(Icons.settings_remote, color: Colors.white),
              tooltip: 'Configurar Conexión',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                ).then(
                  (_) => _loadUsers(),
                ); // Reload users in case connection fixed
              },
            ),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ConnectionStatusBar(),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icono / Logo
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Image.asset(
                        'Parking_icon.png',
                        width: 80,
                        height: 80,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Título
                    Text(
                      'Parking Control',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Iniciar Sesión',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 48),

                    // Formulario en tarjeta
                    Card(
                      elevation: 4,
                      shadowColor: Colors.black12,
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: _isLoading && _users.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Selector de Usuario
                                  if (_users.isEmpty)
                                    const Padding(
                                      padding: EdgeInsets.only(bottom: 24.0),
                                      child: Text(
                                        'No hay usuarios registrados. Sincronice con el servidor.',
                                        style: TextStyle(color: Colors.red),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  else
                                    DropdownButtonFormField<User>(
                                      initialValue: _selectedUser,
                                      decoration: const InputDecoration(
                                        labelText: 'Usuario',
                                        prefixIcon: Icon(Icons.person_outline),
                                      ),
                                      items: _users.map((user) {
                                        return DropdownMenuItem(
                                          value: user,
                                          child: Text(user.name),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedUser = value;
                                        });
                                      },
                                    ),
                                  if (_users.isNotEmpty)
                                    const SizedBox(height: 24),

                                  // Campo de PIN
                                  TextField(
                                    controller: _pinController,
                                    obscureText: _isObscure,
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'PIN',
                                      prefixIcon: const Icon(Icons.pin),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _isObscure
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _isObscure = !_isObscure;
                                          });
                                        },
                                      ),
                                      errorText: _errorMessage,
                                    ),
                                    onSubmitted: (_) => _handleLogin(),
                                  ),
                                  const SizedBox(height: 32),

                                  // Botón de Ingreso
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('INGRESAR'),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
