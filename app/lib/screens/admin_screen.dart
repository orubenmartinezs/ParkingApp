import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/config_models.dart';
import 'logs_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<User> _users = [];
  List<EntryType> _entryTypes = [];
  List<TariffType> _tariffTypes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final users = await _dbHelper.getAllUsers();
    final entryTypes = await _dbHelper.getAllEntryTypes();
    final tariffTypes = await _dbHelper.getAllTariffTypes();

    if (mounted) {
      setState(() {
        _users = users;
        _entryTypes = entryTypes;
        _tariffTypes = tariffTypes;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración'),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Ver Logs',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const LogsScreen()),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Usuarios'),
            Tab(text: 'Tipos Ingreso'),
            Tab(text: 'Tipos Tarifa'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildUsersList(),
                _buildEntryTypesList(),
                _buildTariffTypesList(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddDialog() {
    switch (_tabController.index) {
      case 0:
        _showAddUserDialog();
        break;
      case 1:
        _showAddEntryTypeDialog();
        break;
      case 2:
        _showAddTariffTypeDialog();
        break;
    }
  }

  // --- Users ---

  Widget _buildUsersList() {
    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(user.name),
            subtitle: Text(user.role),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: user.isActive,
                  onChanged: (value) async {
                    final updatedUser = User(
                      id: user.id,
                      name: user.name,
                      role: user.role,
                      isActive: value,
                    );
                    await _dbHelper.updateUser(updatedUser);
                    _loadData();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditUserDialog(user),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDeleteUser(user.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditUserDialog(User user) async {
    final nameController = TextEditingController(text: user.name);
    String role = user.role;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar Usuario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(value: 'STAFF', child: Text('Personal')),
                  DropdownMenuItem(
                    value: 'ADMIN',
                    child: Text('Administrador'),
                  ),
                ],
                onChanged: (value) => setState(() => role = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final updatedUser = User(
                    id: user.id,
                    name: nameController.text,
                    role: role,
                    isActive: user.isActive,
                  );
                  await _dbHelper.updateUser(updatedUser);
                  _loadData();
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteUser(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text(
          '¿Estás seguro de eliminar este usuario? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteUser(id);
      _loadData();
    }
  }

  Future<void> _showAddUserDialog() async {
    final nameController = TextEditingController();
    final pinController = TextEditingController();
    String role = 'STAFF';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nuevo Usuario'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                decoration: const InputDecoration(
                  labelText: 'PIN de Acceso',
                  helperText: 'Numérico (ej. 1234)',
                ),
                keyboardType: TextInputType.number,
                maxLength: 4,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(value: 'STAFF', child: Text('Personal')),
                  DropdownMenuItem(
                    value: 'ADMIN',
                    child: Text('Administrador'),
                  ),
                ],
                onChanged: (value) => setState(() => role = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                  final newUser = User(
                    id: const Uuid().v4(),
                    name: nameController.text,
                    role: role,
                    pin: pinController.text.isNotEmpty
                        ? pinController.text
                        : null,
                    isActive: true,
                  );
                  await _dbHelper.insertUser(newUser);
                  _loadData();
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Entry Types ---

  Widget _buildEntryTypesList() {
    return ListView.builder(
      itemCount: _entryTypes.length,
      itemBuilder: (context, index) {
        final type = _entryTypes[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(type.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: type.isActive,
                  onChanged: (value) async {
                    final updated = EntryType(
                      id: type.id,
                      name: type.name,
                      isActive: value,
                    );
                    await _dbHelper.updateEntryType(updated);
                    _loadData();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditEntryTypeDialog(type),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDeleteEntryType(type.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditEntryTypeDialog(EntryType type) async {
    final nameController = TextEditingController(text: type.name);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Tipo de Ingreso'),
        content: Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text.length < 2) {
              return const Iterable<String>.empty();
            }
            return await _dbHelper.getEntryTypeNameSuggestions(
              textEditingValue.text,
            );
          },
          onSelected: (String selection) {
            nameController.text = selection;
          },
          fieldViewBuilder:
              (
                context,
                fieldTextEditingController,
                focusNode,
                onFieldSubmitted,
              ) {
                return TextField(
                  controller: fieldTextEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (value) {
                    nameController.text = value;
                  },
                );
              },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final updated = EntryType(
                  id: type.id,
                  name: nameController.text.toUpperCase(),
                  isActive: type.isActive,
                );
                await _dbHelper.updateEntryType(updated);
                _loadData();
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteEntryType(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de eliminar este registro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteEntryType(id);
      _loadData();
    }
  }

  Future<void> _showAddEntryTypeDialog() async {
    final nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Tipo de Ingreso'),
        content: Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text.length < 2) {
              return const Iterable<String>.empty();
            }
            return await _dbHelper.getEntryTypeNameSuggestions(
              textEditingValue.text,
            );
          },
          onSelected: (String selection) {
            nameController.text = selection;
          },
          fieldViewBuilder:
              (
                context,
                fieldTextEditingController,
                focusNode,
                onFieldSubmitted,
              ) {
                return TextField(
                  controller: fieldTextEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (value) {
                    nameController.text = value;
                  },
                );
              },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final newType = EntryType(
                  id: const Uuid().v4(),
                  name: nameController.text.toUpperCase(),
                  isActive: true,
                );
                await _dbHelper.insertEntryType(newType);
                _loadData();
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  // --- Tariff Types ---

  Widget _buildTariffTypesList() {
    return ListView.builder(
      itemCount: _tariffTypes.length,
      itemBuilder: (context, index) {
        final type = _tariffTypes[index];
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(type.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: type.isActive,
                  onChanged: (value) async {
                    final updated = TariffType(
                      id: type.id,
                      name: type.name,
                      isActive: value,
                    );
                    await _dbHelper.updateTariffType(updated);
                    _loadData();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditTariffTypeDialog(type),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _confirmDeleteTariffType(type.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditTariffTypeDialog(TariffType type) async {
    final nameController = TextEditingController(text: type.name);
    final defaultCostController = TextEditingController(
      text: type.defaultCost.toString(),
    );
    final costFirstPeriodController = TextEditingController(
      text: type.costFirstPeriod.toString(),
    );
    final costNextPeriodController = TextEditingController(
      text: type.costNextPeriod.toString(),
    );
    final periodMinutesController = TextEditingController(
      text: type.periodMinutes.toString(),
    );
    final toleranceMinutesController = TextEditingController(
      text: type.toleranceMinutes.toString(),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Tipo de Tarifa'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) async {
                  if (textEditingValue.text.length < 2) {
                    return const Iterable<String>.empty();
                  }
                  return await _dbHelper.getTariffTypeNameSuggestions(
                    textEditingValue.text,
                  );
                },
                onSelected: (String selection) {
                  nameController.text = selection;
                },
                fieldViewBuilder:
                    (
                      context,
                      fieldTextEditingController,
                      focusNode,
                      onFieldSubmitted,
                    ) {
                      return TextField(
                        controller: fieldTextEditingController,
                        focusNode: focusNode,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (value) {
                          nameController.text = value;
                        },
                      );
                    },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: defaultCostController,
                      decoration: const InputDecoration(
                        labelText: 'Costo Base (\$)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: costFirstPeriodController,
                      decoration: const InputDecoration(
                        labelText: 'Costo 1er Periodo',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: costNextPeriodController,
                decoration: const InputDecoration(
                  labelText: 'Costo Siguientes Periodos',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: periodMinutesController,
                      decoration: const InputDecoration(
                        labelText: 'Minutos Periodo',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: toleranceMinutesController,
                      decoration: const InputDecoration(
                        labelText: 'Minutos Tolerancia',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final updated = TariffType(
                  id: type.id,
                  name: nameController.text.toUpperCase(),
                  defaultCost:
                      double.tryParse(defaultCostController.text) ?? 0.0,
                  costFirstPeriod:
                      double.tryParse(costFirstPeriodController.text) ?? 0.0,
                  costNextPeriod:
                      double.tryParse(costNextPeriodController.text) ?? 0.0,
                  periodMinutes:
                      int.tryParse(periodMinutesController.text) ?? 60,
                  toleranceMinutes:
                      int.tryParse(toleranceMinutesController.text) ?? 15,
                  isActive: type.isActive,
                );
                await _dbHelper.updateTariffType(updated);
                _loadData();
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTariffType(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de eliminar este registro?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _dbHelper.deleteTariffType(id);
      _loadData();
    }
  }

  Future<void> _showAddTariffTypeDialog() async {
    final nameController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Tipo de Tarifa'),
        content: Autocomplete<String>(
          optionsBuilder: (TextEditingValue textEditingValue) async {
            if (textEditingValue.text.length < 2) {
              return const Iterable<String>.empty();
            }
            return await _dbHelper.getTariffTypeNameSuggestions(
              textEditingValue.text,
            );
          },
          onSelected: (String selection) {
            nameController.text = selection;
          },
          fieldViewBuilder:
              (
                context,
                fieldTextEditingController,
                focusNode,
                onFieldSubmitted,
              ) {
                return TextField(
                  controller: fieldTextEditingController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (value) {
                    nameController.text = value;
                  },
                );
              },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final newType = TariffType(
                  id: const Uuid().v4(),
                  name: nameController.text.toUpperCase(),
                  isActive: true,
                );
                await _dbHelper.insertTariffType(newType);
                _loadData();
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
