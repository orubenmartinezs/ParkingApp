import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../database/database_helper.dart';
import '../models/parking_record.dart';
import '../models/config_models.dart';
import '../models/pension_subscriber.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../services/sound_service.dart';
import '../widgets/connection_status_bar.dart';

import 'pension_screen.dart';
import 'admin_screen.dart';
import 'daily_report_screen.dart';
import 'financial_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<ParkingRecord> _records = [];
  List<User> _users = [];
  List<EntryType> _entryTypes = [];
  List<TariffType> _tariffTypes = [];
  List<PensionSubscriber> _subscribers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfigData();
    _refreshRecords();

    // Escuchar cambios de sincronización para actualizar la UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SyncService>().addListener(_onSyncChanged);
    });
  }

  Future<void> _loadConfigData() async {
    final users = await _dbHelper.getActiveUsers();
    final entryTypes = await _dbHelper.getActiveEntryTypes();
    final tariffTypes = await _dbHelper.getActiveTariffTypes();
    final subscribers = await _dbHelper.getAllSubscribers();

    if (mounted) {
      setState(() {
        _users = users;
        _entryTypes = entryTypes;
        _tariffTypes = tariffTypes;
        _subscribers = subscribers.where((s) => s.isActive).toList();
      });
    }
  }

  @override
  void dispose() {
    // Nota: No podemos eliminar fácilmente el listener de context.read<SyncService>() aquí
    // porque el contexto podría ser inválido. En una app real, usar un Stream o un patrón Provider específico.
    // Para esta demostración, es aceptable.
    super.dispose();
  }

  void _onSyncChanged() {
    if (mounted) {
      final syncService = context.read<SyncService>();
      if (!syncService.isSyncing) {
        _refreshRecords();
        _loadConfigData();
      }
    }
  }

  Future<void> _refreshRecords() async {
    if (!mounted) return;

    final records = await _dbHelper.getTodayAndActiveRecords(DateTime.now());

    if (mounted) {
      setState(() {
        _records = records;
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddRecordDialog() async {
    final plateController = TextEditingController();
    final descriptionController = TextEditingController();
    final notesController = TextEditingController();
    final amountPaidController = TextEditingController(text: '0.00'); // New
    String? selectedEntryTypeId;
    String? selectedUserId;
    bool isPension = false;
    String? selectedSubscriberId;
    DateTime selectedEntryTime = DateTime.now();
    String paymentStatus = 'PENDING'; // Nuevo

    // Por defecto el primer tipo de ingreso si está disponible, o 'PARTICULAR' si existe
    if (_entryTypes.isNotEmpty) {
      try {
        selectedEntryTypeId = _entryTypes
            .firstWhere((e) => e.name == 'PARTICULAR')
            .id;
      } catch (_) {
        selectedEntryTypeId = _entryTypes.first.id;
      }
    }

    // Por defecto el usuario actual si está disponible
    if (AuthService.instance.currentUser != null) {
      selectedUserId = AuthService.instance.currentUser!.id;
    } else if (_users.isNotEmpty) {
      selectedUserId = _users.first.id;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final width = MediaQuery.of(context).size.width;
          // Hacerlo más ancho en tabletas (600px o 90% en móviles)
          final dialogWidth = width > 600 ? 600.0 : width * 0.9;

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: Container(
              width: dialogWidth,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nuevo Ingreso',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 20),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Placa
                          Autocomplete<String>(
                            optionsBuilder:
                                (TextEditingValue textEditingValue) async {
                                  if (textEditingValue.text.length < 2) {
                                    return const Iterable<String>.empty();
                                  }
                                  return await _dbHelper.getPlateSuggestions(
                                    textEditingValue.text,
                                  );
                                },
                            onSelected: (String selection) {
                              plateController.text = selection;
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
                                    decoration: const InputDecoration(
                                      labelText: 'Placa',
                                    ),
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    onChanged: (value) {
                                      plateController.text = value;
                                    },
                                  );
                                },
                          ),
                          // 2. Descripción
                          Autocomplete<String>(
                            optionsBuilder:
                                (TextEditingValue textEditingValue) async {
                                  if (textEditingValue.text.length < 2) {
                                    return const Iterable<String>.empty();
                                  }
                                  return await _dbHelper
                                      .getDescriptionSuggestions(
                                        textEditingValue.text,
                                      );
                                },
                            onSelected: (String selection) {
                              descriptionController.text = selection;
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
                                    decoration: const InputDecoration(
                                      labelText: 'Descripción (Marca/Color)',
                                    ),
                                    onChanged: (value) {
                                      descriptionController.text = value;
                                    },
                                  );
                                },
                          ),
                          const SizedBox(height: 16),

                          // Fecha y Hora de Ingreso
                          Row(
                            children: [
                              Expanded(
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Hora de Ingreso',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Text(
                                    DateFormat(
                                      'dd/MM/yyyy HH:mm',
                                    ).format(selectedEntryTime),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_calendar,
                                  color: Colors.blue,
                                ),
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: selectedEntryTime,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 1),
                                    ),
                                  );
                                  if (date != null && context.mounted) {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(
                                        selectedEntryTime,
                                      ),
                                    );
                                    if (time != null) {
                                      setState(() {
                                        selectedEntryTime = DateTime(
                                          date.year,
                                          date.month,
                                          date.day,
                                          time.hour,
                                          time.minute,
                                        );
                                      });
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Checkbox de Pensión
                          CheckboxListTile(
                            title: const Text('¿Es Pensión?'),
                            value: isPension,
                            onChanged: (value) {
                              setState(() {
                                isPension = value ?? false;
                                if (!isPension) selectedSubscriberId = null;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                          ),

                          if (isPension && _subscribers.isNotEmpty)
                            DropdownButtonFormField<String>(
                              initialValue: selectedSubscriberId,
                              decoration: const InputDecoration(
                                labelText: 'Suscriptor',
                              ),
                              items: _subscribers
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s.id,
                                      child: Text('${s.name} (${s.plate})'),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => selectedSubscriberId = value),
                            ),

                          // 3. Tipo de Ingreso (¿solo si no es pensión, o permitir ambos?)
                          // El usuario pidió "Tipo de Ingreso" como 3er campo.
                          if (!isPension && _entryTypes.isNotEmpty)
                            DropdownButtonFormField<String>(
                              initialValue: selectedEntryTypeId,
                              decoration: const InputDecoration(
                                labelText: 'Tipo de Ingreso',
                              ),
                              items: _entryTypes
                                  .map(
                                    (type) => DropdownMenuItem(
                                      value: type.id,
                                      child: Text(type.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => selectedEntryTypeId = value),
                            ),

                          // SECCIÓN DE PREPAGO
                          if (!isPension) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'Pago por Adelantado',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: amountPaidController,
                                    decoration: const InputDecoration(
                                      labelText: 'Monto Pagado',
                                      prefixText: '\$ ',
                                    ),
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    onChanged: (value) {
                                      final amount =
                                          double.tryParse(value) ?? 0.0;
                                      if (amount > 0) {
                                        setState(() => paymentStatus = 'PAID');
                                      } else {
                                        setState(
                                          () => paymentStatus = 'PENDING',
                                        );
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: paymentStatus,
                                    decoration: const InputDecoration(
                                      labelText: 'Estado',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'PENDING',
                                        child: Text('Pendiente'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'PAID',
                                        child: Text('Pagado'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'PARTIAL',
                                        child: Text('Parcial'),
                                      ),
                                    ],
                                    onChanged: (value) =>
                                        setState(() => paymentStatus = value!),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 16),

                          // 4. Recibido por
                          if (_users.isNotEmpty)
                            DropdownButtonFormField<String>(
                              initialValue: selectedUserId,
                              decoration: const InputDecoration(
                                labelText: 'Recibido por',
                              ),
                              items: _users
                                  .map(
                                    (user) => DropdownMenuItem(
                                      value: user.id,
                                      child: Text(user.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => selectedUserId = value),
                            ),

                          // 5. Comentarios
                          TextField(
                            controller: notesController,
                            decoration: const InputDecoration(
                              labelText: 'Comentarios / Objetos de Valor',
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (plateController.text.isNotEmpty) {
                            Navigator.pop(context);
                            _processNewEntry(
                              plateController.text.toUpperCase(),
                              descriptionController.text,
                              isPension ? null : selectedEntryTypeId,
                              selectedUserId,
                              notesController.text,
                              selectedSubscriberId,
                              selectedEntryTime,
                              double.tryParse(amountPaidController.text) ?? 0.0,
                              paymentStatus,
                            );
                          }
                        },
                        child: const Text('Registrar'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _processNewEntry(
    String plate,
    String description,
    String? entryTypeId,
    String? userId,
    String notes,
    String? subscriberId,
    DateTime entryTime,
    double amountPaid,
    String paymentStatus,
  ) async {
    // Check if it's a subscriber (either selected or by plate)
    PensionSubscriber? subscriber;
    if (subscriberId != null) {
      try {
        subscriber = _subscribers.firstWhere((s) => s.id == subscriberId);
      } catch (_) {}
    } else {
      subscriber = await _dbHelper.getSubscriberByPlate(plate);
    }

    String clientType = 'GENERAL';
    String? finalNotes = notes.isNotEmpty ? notes : null;

    if (subscriber != null) {
      clientType = subscriber.entryType;
      // Append pension info to notes if exists, or start with it
      if (finalNotes != null) {
        finalNotes = 'Pensión Mensual - ${subscriber.name}. $finalNotes';
      } else {
        finalNotes = 'Pensión Mensual - ${subscriber.name}';
      }
    } else if (entryTypeId != null) {
      try {
        final type = _entryTypes.firstWhere((e) => e.id == entryTypeId);
        clientType = type.name;
      } catch (_) {}
    }

    // NEW: Get next folio manually if needed, but the database helper handles it now
    // We just create the object. The helper will assign the folio if it's null,
    // but the model requires an integer? Let's check the model.
    // The model says folio is nullable int.

    final newRecord = ParkingRecord(
      id: const Uuid().v4(),
      plate: plate,
      description: description,
      clientType: clientType,
      entryTypeId: entryTypeId,
      entryUserId: userId,
      entryTime: entryTime,
      notes: finalNotes,
      isSynced: false,
      pensionSubscriberId: subscriber?.id,
      amountPaid: amountPaid,
      paymentStatus: paymentStatus,
    );

    try {
      await _dbHelper.insertRecord(newRecord);
      await _refreshRecords();

      if (mounted) {
        SoundService().playEntry();
        context.read<SyncService>().syncData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ingreso registrado: $plate ($clientType)')),
        );
      }
    } catch (e) {
      print("ERROR SAVING RECORD: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showExitDialog(ParkingRecord record) async {
    DateTime currentEntryTime = record.entryTime;

    // Check if it is a pension subscriber
    final subscriber = record.pensionSubscriberId != null
        ? await _dbHelper.getSubscriberById(record.pensionSubscriberId!)
        : await _dbHelper.getSubscriberByPlate(record.plate);

    bool isSubscriber =
        record.pensionSubscriberId != null ||
        subscriber != null ||
        [
          'NOCTURNO',
          'DIA y NOCHE',
          'PENSION',
        ].contains(record.clientType.toUpperCase()) ||
        (record.notes?.toLowerCase().contains('pensión') ?? false);

    final costController = TextEditingController();
    String? selectedTariffTypeId;
    String? selectedUserId;

    // Initial Tariff Selection
    if (_tariffTypes.isNotEmpty) {
      if (isSubscriber) {
        try {
          final pensionTariff = _tariffTypes.firstWhere(
            (t) =>
                t.name.toUpperCase().contains('PENSIÓN') ||
                t.name.toUpperCase().contains('PENSION'),
            orElse: () => _tariffTypes.first,
          );
          selectedTariffTypeId = pensionTariff.id;
        } catch (_) {}
      } else if (record.clientType == 'IBMH') {
        // Keep calculated cost
      } else {
        // Check if Entry Type has a default tariff linked
        bool tariffFound = false;
        if (record.entryTypeId != null) {
          try {
            final entryType = _entryTypes.firstWhere(
              (e) => e.id == record.entryTypeId,
            );
            if (entryType.defaultTariffId != null) {
              // Check if tariff exists in active tariffs
              if (_tariffTypes.any((t) => t.id == entryType.defaultTariffId)) {
                selectedTariffTypeId = entryType.defaultTariffId;
                tariffFound = true;
              }
            }
          } catch (_) {}
        }

        if (!tariffFound) {
          try {
            selectedTariffTypeId = _tariffTypes
                .firstWhere((t) => t.name == 'POR HORA')
                .id;
          } catch (_) {
            selectedTariffTypeId = _tariffTypes.first.id;
          }
        }
      }
    }

    // Default User
    if (AuthService.instance.currentUser != null) {
      selectedUserId = AuthService.instance.currentUser!.id;
    } else if (_users.isNotEmpty) {
      selectedUserId = _users.first.id;
    }

    void calculateCost() {
      final duration = DateTime.now().difference(currentEntryTime);
      final hours = duration.inMinutes / 60.0;
      double newCost = 0.0;

      if (isSubscriber) {
        newCost = 0.0;
      } else if (record.clientType == 'IBMH') {
        newCost = 30.0;
      } else if (record.clientType == 'IDNTA') {
        newCost = 100.0;
      } else if (record.clientType == 'COOD') {
        newCost = 60.0;
      } else {
        // Check Tariff Type
        if (selectedTariffTypeId != null) {
          try {
            final type = _tariffTypes.firstWhere(
              (t) => t.id == selectedTariffTypeId,
            );
            if (type.name == 'PENSIÓN') {
              newCost = 0.0;
            } else if (type.name == 'COMPLETO') {
              newCost = 100.0;
            } else if (type.name == 'MEDIO DIA') {
              newCost = 60.0;
            } else {
              newCost = (hours.ceil() * 25.0).toDouble();
            }
          } catch (_) {
            newCost = (hours.ceil() * 25.0).toDouble();
          }
        } else {
          newCost = (hours.ceil() * 25.0).toDouble();
        }
      }

      costController.text = newCost.toStringAsFixed(2);
    }

    // Initial calculation
    calculateCost();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final width = MediaQuery.of(context).size.width;
          final dialogWidth = width > 600 ? 600.0 : width * 0.9;
          final duration = DateTime.now().difference(currentEntryTime);

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            child: Container(
              width: dialogWidth,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Salida: ${record.plate}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Entry Time Editor
                          Row(
                            children: [
                              Expanded(
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Hora de Ingreso (Ajuste)',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                  ),
                                  child: Text(
                                    DateFormat(
                                      'dd/MM/yyyy HH:mm',
                                    ).format(currentEntryTime),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_calendar,
                                  color: Colors.blue,
                                ),
                                onPressed: () async {
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate: currentEntryTime,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 1),
                                    ),
                                  );
                                  if (date != null && context.mounted) {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(
                                        currentEntryTime,
                                      ),
                                    );
                                    if (time != null) {
                                      setState(() {
                                        currentEntryTime = DateTime(
                                          date.year,
                                          date.month,
                                          date.day,
                                          time.hour,
                                          time.minute,
                                        );
                                        calculateCost();
                                      });
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Tiempo: ${duration.inHours}h ${duration.inMinutes % 60}m',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 16),
                          if (isSubscriber)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.verified, color: Colors.green),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Vehículo de Pensión detectado.\nEl costo será de \$0.00',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (_tariffTypes.isNotEmpty)
                            DropdownButtonFormField<String>(
                              initialValue: selectedTariffTypeId,
                              decoration: const InputDecoration(
                                labelText: 'Tipo de Tarifa',
                              ),
                              items: _tariffTypes
                                  .map(
                                    (type) => DropdownMenuItem(
                                      value: type.id,
                                      child: Text(type.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    selectedTariffTypeId = value;
                                    calculateCost();
                                  });
                                }
                              },
                            ),
                          const SizedBox(height: 16),
                          if (_users.isNotEmpty)
                            DropdownButtonFormField<String>(
                              initialValue: selectedUserId,
                              decoration: const InputDecoration(
                                labelText: 'Entregado por',
                              ),
                              items: _users
                                  .map(
                                    (user) => DropdownMenuItem(
                                      value: user.id,
                                      child: Text(user.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) =>
                                  setState(() => selectedUserId = value),
                            ),
                          if ((record.amountPaid ?? 0) > 0)
                            Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.blue.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.payment,
                                        color: Colors.blue,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Pago Anticipado: \$${record.amountPaid!.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (record.paymentStatus != null)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 32,
                                        top: 4,
                                      ),
                                      child: Text(
                                        'Estado: ${record.paymentStatus == 'PAID' ? 'Pagado' : record.paymentStatus}',
                                        style: TextStyle(
                                          color: Colors.blue.shade700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: costController,
                            readOnly: isSubscriber,
                            decoration: InputDecoration(
                              labelText: 'Costo Final (\$)',
                              prefixText: '\$',
                              helperText: isSubscriber
                                  ? 'Costo fijo para pensiones'
                                  : 'Puede ajustar el costo si es necesario',
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          final finalCost =
                              double.tryParse(costController.text) ?? 0.0;
                          String tariffName = 'GENERAL';
                          try {
                            tariffName = _tariffTypes
                                .firstWhere((t) => t.id == selectedTariffTypeId)
                                .name;
                          } catch (_) {}

                          _processExit(
                            record,
                            finalCost,
                            tariffName,
                            selectedTariffTypeId,
                            selectedUserId,
                            currentEntryTime,
                          );
                          Navigator.pop(context);
                        },
                        child: const Text('Registrar Salida'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _processExit(
    ParkingRecord record,
    double cost,
    String tariffName,
    String? tariffTypeId,
    String? userId,
    DateTime entryTime,
  ) async {
    String newPaymentStatus = record.paymentStatus ?? 'PENDING';
    final amountPaid = record.amountPaid ?? 0.0;

    if (amountPaid >= cost && cost > 0) {
      newPaymentStatus = 'PAID';
    } else if (amountPaid > 0 && amountPaid < cost) {
      newPaymentStatus = 'PARTIAL';
    } else if (cost == 0) {
      newPaymentStatus = 'PAID';
    } else {
      newPaymentStatus = 'PENDING';
    }

    final updatedRecord = record.copyWith(
      entryTime: entryTime,
      exitTime: DateTime.now(),
      cost: cost,
      tariff: tariffName,
      tariffTypeId: tariffTypeId,
      exitUserId: userId,
      isSynced: false, // Needs sync again
      paymentStatus: newPaymentStatus,
    );

    await _dbHelper.updateRecord(updatedRecord);
    await _refreshRecords();

    if (mounted) {
      SoundService().playExit();
      context.read<SyncService>().syncData();
    }
  }

  Future<void> _showAboutDialog() async {
    final packageInfo = await PackageInfo.fromPlatform();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        final width = MediaQuery.of(context).size.width;
        final dialogWidth = width > 600 ? 600.0 : width * 0.9;

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: Container(
            width: dialogWidth,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 10),
                    Text(
                      'Acerca de',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Image.asset('Parking_icon.png', width: 80, height: 80),
                const SizedBox(height: 16),
                const Text(
                  'Parking Control',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text('Versión: ${packageInfo.version}'),
                Text('Build: ${packageInfo.buildNumber}'),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                const Text(
                  'Desarrollado por:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Taranja Digital',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Text(
                  '© ${DateTime.now().year} Todos los derechos reservados',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cerrar'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parking Control'),
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_car),
            tooltip: 'Administrar Pensiones',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PensionScreen()),
              ).then((_) {
                _loadConfigData(); // Reload subscribers
                _refreshRecords();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Cierre del Día',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DailyReportScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Finanzas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FinancialScreen(),
                ),
              );
            },
          ),
          if (AuthService.instance.isAdmin)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Administración',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AdminScreen()),
                ).then((_) => _loadConfigData());
              },
            ),
          if (AuthService.instance.isAdmin)
            IconButton(
              icon: const Icon(Icons.settings_remote),
              tooltip: 'Configurar Conexión',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Acerca de',
            onPressed: _showAboutDialog,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () {
              AuthService.instance.logout();
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(30),
          child: ConnectionStatusBar(),
        ),
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    await context.read<SyncService>().syncData();
                  },
                  child: _records.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: SizedBox(
                                  height: constraints.maxHeight,
                                  child: const Center(
                                    child: Text('No hay vehículos registrados'),
                                  ),
                                ),
                              ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                            bottom: 100,
                          ), // Space for FAB
                          itemCount: _records.length,
                          itemBuilder: (context, index) {
                            final record = _records[index];
                            final isCompleted = record.exitTime != null;

                            // Calculate duration if completed
                            String durationText = '';
                            if (isCompleted) {
                              final duration = record.exitTime!.difference(
                                record.entryTime,
                              );
                              final hours = duration.inHours;
                              final minutes = duration.inMinutes % 60;
                              durationText = '${hours}h ${minutes}m';
                            }

                            return Dismissible(
                              key: Key(record.id),
                              direction: AuthService.instance.isAdmin
                                  ? DismissDirection.endToStart
                                  : DismissDirection.none,
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(
                                  Icons.delete,
                                  color: Colors.white,
                                ),
                              ),
                              confirmDismiss: (direction) async {
                                return await showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirmar Eliminación'),
                                    content: const Text(
                                      '¿Estás seguro de eliminar este registro permanentemente?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: const Text(
                                          'Eliminar',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              onDismissed: (direction) async {
                                final db = await _dbHelper.database;
                                await db.delete(
                                  'parking_records',
                                  where: 'id = ?',
                                  whereArgs: [record.id],
                                );
                                _refreshRecords();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Registro eliminado'),
                                    ),
                                  );
                                }
                              },
                              child: Card(
                                // Margin handled by Theme
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor: isCompleted
                                        ? Colors.red.shade400
                                        : Colors.green.shade400,
                                    child: const Icon(
                                      Icons.directions_car,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    '${record.folio != null ? "Folio ${record.folio} - " : ""}${record.plate} - ${record.clientType}',
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (record.description != null &&
                                          record.description!.isNotEmpty)
                                        Text(record.description!),
                                      Text(
                                        'Entrada: ${DateFormat('HH:mm').format(record.entryTime)}',
                                      ),
                                      if (isCompleted) ...[
                                        Text(
                                          'Salida: ${DateFormat('HH:mm').format(record.exitTime!)}',
                                        ),
                                        Text('Tiempo: $durationText'),
                                        Text(
                                          'Costo: \$${record.cost?.toStringAsFixed(2)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ] else
                                        const Text(
                                          'En curso...',
                                          style: TextStyle(color: Colors.green),
                                        ),
                                    ],
                                  ),
                                  trailing: isCompleted
                                      ? null
                                      : IconButton(
                                          icon: const Icon(
                                            Icons.exit_to_app,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              _showExitDialog(record),
                                        ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 200, // Wider button
                height: 60, // Taller button
                child: FloatingActionButton.extended(
                  onPressed: _showAddRecordDialog,
                  icon: const Icon(Icons.add, size: 30),
                  label: const Text(
                    'Ingreso',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  elevation: 8,
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
