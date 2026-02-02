import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/parking_record.dart';

class PrinterService extends ChangeNotifier {
  // Singleton
  static final PrinterService _instance = PrinterService._internal();
  static PrinterService get instance => _instance;
  PrinterService._internal();

  List<BluetoothInfo> _devices = [];
  List<BluetoothInfo> get devices => _devices;

  bool _isScanning = false;
  bool get isScanning => _isScanning;

  bool _isConnected = false;
  bool get isConnected => _isConnected;

  String? _connectedDeviceId;
  String? get connectedDeviceId => _connectedDeviceId;

  // Initialize and check permissions
  Future<bool> init() async {
    // Request permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location, // Needed for scanning on older Android
    ].request();

    // Check if permissions granted
    bool granted = true;
    if (statuses[Permission.bluetoothScan]?.isDenied ?? false) granted = false;
    if (statuses[Permission.bluetoothConnect]?.isDenied ?? false)
      granted = false;

    if (granted) {
      _autoConnect();
    }

    return granted;
  }

  Future<void> _autoConnect() async {
    // Add small delay to let Bluetooth stack initialize
    await Future.delayed(const Duration(seconds: 1));

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedMac = prefs.getString('printer_mac');
      if (savedMac != null && savedMac.isNotEmpty) {
        // Only connect if not already connected
        if (!_isConnected) {
          if (kDebugMode) print('Attempting auto-connect to $savedMac...');
          bool result = await connect(savedMac);

          // Retry once if failed
          if (!result) {
            if (kDebugMode) print('Auto-connect failed, retrying in 2s...');
            await Future.delayed(const Duration(seconds: 2));
            await connect(savedMac);
          }
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error auto-connecting: $e');
    }
  }

  // Scan for devices
  Future<void> scan() async {
    _isScanning = true;
    _devices = [];
    notifyListeners();

    try {
      final List<BluetoothInfo> result =
          await PrintBluetoothThermal.pairedBluetooths;
      _devices = result;
    } catch (e) {
      if (kDebugMode) print('Error scanning: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  // Connect to device
  Future<bool> connect(String macAddress) async {
    try {
      final bool result = await PrintBluetoothThermal.connect(
        macPrinterAddress: macAddress,
      );
      _isConnected = result;
      if (result) {
        _connectedDeviceId = macAddress;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('printer_mac', macAddress);
      }
      notifyListeners();
      return result;
    } catch (e) {
      if (kDebugMode) print('Error connecting: $e');
      return false;
    }
  }

  // Disconnect
  Future<bool> disconnect() async {
    try {
      final bool result = await PrintBluetoothThermal.disconnect;
      _isConnected = !result;
      if (result) {
        _connectedDeviceId = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('printer_mac');
      }
      notifyListeners();
      return result;
    } catch (e) {
      return false;
    }
  }

  // Check connection status
  Future<bool> checkConnection() async {
    try {
      final bool result = await PrintBluetoothThermal.connectionStatus;
      _isConnected = result;
      notifyListeners();
      return result;
    } catch (e) {
      return false;
    }
  }

  // Test Print
  Future<bool> testPrint() async {
    if (!_isConnected) return false;

    try {
      // 1. Get capability profile
      final profile = await CapabilityProfile.load();

      // 2. Generate bytes using Generator (Paper size 58mm = 32 chars usually)
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      bytes += generator.reset();
      bytes += generator.text(
        'PRUEBA DE IMPRESION',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.feed(1);
      bytes += generator.text(
        'Parking Control',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        'Taranja Digital',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.feed(1);
      bytes += generator.text(
        '--------------------------------',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        'Si puedes leer esto,',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        'la impresora funciona!',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        '--------------------------------',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.feed(2);
      bytes += generator.cut();

      // 3. Send bytes to printer
      final result = await PrintBluetoothThermal.writeBytes(bytes);
      return result;
    } catch (e) {
      if (kDebugMode) print('Error printing: $e');
      return false;
    }
  }

  // Print Entry Ticket
  Future<bool> printEntryTicket(ParkingRecord record) async {
    if (!_isConnected) return false;

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      bytes += generator.reset();

      // Header
      bytes += generator.text(
        'PARKING CONTROL',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.feed(1);

      // Folio
      if (record.folio != null) {
        bytes += generator.text(
          'Folio: #${record.folio}',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size1,
            width: PosTextSize.size1,
          ),
        );
        bytes += generator.feed(1);
      }

      // Plate
      bytes += generator.text(
        record.plate,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.feed(1);

      // Entry Info
      bytes += generator.text(
        'Entrada:',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        DateFormat('dd/MM/yyyy HH:mm').format(record.entryTime),
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );

      // Details
      bytes += generator.text(
        'Tipo: ${record.clientType}',
        styles: const PosStyles(align: PosAlign.center),
      );

      if (record.tariff != null && record.tariff!.isNotEmpty) {
        bytes += generator.text(
          'Tarifa: ${record.tariff}',
          styles: const PosStyles(align: PosAlign.center),
        );
      }

      if (record.description != null && record.description!.isNotEmpty) {
        bytes += generator.text(
          record.description!,
          styles: const PosStyles(align: PosAlign.center),
        );
      }

      // Pre-Payment Info
      if ((record.amountPaid ?? 0) > 0) {
        bytes += generator.feed(1);
        bytes += generator.text(
          '¡PAGADO!',
          styles: const PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2,
            width: PosTextSize.size2,
          ),
        );
        bytes += generator.text(
          'Abonado: \$${record.amountPaid!.toStringAsFixed(2)}',
          styles: const PosStyles(align: PosAlign.center, bold: true),
        );
      }

      bytes += generator.feed(1);

      // Disclaimer (Compact)
      bytes += generator.text(
        '--------------------------------',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        '1. Boleto necesario para entrega.',
        styles: const PosStyles(align: PosAlign.left, codeTable: 'CP437'),
      );
      bytes += generator.text(
        '2. No nos hacemos responsables por objetos olvidados o fallas.',
        styles: const PosStyles(align: PosAlign.left, codeTable: 'CP437'),
      );
      bytes += generator.text(
        'NO ES COMPROBANTE FISCAL',
        styles: const PosStyles(align: PosAlign.center, bold: true),
      );
      bytes += generator.feed(2);
      bytes += generator.cut();

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      if (kDebugMode) print('Error printing entry ticket: $e');
      return false;
    }
  }

  // Print Exit Ticket
  Future<bool> printExitTicket(ParkingRecord record) async {
    if (!_isConnected || record.exitTime == null) return false;

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      bytes += generator.reset();

      // Header
      bytes += generator.text(
        'PARKING CONTROL',
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.feed(1);

      bytes += generator.text(
        'COMPROBANTE DE PAGO',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.feed(1);

      // Folio
      if (record.folio != null) {
        bytes += generator.text(
          'Folio: #${record.folio}',
          styles: const PosStyles(align: PosAlign.center),
        );
      }

      // Plate
      bytes += generator.text(
        record.plate,
        styles: const PosStyles(
          align: PosAlign.center,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );
      bytes += generator.feed(1);

      // Times
      bytes += generator.row([
        PosColumn(text: 'Entrada:', width: 4),
        PosColumn(
          text: DateFormat('dd/MM HH:mm').format(record.entryTime),
          width: 8,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
      bytes += generator.row([
        PosColumn(text: 'Salida:', width: 4),
        PosColumn(
          text: DateFormat('dd/MM HH:mm').format(record.exitTime!),
          width: 8,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      // Duration
      final duration = record.exitTime!.difference(record.entryTime);
      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;
      bytes += generator.row([
        PosColumn(text: 'Tiempo:', width: 4),
        PosColumn(
          text: '${hours}h ${minutes}m',
          width: 8,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      bytes += generator.text(
        '--------------------------------',
        styles: const PosStyles(align: PosAlign.center),
      );

      // Financials
      if (record.tariff != null) {
        bytes += generator.text(
          'Tarifa: ${record.tariff}',
          styles: const PosStyles(align: PosAlign.right),
        );
      }

      final total = record.cost ?? 0.0;
      bytes += generator.text(
        'TOTAL: \$${total.toStringAsFixed(2)}',
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
          height: PosTextSize.size2,
          width: PosTextSize.size2,
        ),
      );

      if ((record.amountPaid ?? 0) > 0) {
        bytes += generator.text(
          'Abonado: \$${record.amountPaid!.toStringAsFixed(2)}',
          styles: const PosStyles(align: PosAlign.right),
        );
        final remaining = total - (record.amountPaid ?? 0);
        if (remaining > 0) {
          bytes += generator.text(
            'Restante: \$${remaining.toStringAsFixed(2)}',
            styles: const PosStyles(align: PosAlign.right),
          );
        }
      }

      bytes += generator.feed(1);
      bytes += generator.text(
        'ESTE BOLETO NO ES UN',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.text(
        'COMPROBANTE FISCAL',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.feed(1);
      bytes += generator.text(
        'Gracias por su preferencia',
        styles: const PosStyles(align: PosAlign.center),
      );
      bytes += generator.feed(2);
      bytes += generator.cut();

      return await PrintBluetoothThermal.writeBytes(bytes);
    } catch (e) {
      if (kDebugMode) print('Error printing exit ticket: $e');
      return false;
    }
  }
}
