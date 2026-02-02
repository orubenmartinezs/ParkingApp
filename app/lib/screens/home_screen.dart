import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../database/database_helper.dart';
import '../models/parking_record.dart';
import '../models/config_models.dart';
import '../models/pension_subscriber.dart';
import '../config/constants.dart';
import '../services/sync_service.dart';
import '../services/auth_service.dart';
import '../services/sound_service.dart';
import '../widgets/connection_status_bar.dart';

import 'pension_screen.dart';
import 'admin_screen.dart';
import 'daily_report_screen.dart';
import 'financial_screen.dart';
import 'settings_screen.dart';

import 'printer_settings_screen.dart';
import '../services/printer_service.dart';
import '../widgets/ticket_preview_dialog.dart';
import '../widgets/user_profile_dialog.dart';

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
  DateTime _selectedDate = DateTime.now();
  bool _wasPrinterConnected = false;

  @override
  void initState() {
    super.initState();
    _loadConfigData();
    _refreshRecords();

    // Init printer service (auto-connect)
    _wasPrinterConnected = PrinterService.instance.isConnected;
    PrinterService.instance.addListener(_onPrinterStatusChanged);
    PrinterService.instance.init();

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
    PrinterService.instance.removeListener(_onPrinterStatusChanged);
    super.dispose();
  }

  void _onPrinterStatusChanged() {
    final isConnected = PrinterService.instance.isConnected;
    if (isConnected && !_wasPrinterConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impresora conectada'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
    _wasPrinterConnected = isConnected;
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
    setState(() => _isLoading = true);

    try {
      final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
      List<ParkingRecord> records = [];

      if (isToday) {
        records = await _dbHelper.getTodayAndActiveRecords(DateTime.now());
      } else {
        // Búsqueda Histórica
        final syncService = context.read<SyncService>();
        if (syncService.isOnline) {
          try {
            records = await syncService.getRecordsByDate(_selectedDate);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error al consultar servidor: $e')),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Opción no disponible por el momento, intente más tarde',
              ),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _records = records;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ... (Rest of the Dialog methods: _showAddRecordDialog, _processNewEntry, _showExitDialog, _processExit, _showAboutDialog)
  // I will include them below to ensure full file integrity.

  Future<void> _showAddRecordDialog() async {
    final plateController = TextEditingController();
    final descriptionController = TextEditingController();
    final notesController = TextEditingController();
    final amountPaidController = TextEditingController(text: '0.00');
    String? selectedEntryTypeId;
    String? selectedUserId;
    bool isPension = false;
    String? selectedSubscriberId;
    DateTime selectedEntryTime = DateTime.now();
    String paymentStatus = 'PENDING';

    if (_entryTypes.isNotEmpty) {
      try {
        selectedEntryTypeId = _entryTypes.firstWhere((e) => e.isDefault).id;
      } catch (_) {
        selectedEntryTypeId = _entryTypes.first.id;
      }
    }

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
                          Autocomplete<String>(
                            optionsBuilder:
                                (TextEditingValue textEditingValue) async {
                                  if (textEditingValue.text.length < 2)
                                    return const Iterable<String>.empty();
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
                                    onChanged: (value) =>
                                        plateController.text = value,
                                  );
                                },
                          ),
                          Autocomplete<String>(
                            optionsBuilder:
                                (TextEditingValue textEditingValue) async {
                                  if (textEditingValue.text.length < 2)
                                    return const Iterable<String>.empty();
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
                                    onChanged: (value) =>
                                        descriptionController.text = value,
                                  );
                                },
                          ),
                          const SizedBox(height: 16),
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
                                      setState(
                                        () => paymentStatus = amount > 0
                                            ? 'PAID'
                                            : 'PENDING',
                                      );
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
                          if (AuthService.instance.isAdmin && _users.isNotEmpty)
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
    PensionSubscriber? subscriber;
    if (subscriberId != null) {
      try {
        subscriber = _subscribers.firstWhere((s) => s.id == subscriberId);
      } catch (_) {}
    } else {
      subscriber = await _dbHelper.getSubscriberByPlate(plate);
    }

    // 1. Determine Client Type / Entry Type Name
    String clientType = AppConstants.fallbackEntryTypeName; // Fallback

    // Try to find default type from loaded list
    if (_entryTypes.isNotEmpty) {
      try {
        final defaultType = _entryTypes.firstWhere((e) => e.isDefault);
        clientType = defaultType.name;
      } catch (_) {
        clientType = _entryTypes.first.name;
      }
    }

    String? finalNotes = notes.isNotEmpty ? notes : null;

    if (subscriber != null) {
      clientType = subscriber.entryType;
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
      // Get record with Folio (insertRecord assigns folio if needed via DB trigger/autoincrement,
      // but sqflite usually returns int ID. Our ID is UUID string.
      // ParkingRecord has 'folio' field. We need to fetch the inserted record to get the generated folio if handled by DB.
      // However, current insertRecord implementation just inserts.
      // Let's assume we need to re-fetch the record or that insertRecord handles it.
      // Checking DatabaseHelper: insertRecord returns int (row id), but we pass UUID.
      // Let's assume we proceed with the object we have. If folio is generated by DB, we might miss it here.
      // Ideally, we should fetch the latest record for this UUID to get the Folio.

      await _dbHelper.insertRecord(newRecord);

      // Fetch fresh record to get generated fields (like folio if any)
      final savedRecord =
          (await _dbHelper.getRecordById(newRecord.id)) ?? newRecord;

      await _refreshRecords();

      if (mounted) {
        SoundService().playEntry();
        context.read<SyncService>().syncData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ingreso registrado: $plate ($clientType)')),
        );

        // Auto-Print Entry Ticket if connected
        bool shouldPrint = true;

        if (PrinterService.instance.isConnected) {
          // 1. Check Pension (Business Rule: Subscribers don't get tickets by default)
          if (savedRecord.pensionSubscriberId != null) {
            shouldPrint = false;
          }

          // 2. Check EntryType configuration
          // This allows dynamic control via Backend/Admin
          if (shouldPrint && savedRecord.entryTypeId != null) {
            try {
              final type = _entryTypes.firstWhere(
                (e) => e.id == savedRecord.entryTypeId,
              );
              shouldPrint = type.shouldPrintTicket;
            } catch (_) {
              // If type not found locally, keep current value
            }
          }

          if (shouldPrint) {
            await PrinterService.instance.printEntryTicket(savedRecord);
          }
        }
      }
    } catch (e) {
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
    DateTime selectedExitTime =
        DateTime.now(); // Nueva variable para hora de salida
    final subscriber = record.pensionSubscriberId != null
        ? await _dbHelper.getSubscriberById(record.pensionSubscriberId!)
        : await _dbHelper.getSubscriberByPlate(record.plate);

    bool isSubscriber =
        record.pensionSubscriberId != null || subscriber != null;

    final costController = TextEditingController();
    String? selectedTariffTypeId;
    String? selectedUserId;
    String entryTypeName = 'General'; // Default

    // Obtener nombre del tipo de entrada para mostrar
    if (record.entryTypeId != null && _entryTypes.isNotEmpty) {
      try {
        final type = _entryTypes.firstWhere((e) => e.id == record.entryTypeId);
        entryTypeName = type.name;
      } catch (_) {}
    } else if (record.clientType != null && record.clientType!.isNotEmpty) {
      entryTypeName = record.clientType!;
    }

    if (_tariffTypes.isNotEmpty) {
      if (isSubscriber) {
        // Try to find a tariff associated with the record's entry type, otherwise use the first one
        if (record.entryTypeId != null) {
          try {
            final entryType = _entryTypes.firstWhere(
              (e) => e.id == record.entryTypeId,
            );
            if (entryType.defaultTariffId != null) {
              selectedTariffTypeId = entryType.defaultTariffId;
            }
          } catch (_) {}
        }
        if (selectedTariffTypeId == null) {
          selectedTariffTypeId = _tariffTypes.first.id;
        }
      } else {
        bool tariffFound = false;
        if (record.entryTypeId != null) {
          try {
            final entryType = _entryTypes.firstWhere(
              (e) => e.id == record.entryTypeId,
            );
            if (entryType.defaultTariffId != null) {
              if (_tariffTypes.any((t) => t.id == entryType.defaultTariffId)) {
                selectedTariffTypeId = entryType.defaultTariffId;
                tariffFound = true;
              }
            }
          } catch (_) {}
        }

        if (!tariffFound) {
          selectedTariffTypeId = _tariffTypes.first.id;
        }
      }
    }

    if (AuthService.instance.currentUser != null) {
      selectedUserId = AuthService.instance.currentUser!.id;
    } else if (_users.isNotEmpty) {
      selectedUserId = _users.first.id;
    }

    void calculateCost() {
      // Usar selectedExitTime en lugar de DateTime.now()
      final duration = selectedExitTime.difference(currentEntryTime);
      final hours = duration.inMinutes / 60.0;
      double newCost = 0.0;

      if (isSubscriber) {
        newCost = 0.0;
      } else {
        if (selectedTariffTypeId != null) {
          try {
            final type = _tariffTypes.firstWhere(
              (t) => t.id == selectedTariffTypeId,
            );

            // Exact Formula Calculation
            final int durationMinutes = duration.inMinutes;
            final int tolerance = type.toleranceMinutes;
            final int period = type.periodMinutes > 0 ? type.periodMinutes : 60;
            final double costFirst = type.costFirstPeriod;
            final double costNext = type.costNextPeriod;
            final double defaultCost = type.defaultCost;

            // 1. Tolerance Check
            if (durationMinutes <= tolerance) {
              newCost = 0.0;
            } else {
              // 2. Logic: First Period + Next Periods
              // If we are here, we exceeded tolerance.
              // Usually, you pay at least the first period.

              // If costs are not configured (0), fallback to defaultCost * hours
              if (costFirst == 0 && costNext == 0) {
                final hours = durationMinutes / 60.0;
                newCost = (hours.ceil() * defaultCost).toDouble();
              } else {
                newCost = costFirst;

                int remainingMinutes = durationMinutes - period;
                if (remainingMinutes > 0) {
                  final int nextPeriods = (remainingMinutes / period).ceil();
                  newCost += nextPeriods * costNext;
                }
              }
            }
          } catch (_) {
            newCost = 0.0;
          }
        } else {
          newCost = 0.0;
        }
      }
      costController.text = newCost.toStringAsFixed(2);
    }

    calculateCost();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final width = MediaQuery.of(context).size.width;
          final dialogWidth = width > 600 ? 600.0 : width * 0.9;
          // Calcular duración basada en la hora de salida seleccionada
          final duration = selectedExitTime.difference(currentEntryTime);

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
                  const SizedBox(height: 8),
                  // Mostrar Tipo de Ingreso
                  Text(
                    'Tipo: $entryTypeName',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hora de Ingreso (Solo Lectura)
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Hora de Ingreso',
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Color(
                                0xFFF5F5F5,
                              ), // Gris claro para indicar disabled
                            ),
                            child: Text(
                              DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(currentEntryTime),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Hora de Salida (Editable)
                          Row(
                            children: [
                              Expanded(
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Hora de Salida',
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Text(
                                    DateFormat(
                                      'dd/MM/yyyy HH:mm',
                                    ).format(selectedExitTime),
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
                                    initialDate: selectedExitTime,
                                    firstDate:
                                        currentEntryTime, // No salir antes de entrar
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 1),
                                    ),
                                  );
                                  if (date != null && context.mounted) {
                                    final time = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.fromDateTime(
                                        selectedExitTime,
                                      ),
                                    );
                                    if (time != null) {
                                      setState(() {
                                        selectedExitTime = DateTime(
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
                              child: const Text(
                                'Vehículo de Pensión detectado. Costo \$0.00',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
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
                          if (AuthService.instance.isAdmin && _users.isNotEmpty)
                            DropdownButtonFormField<String>(
                              initialValue: selectedUserId,
                              decoration: const InputDecoration(
                                labelText: 'Entregado por',
                                border: OutlineInputBorder(),
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
                            )
                          else if (selectedUserId != null)
                            InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Entregado por',
                                border: OutlineInputBorder(),
                                filled: true,
                                fillColor: Color(0xFFF5F5F5),
                              ),
                              child: Text(
                                _users
                                    .firstWhere(
                                      (u) => u.id == selectedUserId,
                                      orElse: () => User(
                                        id: '',
                                        name: 'Usuario',
                                        pin: '',
                                        role: 'STAFF',
                                        isSynced: false,
                                      ),
                                    )
                                    .name,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: costController,
                            readOnly: isSubscriber,
                            decoration: const InputDecoration(
                              labelText: 'Costo Final (\$)',
                              prefixText: '\$',
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
                          String tariffName = '';
                          if (_tariffTypes.isNotEmpty) {
                            tariffName = _tariffTypes.first.name;
                          }
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
                            selectedExitTime,
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
    DateTime exitTime,
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
      exitTime: exitTime,
      cost: cost,
      tariff: tariffName,
      tariffTypeId: tariffTypeId,
      exitUserId: userId,
      isSynced: false,
      paymentStatus: newPaymentStatus,
    );

    await _dbHelper.updateRecord(updatedRecord);
    await _refreshRecords();

    if (mounted) {
      SoundService().playExit();
      context.read<SyncService>().syncData();
    }
  }

  // CRUD Update Logic for Admin
  Future<void> _showEditDialog(ParkingRecord record) async {
    // Reusing the Add Dialog logic but pre-filled
    // For brevity, I'll create a simplified version or reuse logic.
    // Given the constraints, I'll implement a dedicated Edit Dialog.

    final plateController = TextEditingController(text: record.plate);
    final descriptionController = TextEditingController(
      text: record.description,
    );
    final notesController = TextEditingController(text: record.notes);
    final amountPaidController = TextEditingController(
      text: (record.amountPaid ?? 0.0).toString(),
    );
    DateTime selectedEntryTime = record.entryTime;
    String paymentStatus = record.paymentStatus ?? 'PENDING';

    // ... (More fields if needed)

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            child: Container(
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Editar Registro',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: plateController,
                      decoration: const InputDecoration(labelText: 'Placa'),
                    ),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Hora de Ingreso',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              DateFormat(
                                'dd/MM/yyyy HH:mm',
                              ).format(selectedEntryTime),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_calendar),
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
                    TextField(
                      controller: amountPaidController,
                      decoration: const InputDecoration(
                        labelText: 'Monto Pagado',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    DropdownButtonFormField<String>(
                      value: paymentStatus,
                      items: const [
                        DropdownMenuItem(
                          value: 'PENDING',
                          child: Text('Pendiente'),
                        ),
                        DropdownMenuItem(value: 'PAID', child: Text('Pagado')),
                        DropdownMenuItem(
                          value: 'PARTIAL',
                          child: Text('Parcial'),
                        ),
                      ],
                      onChanged: (v) => setState(() => paymentStatus = v!),
                    ),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(labelText: 'Notas'),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            final updated = record.copyWith(
                              plate: plateController.text,
                              description: descriptionController.text,
                              entryTime: selectedEntryTime,
                              amountPaid:
                                  double.tryParse(amountPaidController.text) ??
                                  0.0,
                              paymentStatus: paymentStatus,
                              notes: notesController.text,
                              isSynced: false,
                            );
                            await _dbHelper.updateRecord(updated);
                            _refreshRecords();
                            if (mounted) Navigator.pop(context);
                          },
                          child: const Text('Guardar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showAboutDialog() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Acerca de'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Parking Control',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Versión: ${packageInfo.version}'),
            const SizedBox(height: 16),
            const Text('Taranja Digital'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final entries = _records.length;
    final exits = _records.where((r) => r.exitTime != null).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                DateFormat(
                  'EEEE, d MMMM',
                  'es',
                ).format(_selectedDate).toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.calendar_month, color: Colors.white),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2023),
                    lastDate: DateTime.now(),
                    locale: const Locale('es', 'ES'),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                    _refreshRecords();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem('Ingresos', '$entries', Icons.arrow_downward),
              _buildSummaryItem('Salidas', '$exits', Icons.arrow_upward),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteRecord(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text(
          '¿Estás seguro de eliminar este registro? Esta acción no se puede deshacer.',
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
      await _dbHelper.deleteRecord(id);
      _refreshRecords();
    }
  }

  Widget _buildParkingCard(ParkingRecord record) {
    final isCompleted = record.exitTime != null;
    String durationText = '';
    if (isCompleted) {
      final duration = record.exitTime!.difference(record.entryTime);
      durationText = '${duration.inHours}h ${duration.inMinutes % 60}m';
    }

    // Resolver Nombre de Usuario que recibió
    final entryUserName = _users
        .firstWhere(
          (u) => u.id == record.entryUserId,
          orElse: () => User(
            id: '',
            name: 'Desc.',
            role: 'USER',
            pin: '',
            isActive: true,
          ),
        )
        .name;

    // Resolver Nombre de Tipo de Entrada (Fix SIN_CATEGORIA)
    String displayEntryType = record.clientType ?? 'General';
    if (displayEntryType == 'SIN_CATEGORIA') {
      if (record.entryTypeId != null && _entryTypes.isNotEmpty) {
        try {
          displayEntryType = _entryTypes
              .firstWhere((e) => e.id == record.entryTypeId)
              .name;
        } catch (_) {
          displayEntryType = 'General';
        }
      } else {
        displayEntryType = 'General';
      }
    }

    // Resolver Estado de Pago (Traducción)
    String paymentStatusText = 'Pendiente';
    if (record.paymentStatus == 'PAID') {
      paymentStatusText = 'Pagado';
    } else if (record.paymentStatus == 'PARTIAL') {
      paymentStatusText = 'Parcial';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Placa y Estado
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  record.plate,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isCompleted
                        ? Colors.red.withOpacity(0.1)
                        : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isCompleted ? Colors.red : Colors.green,
                    ),
                  ),
                  child: Text(
                    isCompleted ? 'SALIDA' : 'EN SITIO',
                    style: TextStyle(
                      color: isCompleted ? Colors.red : Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Descripción y Tipo
            Text(
              '${record.description ?? "Sin descripción"} • $displayEntryType',
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
            const Divider(),

            // Detalles Grid
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow(
                        Icons.login,
                        'Entrada',
                        DateFormat('dd/MM HH:mm').format(record.entryTime),
                      ),
                      const SizedBox(height: 4),
                      _buildDetailRow(Icons.person, 'Recibió', entryUserName),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isCompleted)
                        _buildDetailRow(
                          Icons.logout,
                          'Salida',
                          DateFormat('dd/MM HH:mm').format(record.exitTime!),
                        ),
                      const SizedBox(height: 4),
                      _buildDetailRow(
                        Icons.payment,
                        'Estado',
                        paymentStatusText,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            if (record.notes != null && record.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Nota: ${record.notes}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            if ((record.amountPaid ?? 0) > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Abonado: \$${record.amountPaid!.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],

            const SizedBox(height: 8),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.print, size: 20, color: Colors.grey),
                  tooltip: 'Reimprimir Ticket',
                  onPressed: () async {
                    if (!PrinterService.instance.isConnected) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Conecte la impresora primero'),
                        ),
                      );
                      return;
                    }

                    // Check if restricted
                    bool shouldPrint = true;
                    String reason = '';

                    if (record.pensionSubscriberId != null) {
                      shouldPrint = false;
                      reason = 'Pensiones';
                    } else {
                      EntryType? type;
                      // Try to find by ID
                      if (record.entryTypeId != null) {
                        try {
                          type = _entryTypes.firstWhere(
                            (e) => e.id == record.entryTypeId,
                          );
                        } catch (_) {}
                      }
                      // Try to find by Name (fallback)
                      if (type == null) {
                        try {
                          type = _entryTypes.firstWhere(
                            (e) =>
                                e.name.toUpperCase() ==
                                record.clientType.toUpperCase(),
                          );
                        } catch (_) {}
                      }

                      if (type != null && !type.shouldPrintTicket) {
                        shouldPrint = false;
                        reason = type.name;
                      }
                    }

                    if (!shouldPrint) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('No se emiten tickets para $reason'),
                        ),
                      );
                      return;
                    }

                    // Confirm Dialog with Preview
                    await showDialog(
                      context: context,
                      builder: (dialogContext) => TicketPreviewDialog(
                        record: record,
                        onCancel: () => Navigator.pop(dialogContext),
                        onPrint: () async {
                          Navigator.pop(dialogContext); // Close dialog

                          bool result = false;
                          if (record.exitTime == null) {
                            result = await PrinterService.instance
                                .printEntryTicket(record);
                          } else {
                            result = await PrinterService.instance
                                .printExitTicket(record);
                          }

                          if (!result && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Error al imprimir'),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
                if (AuthService.instance.isAdmin) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Editar'),
                    onPressed: () => _showEditDialog(record),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.delete, size: 16, color: Colors.red),
                    label: const Text(
                      'Eliminar',
                      style: TextStyle(color: Colors.red),
                    ),
                    onPressed: () => _confirmDeleteRecord(record.id),
                  ),
                ],
                if (!isCompleted)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.exit_to_app, size: 16),
                    label: const Text('Salida'),
                    onPressed: () => _showExitDialog(record),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Parking Control'),
        elevation: 0, // Flat because we have a custom header
        actions: [
          IconButton(
            icon: const Icon(Icons.directions_car),
            tooltip: 'Pensiones',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PensionScreen()),
            ).then((_) => _refreshRecords()),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Cierre',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DailyReportScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.print),
            tooltip: 'Impresora',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const PrinterSettingsScreen(),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_remote),
            tooltip: 'Configurar Conexión',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              ).then((_) => _loadConfigData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.attach_money),
            tooltip: 'Finanzas',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FinancialScreen()),
            ),
          ),
          if (AuthService.instance.isAdmin)
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Admin',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AdminScreen()),
              ).then((_) => _loadConfigData()),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle),
            tooltip: 'Usuario',
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  final user = AuthService.instance.currentUser;
                  if (user != null) {
                    showDialog(
                      context: context,
                      builder: (context) => UserProfileDialog(user: user),
                    );
                  }
                  break;
                case 'about':
                  _showAboutDialog();
                  break;
                case 'logout':
                  AuthService.instance.logout();
                  break;
              }
            },
            itemBuilder: (context) {
              final user = AuthService.instance.currentUser;
              return [
                if (user != null)
                  PopupMenuItem(
                    enabled: false,
                    child: Text(
                      user.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                if (user != null) const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Mi Perfil'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'about',
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.grey),
                      SizedBox(width: 8),
                      Text('Acerca de'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Cerrar Sesión'),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(30),
          child: ConnectionStatusBar(),
        ),
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _refreshRecords,
                    child: _records.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 100),
                              Center(child: Text('No hay registros')),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 80),
                            itemCount: _records.length,
                            itemBuilder: (context, index) {
                              final record = _records[index];
                              return _buildParkingCard(record);
                            },
                          ),
                  ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: isToday
          ? FloatingActionButton(
              onPressed: _showAddRecordDialog,
              tooltip: 'Nuevo Ingreso',
              child: const Icon(Icons.add, size: 32),
            )
          : null,
    );
  }
}
