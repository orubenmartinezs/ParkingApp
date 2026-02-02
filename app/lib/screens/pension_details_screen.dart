import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/pension_subscriber.dart';
import '../models/pension_payment.dart';
import '../database/database_helper.dart';
import '../services/sync_service.dart';
import '../services/sound_service.dart';

class PensionDetailsScreen extends StatefulWidget {
  final PensionSubscriber subscriber;

  const PensionDetailsScreen({super.key, required this.subscriber});

  @override
  State<PensionDetailsScreen> createState() => _PensionDetailsScreenState();
}

class _PensionDetailsScreenState extends State<PensionDetailsScreen> {
  late PensionSubscriber _subscriber;
  List<PensionPayment> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _subscriber = widget.subscriber;
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    final payments = await DatabaseHelper.instance.getPaymentsBySubscriber(
      _subscriber.id,
    );
    if (mounted) {
      setState(() {
        _payments = payments;
        _isLoading = false;
      });
    }
  }

  Future<void> _showEditSubscriberDialog() async {
    final plateController = TextEditingController(text: _subscriber.plate);
    final nameController = TextEditingController(text: _subscriber.name);
    final notesController = TextEditingController(text: _subscriber.notes);
    final feeController = TextEditingController(
      text: _subscriber.monthlyFee.toString(),
    );
    String entryType = _subscriber.entryType;
    String periodicity = _subscriber.periodicity;

    final periodicityOptions = {
      'WEEKLY': 'Semanal',
      'BIWEEKLY': 'Quincenal',
      'MONTHLY': 'Mensual',
    };

    final availableTypes = await DatabaseHelper.instance.getActiveEntryTypes();

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
                      'Editar Pensión',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre / Alias',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: plateController,
                      decoration: const InputDecoration(
                        labelText: 'Placa (Opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.directions_car),
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: availableTypes.any((t) => t.name == entryType)
                          ? entryType
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de Ingreso',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      items: availableTypes
                          .map(
                            (type) => DropdownMenuItem(
                              value: type.name,
                              child: Text(type.name),
                            ),
                          )
                          .toList(),
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
                        labelText: 'Monto de Cuota (\$)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: periodicity,
                      decoration: const InputDecoration(
                        labelText: 'Periodicidad de Pago',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.update),
                      ),
                      items: periodicityOptions.entries
                          .map(
                            (entry) => DropdownMenuItem(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            periodicity = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Observaciones',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.comment),
                      ),
                      maxLines: 2,
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

                            final updatedSubscriber = _subscriber.copyWith(
                              name: name,
                              plate: plateController.text.trim().isEmpty
                                  ? null
                                  : plateController.text.trim(),
                              entryType: entryType,
                              monthlyFee: fee,
                              notes: notesController.text.trim(),
                              periodicity: periodicity,
                              isSynced: false,
                            );

                            await DatabaseHelper.instance.updateSubscriber(
                              updatedSubscriber,
                            );

                            if (mounted) {
                              setState(() {
                                _subscriber = updatedSubscriber;
                              });
                              context.read<SyncService>().syncData();
                              Navigator.pop(context);
                            }
                          },
                          child: const Text('Guardar Cambios'),
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

  Future<void> _showPaymentDialog() async {
    final amountController = TextEditingController(
      text: _subscriber.monthlyFee.toString(),
    );

    // Determine start date based on last payment
    DateTime startDate = DateTime.now();
    if (_payments.isNotEmpty) {
      // Find the payment with the latest coverage end date
      final lastCoverageEnd = _payments
          .map((p) => p.coverageEndDate)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      // If the last coverage is still valid or recently expired, start from there
      if (lastCoverageEnd.isAfter(
        DateTime.now().subtract(const Duration(days: 60)),
      )) {
        startDate = lastCoverageEnd;
      }
    }

    // Determine days to add based on periodicity
    int daysToAdd = 30; // Default MONTHLY
    if (_subscriber.periodicity == 'WEEKLY')
      daysToAdd = 7;
    else if (_subscriber.periodicity == 'BIWEEKLY')
      daysToAdd = 15;

    DateTime endDate = startDate.add(Duration(days: daysToAdd));
    DateTime paymentDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Registrar Pago: ${_subscriber.plate}'),
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
                  Row(
                    children: [
                      const Text('Fecha Pago: '),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: paymentDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null)
                            setState(() => paymentDate = picked);
                        },
                        child: Text(
                          DateFormat('dd/MM/yyyy').format(paymentDate),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  const Text(
                    'Vigencia:',
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
                              endDate = startDate.add(
                                Duration(days: daysToAdd),
                              );
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
                onPressed: () async {
                  final amount = double.tryParse(amountController.text) ?? 0.0;
                  await _processPayment(
                    amount,
                    paymentDate,
                    startDate,
                    endDate,
                  );
                  if (mounted) Navigator.pop(context);
                },
                child: const Text('Registrar'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _processPayment(
    double amount,
    DateTime payDate,
    DateTime start,
    DateTime end,
  ) async {
    final payment = PensionPayment(
      id: const Uuid().v4(),
      subscriberId: _subscriber.id,
      amount: amount,
      paymentDate: payDate,
      coverageStartDate: start,
      coverageEndDate: end,
      isSynced: false,
    );

    await DatabaseHelper.instance.insertPayment(payment);

    // Update Subscriber paid_until
    final currentPaidUntil = _subscriber.paidUntil != null
        ? DateTime.fromMillisecondsSinceEpoch(_subscriber.paidUntil!)
        : null;

    if (currentPaidUntil == null || end.isAfter(currentPaidUntil)) {
      final updatedSubscriber = _subscriber.copyWith(
        paidUntil: end.millisecondsSinceEpoch,
        isSynced: false,
      );
      await DatabaseHelper.instance.updateSubscriber(updatedSubscriber);
      if (mounted) {
        setState(() {
          _subscriber = updatedSubscriber;
        });
      }
    }

    if (mounted) {
      SoundService().playPaymentSuccess();
      context.read<SyncService>().syncData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago registrado exitosamente')),
      );
      _loadPayments();
    }
  }

  Future<void> _toggleAccountStatus() async {
    final newStatus = !_subscriber.isActive;
    final action = newStatus ? 'Reactivar' : 'Cerrar';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action Cuenta'),
        content: Text(
          '¿Estás seguro de que deseas $action la cuenta de ${_subscriber.plate}?${!newStatus ? "\nNo se podrán registrar nuevos pagos." : ""}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action,
              style: TextStyle(color: newStatus ? Colors.green : Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final updatedSubscriber = _subscriber.copyWith(
        isActive: newStatus,
        isSynced: false,
      );

      await DatabaseHelper.instance.updateSubscriber(updatedSubscriber);

      if (mounted) {
        setState(() {
          _subscriber = updatedSubscriber;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cuenta ${newStatus ? "reactivada" : "cerrada"} exitosamente',
            ),
          ),
        );
      }
    }
  }

  Future<void> _deleteSubscriber() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Pensión'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar DEFINITIVAMENTE este registro?\n\nEsta acción no se puede deshacer y es solo para errores de captura.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteSubscriber(_subscriber.id);
      if (mounted) {
        Navigator.pop(context); // Go back to list
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Registro eliminado')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _subscriber.name ?? _subscriber.plate ?? 'Sin Identificación',
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _showEditSubscriberDialog,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') _deleteSubscriber();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Eliminar Registro'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Folio: ${_subscriber.folio ?? "N/A"}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Row(
                        children: [
                          if (!_subscriber.isActive)
                            const Chip(
                              label: Text(
                                'INACTIVA',
                                style: TextStyle(color: Colors.white),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(_subscriber.entryType),
                            backgroundColor: Colors.blue.withOpacity(0.1),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _subscriber.name ??
                        _subscriber.plate ??
                        'Sin Identificación',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (_subscriber.name != null && _subscriber.plate != null)
                    Text(
                      _subscriber.plate!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.attach_money, color: Colors.green),
                      Text(
                        '${_subscriber.monthlyFee.toStringAsFixed(2)} / ${_subscriber.periodicity == 'WEEKLY'
                            ? 'Semana'
                            : _subscriber.periodicity == 'BIWEEKLY'
                            ? 'Quincena'
                            : 'Mes'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                if (_subscriber.isActive)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showPaymentDialog,
                      icon: const Icon(Icons.payment),
                      label: const Text('REGISTRAR PAGO / RENOVAR'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _toggleAccountStatus,
                    icon: Icon(
                      _subscriber.isActive ? Icons.block : Icons.restore,
                      color: _subscriber.isActive ? Colors.red : Colors.green,
                    ),
                    label: Text(
                      _subscriber.isActive
                          ? 'CERRAR CUENTA (BAJA)'
                          : 'REACTIVAR CUENTA',
                      style: TextStyle(
                        color: _subscriber.isActive ? Colors.red : Colors.green,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: _subscriber.isActive ? Colors.red : Colors.green,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Historial de Pagos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Payments List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _payments.isEmpty
                ? const Center(child: Text('No hay pagos registrados'))
                : ListView.builder(
                    itemCount: _payments.length,
                    itemBuilder: (context, index) {
                      final payment = _payments[index];
                      final dateFormat = DateFormat('dd/MM/yyyy');
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          leading: const Icon(
                            Icons.receipt_long,
                            color: Colors.blueGrey,
                          ),
                          title: Text(
                            '\$${payment.amount.toStringAsFixed(2)} - ${dateFormat.format(payment.paymentDate)}',
                          ),
                          subtitle: Text(
                            'Vigencia: ${dateFormat.format(payment.coverageStartDate)} - ${dateFormat.format(payment.coverageEndDate)}',
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
