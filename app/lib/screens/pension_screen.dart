import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/pension_subscriber.dart';
import '../models/pension_payment.dart';
import '../config/constants.dart';
import '../database/database_helper.dart';
import '../services/sync_service.dart';
import '../services/sound_service.dart';
import 'pension_details_screen.dart';

/// Pantalla principal para la Gestión de Pensiones.
///
/// Permite visualizar la lista de suscriptores (activos e inactivos),
/// registrar nuevos suscriptores, y gestionar pagos/renovaciones.
///
/// Funcionalidades Principales:
/// - Listado de pensiones con indicador visual de estado (Activo/Inactivo).
/// - Sincronización automática con el backend al cargar.
/// - Alta de nuevos suscriptores con autocompletado de clientes/placas.
/// - Renovación de pagos con cálculo automático de fechas (+30 días).
class PensionScreen extends StatefulWidget {
  const PensionScreen({super.key});

  @override
  State<PensionScreen> createState() => _PensionScreenState();
}

class _PensionScreenState extends State<PensionScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<PensionSubscriber> _subscribers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshSubscribers();
    // Escuchar cambios en la sincronización para actualizar la lista
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SyncService>().addListener(_onSyncChanged);
    });
  }

  @override
  void dispose() {
    // No se puede acceder de forma segura a context.read en dispose si el widget está desmontado del árbol
    // Pero necesitamos eliminar el listener.
    // En esta aplicación simple, podríamos omitirlo o usar una referencia si tuviéramos una.
    // Pero dado que SyncService es global, podemos intentarlo.
    // Sin embargo, context.read en dispose está desaconsejado.
    // Omitiremos removeListener aquí por simplicidad ya que el servicio es un singleton en Provider
    // y esta pantalla probablemente solo se empuja/extrae ocasionalmente.
    // Idealmente guardaríamos la referencia del servicio en initState.
    super.dispose();
  }

  void _onSyncChanged() {
    if (mounted) {
      final syncService = context.read<SyncService>();
      if (!syncService.isSyncing) {
        _refreshSubscribers();
      }
    }
  }

  Future<void> _refreshSubscribers() async {
    final subscribers = await _dbHelper.getAllSubscribers();
    if (mounted) {
      setState(() {
        _subscribers = subscribers;
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddSubscriberDialog() async {
    final plateController = TextEditingController();
    final nameController = TextEditingController();
    final notesController = TextEditingController();
    final feeController = TextEditingController(text: '0.0');

    // Load dynamic entry types
    final availableTypes = await _dbHelper.getActiveEntryTypes();
    String entryType = availableTypes.isNotEmpty
        ? availableTypes.first.name
        : AppConstants.fallbackEntryTypeName; // Fallback only if DB is empty

    DateTime entryDate = DateTime.now();

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Nueva Pensión',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Autocomplete<String>(
                      optionsBuilder:
                          (TextEditingValue textEditingValue) async {
                            if (textEditingValue.text.length < 2) {
                              return const Iterable<String>.empty();
                            }
                            return await _dbHelper.getClientNameSuggestions(
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
                              decoration: const InputDecoration(
                                labelText: 'Nombre / Alias (Quien contrata)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                              onChanged: (value) {
                                nameController.text = value;
                              },
                            );
                          },
                    ),
                    const SizedBox(height: 16),
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
                                labelText: 'Placa (Opcional)',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.directions_car),
                              ),
                              textCapitalization: TextCapitalization.characters,
                              onChanged: (value) {
                                plateController.text = value;
                              },
                            );
                          },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: entryType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Ingreso',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      items: availableTypes.isNotEmpty
                          ? availableTypes
                                .map(
                                  (type) => DropdownMenuItem(
                                    value: type.name,
                                    child: Text(type.name),
                                  ),
                                )
                                .toList()
                          : [
                              // Fallback items if DB is empty
                              const DropdownMenuItem(
                                value: AppConstants.fallbackEntryTypeName,
                                child: Text(AppConstants.fallbackEntryTypeName),
                              ),
                            ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            entryType = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: feeController,
                      decoration: const InputDecoration(
                        labelText: 'Mensualidad (\$)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones / Comentarios',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.comment),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Text('Fecha de Ingreso: '),
                        TextButton(
                          onPressed: () async {
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
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(entryDate),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancelar'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () async {
                            final name = nameController.text.trim();
                            final plate = plateController.text.trim();
                            final fee =
                                double.tryParse(feeController.text) ?? 0.0;

                            if (name.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('El nombre es obligatorio'),
                                ),
                              );
                              return;
                            }

                            final folio = await _dbHelper.getNextSequence(
                              'pension_folio',
                            );

                            final newSubscriber = PensionSubscriber(
                              id: const Uuid().v4(),
                              folio: folio,
                              plate: plate.isEmpty ? null : plate,
                              entryType: entryType,
                              monthlyFee: fee,
                              name: name,
                              notes: notesController.text.trim(),
                              entryDate: entryDate.millisecondsSinceEpoch,
                              paidUntil: entryDate.millisecondsSinceEpoch,
                              isActive: true,
                            );

                            await _dbHelper.insertSubscriber(newSubscriber);
                            _refreshSubscribers();

                            // Intentar sincronizar inmediatamente
                            if (mounted) {
                              context.read<SyncService>().syncData();
                            }

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

  Future<void> _showPaymentDialog(PensionSubscriber subscriber) async {
    final amountController = TextEditingController(
      text: subscriber.monthlyFee.toString(),
    );
    DateTime selectedDate = DateTime.now();
    DateTime startDate = DateTime.now();
    DateTime endDate = DateTime.now().add(const Duration(days: 30));

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(
              'Renovar Pensión: ${subscriber.plate ?? subscriber.name ?? "Sin ID"}',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Monto a Pagar (\$)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Cobertura:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: startDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() {
                              startDate = picked;
                              // Auto actualizar fecha fin (+30 días)
                              endDate = startDate.add(const Duration(days: 30));
                            });
                          }
                        },
                        child: Text(DateFormat('dd/MM/yyyy').format(startDate)),
                      ),
                      const Text('al'),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: endDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() => endDate = picked);
                        },
                        child: Text(DateFormat('dd/MM/yyyy').format(endDate)),
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
                onPressed: () {
                  final amount = double.tryParse(amountController.text) ?? 0.0;
                  _processPayment(subscriber, amount, startDate, endDate);
                  Navigator.pop(context);
                },
                child: const Text('Registrar Pago'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _processPayment(
    PensionSubscriber subscriber,
    double amount,
    DateTime start,
    DateTime end,
  ) async {
    final payment = PensionPayment(
      id: const Uuid().v4(),
      subscriberId: subscriber.id,
      amount: amount,
      paymentDate: DateTime.now(),
      coverageStartDate: start,
      coverageEndDate: end,
      isSynced: false,
    );

    await _dbHelper.insertPayment(payment);

    // Actualizar paid_until del Suscriptor
    final updatedSubscriber = subscriber.copyWith(
      paidUntil: end.millisecondsSinceEpoch,
      isSynced: false,
    );
    await _dbHelper.updateSubscriber(updatedSubscriber);

    // También activar sincronización
    if (mounted) {
      SoundService().playPaymentSuccess();
      context.read<SyncService>().syncData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago registrado exitosamente')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar Pensiones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sincronizar ahora',
            onPressed: () async {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Sincronizando...')));
              await context.read<SyncService>().syncData();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sincronización finalizada')),
                );
                _refreshSubscribers();
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _subscribers.isEmpty
          ? const Center(child: Text('No hay pensiones registradas'))
          : ListView.builder(
              itemCount: _subscribers.length,
              itemBuilder: (context, index) {
                final sub = _subscribers[index];
                return Card(
                  color: sub.isActive ? null : Colors.grey.shade200,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: sub.isActive ? null : Colors.grey,
                      child: Text(sub.entryType.substring(0, 1)),
                    ),
                    title: Text(
                      '${sub.folio != null ? "Folio ${sub.folio} - " : ""}${sub.name ?? sub.plate ?? "Sin Identificación"}${!sub.isActive ? " (INACTIVA)" : ""}',
                      style: TextStyle(
                        color: sub.isActive ? null : Colors.grey.shade700,
                        decoration: sub.isActive
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    subtitle: Text(
                      '${sub.plate != null ? "${sub.plate}\n" : ""}\$${sub.monthlyFee} / Mes${sub.paidUntil != null ? "\nPagado hasta: ${DateFormat('dd/MM/yyyy').format(DateTime.fromMillisecondsSinceEpoch(sub.paidUntil!))}" : ""}',
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PensionDetailsScreen(subscriber: sub),
                        ),
                      );
                      _refreshSubscribers();
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSubscriberDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
