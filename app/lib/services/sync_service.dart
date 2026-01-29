import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import '../database/database_helper.dart';
import '../models/parking_record.dart';
import '../models/pension_payment.dart';
import '../models/pension_subscriber.dart';
import '../models/expense.dart';
import '../models/config_models.dart';
import '../services/log_service.dart';
import '../services/config_service.dart';
import '../services/sound_service.dart';

class SyncService extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Dio _dio = Dio();
  String get _baseUrl => '${ConfigService.instance.apiUrl}/sync.php';

  bool _isOnline = false;
  bool _isSyncing = false;

  bool get isOnline => _isOnline;
  bool get isSyncing => _isSyncing;

  SyncService() {
    _initConnectivity();
    Connectivity().onConnectivityChanged.listen(_updateConnectionStatus);
  }

  Future<void> _initConnectivity() async {
    final result = await Connectivity().checkConnectivity();
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    bool isConnected = results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet,
    );

    if (isConnected != _isOnline) {
      _isOnline = isConnected;
      notifyListeners();
      if (_isOnline) {
        LogService().info('Conexión detectada. Iniciando sincronización...');
        SoundService().playOnline();
        syncData();
      } else {
        LogService().warning('Conexión perdida. Modo offline.');
        SoundService().playOffline();
      }
    }
  }

  Future<void> syncData() async {
    if (_isSyncing || !_isOnline) return;

    _isSyncing = true;
    notifyListeners();
    LogService().info('Iniciando sincronización de datos...');
    SoundService().playSyncStart();

    try {
      // Sincronizar Usuarios
      final unsyncedUsers = await _dbHelper.getUnsyncedUsers();
      if (unsyncedUsers.isNotEmpty) {
        LogService().info('Sincronizando ${unsyncedUsers.length} usuarios...');
      }
      for (var user in unsyncedUsers) {
        await _uploadUser(user);
      }

      // Sincronizar Tipos de Ingreso
      final unsyncedEntryTypes = await _dbHelper.getUnsyncedEntryTypes();
      if (unsyncedEntryTypes.isNotEmpty) {
        LogService().info(
          'Sincronizando ${unsyncedEntryTypes.length} tipos de ingreso...',
        );
      }
      for (var type in unsyncedEntryTypes) {
        await _uploadEntryType(type);
      }

      // Sincronizar Tipos de Tarifa
      final unsyncedTariffTypes = await _dbHelper.getUnsyncedTariffTypes();
      if (unsyncedTariffTypes.isNotEmpty) {
        LogService().info(
          'Sincronizando ${unsyncedTariffTypes.length} tipos de tarifa...',
        );
      }
      for (var type in unsyncedTariffTypes) {
        await _uploadTariffType(type);
      }

      // Sincronizar Suscriptores (Primero, porque los pagos dependen de ellos)
      final unsyncedSubscribers = await _dbHelper.getUnsyncedSubscribers();
      if (unsyncedSubscribers.isNotEmpty) {
        LogService().info(
          'Sincronizando ${unsyncedSubscribers.length} suscriptores...',
        );
      }
      for (var subscriber in unsyncedSubscribers) {
        await _uploadSubscriber(subscriber);
      }

      // Sincronizar Registros
      final unsyncedRecords = await _dbHelper.getUnsyncedRecords();
      if (unsyncedRecords.isNotEmpty) {
        LogService().info(
          'Sincronizando ${unsyncedRecords.length} registros...',
        );
      }
      for (var record in unsyncedRecords) {
        await _uploadRecord(record);
      }

      // Sincronizar Pagos
      final unsyncedPayments = await _dbHelper.getUnsyncedPayments();
      if (unsyncedPayments.isNotEmpty) {
        LogService().info('Sincronizando ${unsyncedPayments.length} pagos...');
      }
      for (var payment in unsyncedPayments) {
        await _uploadPayment(payment);
      }

      // Sincronizar Gastos
      final unsyncedExpenses = await _dbHelper.getUnsyncedExpenses();
      if (unsyncedExpenses.isNotEmpty) {
        LogService().info('Sincronizando ${unsyncedExpenses.length} gastos...');
      }
      for (var expense in unsyncedExpenses) {
        await _uploadExpense(expense);
      }

      // Fase de Descarga
      LogService().info('Descargando cambios remotos...');
      await _downloadData();

      LogService().success('Sincronización completada.');
      SoundService().playSyncSuccess();
    } catch (e) {
      LogService().error('Error CRÍTICO de sincronización: $e');
      if (kDebugMode) {
        print('Sync error CRITICAL: $e');
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _uploadUser(User user) async {
    try {
      final response = await _dio.post(
        _baseUrl,
        data: {
          ...user.toMap(),
          'table':
              'users', // Pista para el backend si es necesario, aunque usualmente se maneja por el endpoint o estructura de datos
        },
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Crear una nueva instancia de Usuario con isSynced = true
        // Necesitamos usar copyWith pero el modelo User podría no tenerlo.
        // Revisemos el modelo User de nuevo o usemos el constructor.
        final syncedUser = User(
          id: user.id,
          name: user.name,
          role: user.role,
          pin: user.pin,
          isActive: user.isActive,
          isSynced: true,
        );
        await _dbHelper.updateUser(syncedUser);
        LogService().success('Usuario sincronizado: ${user.name}');
      }
    } catch (e) {
      LogService().error('Error subiendo usuario: $e');
    }
  }

  Future<void> _uploadEntryType(EntryType type) async {
    try {
      final response = await _dio.post(
        _baseUrl,
        data: {...type.toMap(), 'table': 'entry_types'},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final syncedType = EntryType(
          id: type.id,
          name: type.name,
          isActive: type.isActive,
          isSynced: true,
          defaultTariffId: type.defaultTariffId,
        );
        await _dbHelper.updateEntryType(syncedType);
        LogService().success('Tipo de ingreso sincronizado: ${type.name}');
      }
    } catch (e) {
      LogService().error('Error subiendo tipo de ingreso: $e');
    }
  }

  Future<void> _uploadTariffType(TariffType type) async {
    try {
      final response = await _dio.post(
        _baseUrl,
        data: {...type.toMap(), 'table': 'tariff_types'},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final syncedType = TariffType(
          id: type.id,
          name: type.name,
          isActive: type.isActive,
          isSynced: true,
        );
        await _dbHelper.updateTariffType(syncedType);
        LogService().success('Tipo de tarifa sincronizado: ${type.name}');
      }
    } catch (e) {
      LogService().error('Error subiendo tipo de tarifa: $e');
    }
  }

  Future<void> _uploadSubscriber(PensionSubscriber subscriber) async {
    try {
      final response = await _dio.post(
        _baseUrl,
        data: subscriber.toMap(),
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final syncedSubscriber = subscriber.copyWith(isSynced: true);
        await _dbHelper.updateSubscriber(syncedSubscriber);
        LogService().success('Suscripción sincronizada: ${subscriber.name}');
        if (kDebugMode) {
          print('Synced subscriber: ${subscriber.name}');
        }
      } else {
        LogService().error(
          'Fallo sincronizar suscriptor ${subscriber.name}: ${response.statusCode}',
        );
        if (kDebugMode) {
          print(
            'Failed to sync subscriber ${subscriber.name}: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      LogService().error(
        'Error sincronizando suscriptor ${subscriber.name}: $e',
      );
      if (kDebugMode) {
        print('Error syncing subscriber ${subscriber.name}: $e');
      }
    }
  }

  Future<void> _uploadRecord(ParkingRecord record) async {
    try {
      final response = await _dio.post(
        _baseUrl,
        data: record.toMap(),
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final syncedRecord = record.copyWith(isSynced: true);
        await _dbHelper.updateRecord(syncedRecord);
        LogService().success('Registro sincronizado: ${record.plate}');
        if (kDebugMode) {
          print('Synced record: ${record.plate}');
        }
      } else {
        LogService().error(
          'Fallo sincronizar registro ${record.plate}: ${response.statusCode}',
        );
        if (kDebugMode) {
          print(
            'Failed to sync record ${record.plate}: ${response.statusCode}',
          );
        }
      }
    } catch (e) {
      LogService().error('Error subiendo registro: $e');
      if (kDebugMode) {
        print('Error uploading record: $e');
      }
      rethrow; // Re-throw to stop sync process if connection fails
    }
  }

  Future<void> _uploadPayment(PensionPayment payment) async {
    try {
      final response = await _dio.post(
        _baseUrl,
        data: payment.toMap(),
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final syncedPayment = payment.copyWith(isSynced: true);
        await _dbHelper.updatePayment(syncedPayment);
        LogService().success(
          'Pago sincronizado para suscriptor: ${payment.subscriberId}',
        );
        if (kDebugMode) {
          print('Synced payment for: ${payment.subscriberId}');
        }
      }
    } catch (e) {
      LogService().error('Error subiendo pago: $e');
      if (kDebugMode) {
        print('Error uploading payment: $e');
      }
      // Don't rethrow here to allow other items to try
    }
  }

  Future<void> _uploadExpense(Expense expense) async {
    try {
      final response = await _dio.post(
        _baseUrl,
        data: {...expense.toMap(), 'table': 'expenses'},
        options: Options(
          headers: {'Content-Type': 'application/json'},
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final syncedExpense = Expense(
          id: expense.id,
          description: expense.description,
          amount: expense.amount,
          category: expense.category,
          expenseDate: expense.expenseDate,
          userId: expense.userId,
          createdAt: expense.createdAt,
          isSynced: true,
        );
        await _dbHelper.updateExpense(syncedExpense);
        LogService().success('Gasto sincronizado: ${expense.description}');
      }
    } catch (e) {
      LogService().error('Error subiendo gasto: $e');
    }
  }

  Future<void> _downloadData() async {
    try {
      final response = await _dio.get(
        '${ConfigService.instance.apiUrl}/pull.php',
        options: Options(
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 10),
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final data = response.data['data'];

        // Manejar Configuraciones (Zona Horaria)
        if (data['settings'] != null) {
          final settings = data['settings'];
          if (settings['timezone'] != null) {
            await ConfigService.instance.setTimezone(
              settings['timezone'].toString(),
            );
            LogService().info(
              'Zona horaria actualizada: ${settings['timezone']}',
            );
          }
        }

        await _dbHelper.processRemoteData(Map<String, dynamic>.from(data));
      } else {
        LogService().error('Error descargando datos: ${response.statusCode}');
      }
    } catch (e) {
      LogService().error('Error en descarga de datos: $e');
      if (kDebugMode) {
        print('Error downloading data: $e');
      }
    }
  }
}
