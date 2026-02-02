import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/config_models.dart';
import '../models/pension_subscriber.dart';
import '../config/constants.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  late TabController _tabController;

  List<User> _users = [];
  List<EntryType> _entryTypes = [];
  List<TariffType> _tariffTypes = [];
  List<PensionSubscriber> _pensionSubscribers = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final users = await _dbHelper.getAllUsers();
    final entryTypes = await _dbHelper.getAllEntryTypes();
    final tariffTypes = await _dbHelper.getAllTariffTypes();
    final subscribers = await _dbHelper.getAllPensionSubscribers();

    if (mounted) {
      setState(() {
        _users = users;
        _entryTypes = entryTypes;
        _tariffTypes = tariffTypes;
        _pensionSubscribers = subscribers;
      });
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
            leading: CircleAvatar(child: Text(user.name[0])),
            title: Text(user.name),
            subtitle: Text('Rol: ${user.role}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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

  Future<void> _showAddUserDialog() async {
    // Implementation for adding user
    final nameController = TextEditingController();
    final pinController = TextEditingController();
    String role = 'STAFF';

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Usuario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: pinController,
              decoration: const InputDecoration(labelText: 'PIN'),
              keyboardType: TextInputType.number,
            ),
            DropdownButton<String>(
              value: role,
              items: ['ADMIN', 'STAFF'].map((r) {
                return DropdownMenuItem(value: r, child: Text(r));
              }).toList(),
              onChanged: (v) => role = v!,
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
                  pin: pinController.text,
                  role: role,
                  isSynced: false,
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
    );
  }

  Future<void> _showEditUserDialog(User user) async {
    final nameController = TextEditingController(text: user.name);
    final pinController = TextEditingController(text: user.pin);
    String role = user.role;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Usuario'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: pinController,
              decoration: const InputDecoration(labelText: 'PIN'),
              keyboardType: TextInputType.number,
            ),
            DropdownButton<String>(
              value: role,
              items: ['ADMIN', 'STAFF'].map((r) {
                return DropdownMenuItem(value: r, child: Text(r));
              }).toList(),
              onChanged: (v) => role = v!,
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
                final updated = User(
                  id: user.id,
                  name: nameController.text,
                  pin: pinController.text,
                  role: role,
                  isActive: user.isActive,
                  isSynced: false,
                );
                await _dbHelper.updateUser(updated);
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

  Future<void> _confirmDeleteUser(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de eliminar este usuario?'),
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

  // --- Entry Types ---

  Widget _buildEntryTypesList() {
    return ListView.builder(
      itemCount: _entryTypes.length,
      itemBuilder: (context, index) {
        final type = _entryTypes[index];
        return Card(
          child: ListTile(
            title: Text(type.name),
            subtitle: Text(
              'Ticket: ${type.shouldPrintTicket ? "Sí" : "No"} | Default: ${type.isDefault ? "Sí" : "No"}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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

  Future<void> _showAddEntryTypeDialog() async {
    final nameController = TextEditingController();
    bool shouldPrint = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nuevo Tipo de Ingreso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              SwitchListTile(
                title: const Text('Imprimir Ticket'),
                value: shouldPrint,
                onChanged: (v) => setState(() => shouldPrint = v),
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
                  final newType = EntryType(
                    id: const Uuid().v4(),
                    name: nameController.text,
                    shouldPrintTicket: shouldPrint,
                    isSynced: false,
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
      ),
    );
  }

  Future<void> _showEditEntryTypeDialog(EntryType type) async {
    final nameController = TextEditingController(text: type.name);
    bool shouldPrint = type.shouldPrintTicket;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar Tipo de Ingreso'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Nombre'),
              ),
              SwitchListTile(
                title: const Text('Imprimir Ticket'),
                value: shouldPrint,
                onChanged: (v) => setState(() => shouldPrint = v),
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
                  final updated = EntryType(
                    id: type.id,
                    name: nameController.text,
                    shouldPrintTicket: shouldPrint,
                    isSynced: false,
                    isDefault: type.isDefault,
                    defaultTariffId: type.defaultTariffId,
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
      ),
    );
  }

  Future<void> _confirmDeleteEntryType(String id) async {
    // ... similar to user
    await _dbHelper.deleteEntryType(id);
    _loadData();
  }

  // --- Tariff Types ---

  Widget _buildTariffTypesList() {
    return ListView.builder(
      itemCount: _tariffTypes.length,
      itemBuilder: (context, index) {
        final type = _tariffTypes[index];
        return Card(
          child: ListTile(
            title: Text(type.name),
            subtitle: Text(
              'Costo: \$${type.costFirstPeriod} | Periodo: ${type.periodMinutes} min',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
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

  Future<void> _showAddTariffTypeDialog() async {
    final nameController = TextEditingController();
    final costController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva Tarifa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: costController,
              decoration: const InputDecoration(labelText: 'Costo'),
              keyboardType: TextInputType.number,
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
                final newType = TariffType(
                  id: const Uuid().v4(),
                  name: nameController.text,
                  costFirstPeriod: double.tryParse(costController.text) ?? 0.0,
                  isSynced: false,
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

  Future<void> _showEditTariffTypeDialog(TariffType type) async {
    final nameController = TextEditingController(text: type.name);
    final costController = TextEditingController(
      text: type.costFirstPeriod.toString(),
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar Tarifa'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            TextField(
              controller: costController,
              decoration: const InputDecoration(labelText: 'Costo'),
              keyboardType: TextInputType.number,
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
                final updated = TariffType(
                  id: type.id,
                  name: nameController.text,
                  costFirstPeriod: double.tryParse(costController.text) ?? 0.0,
                  isSynced: false,
                  periodMinutes: type.periodMinutes,
                  toleranceMinutes: type.toleranceMinutes,
                  costNextPeriod: type.costNextPeriod,
                  defaultCost: type.defaultCost,
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
    await _dbHelper.deleteTariffType(id);
    _loadData();
  }

  // --- Pension Subscribers ---

  Widget _buildPensionSubscribersList() {
    return ListView.builder(
      itemCount: _pensionSubscribers.length,
      itemBuilder: (context, index) {
        final subscriber = _pensionSubscribers[index];
        final entryDate = subscriber.entryDate != null
            ? DateTime.fromMillisecondsSinceEpoch(subscriber.entryDate!)
            : null;
        final paidUntil = subscriber.paidUntil != null
            ? DateTime.fromMillisecondsSinceEpoch(subscriber.paidUntil!)
            : null;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      subscriber.name ?? 'Sin Nombre',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      subscriber.plate ?? 'Sin Placa',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Folio: ${subscriber.folio ?? 'N/A'}'),
                          Text('Tipo: ${subscriber.entryType}'),
                          Text(
                            'Mensualidad: \$${subscriber.monthlyFee.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inicio: ${entryDate != null ? "${entryDate.day}/${entryDate.month}/${entryDate.year}" : "-"}',
                          ),
                          Text(
                            'Pagado hasta: ${paidUntil != null ? "${paidUntil.day}/${paidUntil.month}/${paidUntil.year}" : "-"}',
                          ),
                          if (paidUntil != null &&
                              paidUntil.isBefore(DateTime.now()))
                            const Text(
                              'VENCIDO',
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (subscriber.notes != null &&
                    subscriber.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Notas: ${subscriber.notes}',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ],
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Switch(
                      value: subscriber.isActive,
                      onChanged: (value) async {
                        final updated = PensionSubscriber(
                          id: subscriber.id,
                          folio: subscriber.folio,
                          plate: subscriber.plate,
                          entryType: subscriber.entryType,
                          monthlyFee: subscriber.monthlyFee,
                          name: subscriber.name,
                          notes: subscriber.notes,
                          entryDate: subscriber.entryDate,
                          paidUntil: subscriber.paidUntil,
                          isActive: value,
                          isSynced: false,
                        );
                        await _dbHelper.updatePensionSubscriber(updated);
                        _loadData();
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () =>
                          _showEditPensionSubscriberDialog(subscriber),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () =>
                          _confirmDeletePensionSubscriber(subscriber.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showAddPensionSubscriberDialog() async {
    final nameController = TextEditingController();
    final plateController = TextEditingController();
    final feeController = TextEditingController();
    final notesController = TextEditingController();

    // Default values
    String? selectedEntryType;
    if (_entryTypes.isNotEmpty) {
      selectedEntryType = _entryTypes.first.name;
    }

    DateTime entryDate = DateTime.now();
    DateTime? paidUntil;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Nueva Pensión'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre / Cliente',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: plateController,
                  decoration: const InputDecoration(
                    labelText: 'Placa (Opcional)',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedEntryType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Pensión',
                  ),
                  items: _entryTypes.map((type) {
                    return DropdownMenuItem(
                      value: type.name,
                      child: Text(type.name),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => selectedEntryType = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: feeController,
                  decoration: const InputDecoration(
                    labelText: 'Mensualidad (\$)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Fecha de Inicio'),
                  subtitle: Text(
                    "${entryDate.day}/${entryDate.month}/${entryDate.year}",
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  contentPadding: EdgeInsets.zero,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: entryDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => entryDate = picked);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Pagado Hasta'),
                  subtitle: Text(
                    paidUntil != null
                        ? "${paidUntil!.day}/${paidUntil!.month}/${paidUntil!.year}"
                        : "No definido",
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  contentPadding: EdgeInsets.zero,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          paidUntil ??
                          DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => paidUntil = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notas'),
                  maxLines: 2,
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
                final name = nameController.text.trim();
                final feeText = feeController.text.trim();
                final fee = double.tryParse(feeText);

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El nombre es obligatorio')),
                  );
                  return;
                }

                if (selectedEntryType == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Selecciona un tipo de pensión'),
                    ),
                  );
                  return;
                }

                if (fee == null || fee < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('La mensualidad debe ser un número válido'),
                    ),
                  );
                  return;
                }

                final newSubscriber = PensionSubscriber(
                  id: const Uuid().v4(),
                  plate: plateController.text.isNotEmpty
                      ? plateController.text
                      : null,
                  name: name,
                  entryType: selectedEntryType!,
                  monthlyFee: fee,
                  entryDate: entryDate.millisecondsSinceEpoch,
                  paidUntil: paidUntil?.millisecondsSinceEpoch,
                  notes: notesController.text.isNotEmpty
                      ? notesController.text
                      : null,
                  isActive: true,
                  isSynced: false,
                );
                await _dbHelper.insertPensionSubscriber(newSubscriber);
                _loadData();
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditPensionSubscriberDialog(
    PensionSubscriber subscriber,
  ) async {
    final nameController = TextEditingController(text: subscriber.name);
    final plateController = TextEditingController(text: subscriber.plate);
    final feeController = TextEditingController(
      text: subscriber.monthlyFee.toString(),
    );
    final notesController = TextEditingController(text: subscriber.notes);

    String? selectedEntryType = subscriber.entryType;

    // Check if the current entry type is in the list
    if (_entryTypes.isNotEmpty &&
        !_entryTypes.any((e) => e.name == selectedEntryType)) {
      // If not in list, add it temporarily or default to null?
      // Better to let it be null or handle it.
      // But DropdownButton requires value to be in items.
      // We will leave it as is, but if it causes error, we should clear it.
      // Actually, if we pass a value not in items, it crashes.
      // So we must check.
      if (!_entryTypes.any((e) => e.name == selectedEntryType)) {
        selectedEntryType = null;
      }
    }

    DateTime entryDate = subscriber.entryDate != null
        ? DateTime.fromMillisecondsSinceEpoch(subscriber.entryDate!)
        : DateTime.now();
    DateTime? paidUntil = subscriber.paidUntil != null
        ? DateTime.fromMillisecondsSinceEpoch(subscriber.paidUntil!)
        : null;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Editar Pensión'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre / Cliente',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: plateController,
                  decoration: const InputDecoration(
                    labelText: 'Placa (Opcional)',
                  ),
                  textCapitalization: TextCapitalization.characters,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedEntryType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Pensión',
                  ),
                  items: _entryTypes.map((type) {
                    return DropdownMenuItem(
                      value: type.name,
                      child: Text(type.name),
                    );
                  }).toList(),
                  onChanged: (value) =>
                      setState(() => selectedEntryType = value),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: feeController,
                  decoration: const InputDecoration(
                    labelText: 'Mensualidad (\$)',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text('Fecha de Inicio'),
                  subtitle: Text(
                    "${entryDate.day}/${entryDate.month}/${entryDate.year}",
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  contentPadding: EdgeInsets.zero,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: entryDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => entryDate = picked);
                    }
                  },
                ),
                ListTile(
                  title: const Text('Pagado Hasta'),
                  subtitle: Text(
                    paidUntil != null
                        ? "${paidUntil!.day}/${paidUntil!.month}/${paidUntil!.year}"
                        : "No definido",
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  contentPadding: EdgeInsets.zero,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate:
                          paidUntil ??
                          DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() => paidUntil = picked);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(labelText: 'Notas'),
                  maxLines: 2,
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
                final name = nameController.text.trim();
                final feeText = feeController.text.trim();
                final fee = double.tryParse(feeText);

                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('El nombre es obligatorio')),
                  );
                  return;
                }

                if (selectedEntryType == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Selecciona un tipo de pensión'),
                    ),
                  );
                  return;
                }

                if (fee == null || fee < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('La mensualidad debe ser un número válido'),
                    ),
                  );
                  return;
                }

                final updated = PensionSubscriber(
                  id: subscriber.id,
                  folio: subscriber.folio,
                  plate: plateController.text.isNotEmpty
                      ? plateController.text
                      : null,
                  name: name,
                  entryType: selectedEntryType!,
                  monthlyFee: fee,
                  entryDate: entryDate.millisecondsSinceEpoch,
                  paidUntil: paidUntil?.millisecondsSinceEpoch,
                  notes: notesController.text.isNotEmpty
                      ? notesController.text
                      : null,
                  isActive: subscriber.isActive,
                  isSynced: false,
                );
                await _dbHelper.updatePensionSubscriber(updated);
                _loadData();
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeletePensionSubscriber(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text(
          '¿Estás seguro de eliminar esta pensión? Esta acción no se puede deshacer.',
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
      await _dbHelper.deletePensionSubscriber(id);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administración'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Usuarios', icon: Icon(Icons.people)),
            Tab(text: 'Tipos Ingreso', icon: Icon(Icons.category)),
            Tab(text: 'Tarifas', icon: Icon(Icons.attach_money)),
            Tab(text: 'Pensiones', icon: Icon(Icons.car_rental)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUsersList(),
          _buildEntryTypesList(),
          _buildTariffTypesList(),
          _buildPensionSubscribersList(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
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
            case 3:
              _showAddPensionSubscriberDialog();
              break;
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
