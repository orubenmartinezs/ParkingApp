import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import '../models/parking_record.dart';
import '../database/database_helper.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  List<ParkingRecord> _todayRecords = [];
  Map<String, String> _userNames = {}; // ID -> Name
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    // Load Users for name mapping
    final users = await _dbHelper.getAllUsers();
    final userMap = {for (var u in users) u.id: u.name};
    
    // Load Records
    final allRecords = await _dbHelper.getAllRecords();
    
    // Filter by selected date
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    final filtered = allRecords.where((r) {
      final matchesEntry = r.entryTime.isAfter(startOfDay) && r.entryTime.isBefore(endOfDay);
      final matchesExit = r.exitTime != null && 
                          r.exitTime!.isAfter(startOfDay) && 
                          r.exitTime!.isBefore(endOfDay);
      return matchesEntry || matchesExit;
    }).toList();

    if (mounted) {
      setState(() {
        _userNames = userMap;
        _todayRecords = filtered;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  Future<void> _exportToCsv() async {
    List<List<dynamic>> rows = [];
    // Headers
    rows.add([
      'ID',
      'Placa',
      'Tipo Cliente',
      'Entrada',
      'Salida',
      'Duración (Min)',
      'Costo',
      'Tarifa',
      'Cobrador',
      'Comentarios',
      'Estado'
    ]);

    // Data
    for (var record in _todayRecords) {
      final exitTimeStr = record.exitTime != null 
          ? DateFormat('HH:mm').format(record.exitTime!) 
          : '-';
      final duration = record.exitTime != null 
          ? record.exitTime!.difference(record.entryTime).inMinutes
          : 0;
      final cashierName = record.exitUserId != null 
          ? (_userNames[record.exitUserId] ?? 'Desconocido') 
          : '-';
      
      rows.add([
        record.id.substring(0, 8),
        record.plate,
        record.clientType,
        DateFormat('HH:mm').format(record.entryTime),
        exitTimeStr,
        duration,
        record.cost?.toStringAsFixed(2) ?? '0.00',
        record.tariff ?? '-',
        cashierName,
        record.notes ?? '',
        record.exitTime != null ? 'Completado' : 'En Sitio'
      ]);
    }

    String csv = const ListToCsvConverter().convert(rows);

    try {
      final directory = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final path = '${directory.path}/cierre_caja_$dateStr.csv';
      final file = File(path);
      await file.writeAsString(csv);
      
      if (!await file.exists()) {
        throw Exception('El archivo no pudo ser creado en $path');
      }

      final xFile = XFile(path, mimeType: 'text/csv');
      await Share.shareXFiles([xFile], text: 'Cierre de Caja $dateStr');
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error al Exportar'),
            content: Text('No se pudo compartir el archivo.\n\nDetalle: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Calculations
    final completedRecords = _todayRecords.where((r) => r.exitTime != null).toList();
    final pendingRecords = _todayRecords.where((r) => r.exitTime == null).toList();
    final totalCollected = completedRecords.fold<double>(0, (sum, r) => sum + (r.cost ?? 0));

    // Breakdown by User (Cashier)
    final Map<String, double> salesByUser = {};
    for (var r in completedRecords) {
      final userId = r.exitUserId ?? 'Desconocido';
      final userName = _userNames[userId] ?? 'Desconocido';
      salesByUser[userName] = (salesByUser[userName] ?? 0) + (r.cost ?? 0);
    }

    // Breakdown by Tariff Type
    final Map<String, double> salesByTariff = {};
    for (var r in completedRecords) {
      final tariff = r.tariff ?? 'General';
      salesByTariff[tariff] = (salesByTariff[tariff] ?? 0) + (r.cost ?? 0);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cierre del Día'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _exportToCsv,
            tooltip: 'Exportar CSV',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Summary Card
                  Card(
                    color: Theme.of(context).primaryColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            DateFormat('EEEE d, MMMM y', 'es').format(_selectedDate),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryItem('Ingresos', '${_todayRecords.length}', isDark: true),
                              _buildSummaryItem('Ventas', '\$${totalCollected.toStringAsFixed(2)}', isDark: true),
                              _buildSummaryItem('En Sitio', '${pendingRecords.length}', isDark: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sales by User
                  if (salesByUser.isNotEmpty) ...[
                    const Text('Ventas por Cobrador', 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: salesByUser.entries.map((e) => ListTile(
                          leading: const Icon(Icons.person, color: Colors.blueGrey),
                          title: Text(e.key),
                          trailing: Text('\$${e.value.toStringAsFixed(2)}', 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Sales by Tariff
                  if (salesByTariff.isNotEmpty) ...[
                    const Text('Ventas por Tarifa', 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Card(
                      child: Column(
                        children: salesByTariff.entries.map((e) => ListTile(
                          leading: const Icon(Icons.price_change, color: Colors.green),
                          title: Text(e.key),
                          trailing: Text('\$${e.value.toStringAsFixed(2)}', 
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Pending List (Autos en resguardo)
                  if (pendingRecords.isNotEmpty) ...[
                    const Text('Autos en Sitio (Posible Pensión/Nocturno)', 
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: pendingRecords.length,
                      itemBuilder: (context, index) {
                        final record = pendingRecords[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.nightlight_round, color: Colors.indigo),
                            title: Text(record.plate),
                            subtitle: Text('Entrada: ${DateFormat('HH:mm').format(record.entryTime)} - ${record.clientType}'),
                            trailing: Text(record.notes ?? ''),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Completed List
                  const Text('Detalle de Salidas', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: completedRecords.length,
                    itemBuilder: (context, index) {
                      final record = completedRecords[index];
                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          title: Text('${record.plate} - ${record.tariff ?? 'General'}'),
                          subtitle: Text('${DateFormat('HH:mm').format(record.entryTime)} - ${DateFormat('HH:mm').format(record.exitTime!)}'),
                          trailing: Text('\$${record.cost?.toStringAsFixed(2)}', 
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value, {bool isDark = false}) {
    return Column(
      children: [
        Text(
          value, 
          style: TextStyle(
            fontSize: 24, 
            fontWeight: FontWeight.bold, 
            color: isDark ? Colors.white : Colors.blue
          )
        ),
        Text(
          label, 
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.grey
          )
        ),
      ],
    );
  }
}