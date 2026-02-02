import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';
import '../models/parking_record.dart';
import '../models/pension_subscriber.dart';
import '../models/pension_payment.dart';
import '../models/expense.dart';
import '../models/config_models.dart';
import '../config/constants.dart';
import '../services/log_service.dart';
import '../services/config_service.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('parking_app_prod.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 13,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      LogService().info('Actualizando base de datos a versión 2...');
      try {
        await db.execute(
          "ALTER TABLE pension_subscribers ADD COLUMN created_at TEXT",
        );
        await db.execute(
          "ALTER TABLE pension_subscribers ADD COLUMN updated_at TEXT",
        );
        await db.execute(
          "ALTER TABLE parking_records ADD COLUMN created_at TEXT",
        );
        await db.execute(
          "ALTER TABLE parking_records ADD COLUMN updated_at TEXT",
        );
        await db.execute(
          "ALTER TABLE pension_payments ADD COLUMN created_at TEXT",
        );
        await db.execute(
          "ALTER TABLE pension_payments ADD COLUMN updated_at TEXT",
        );
        LogService().success('Migración a versión 2 completada.');
      } catch (e) {
        LogService().error('Error en migración v2: $e');
      }
    }

    if (oldVersion < 3) {
      LogService().info('Actualizando base de datos a versión 3...');
      try {
        // Add is_synced column to config tables
        await db.execute(
          "ALTER TABLE users ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0",
        );
        await db.execute(
          "ALTER TABLE entry_types ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0",
        );
        await db.execute(
          "ALTER TABLE tariff_types ADD COLUMN is_synced INTEGER NOT NULL DEFAULT 0",
        );
        LogService().success('Migración a versión 3 completada.');
      } catch (e) {
        LogService().error('Error en migración v3: $e');
      }
    }

    if (oldVersion < 5) {
      LogService().info('Actualizando base de datos a versión 5...');
      try {
        await db.execute(
          "ALTER TABLE parking_records ADD COLUMN amount_paid REAL",
        );
        await db.execute(
          "ALTER TABLE parking_records ADD COLUMN payment_status TEXT",
        );
      } catch (e) {
        LogService().error('Error en migración v5: $e');
      }
    }

    if (oldVersion < 6) {
      LogService().info(
        'Actualizando base de datos a versión 6 (Corrección)...',
      );
      try {
        // Intentar agregar columnas de nuevo por si la instalación limpia v5 falló
        // Usamos try-catch individual para cada una por si alguna ya existe
        try {
          await db.execute(
            "ALTER TABLE parking_records ADD COLUMN amount_paid REAL",
          );
        } catch (_) {}
        try {
          await db.execute(
            "ALTER TABLE parking_records ADD COLUMN payment_status TEXT",
          );
        } catch (_) {}
      } catch (e) {
        LogService().error('Error en migración v6: $e');
      }
    }

    if (oldVersion < 7) {
      LogService().info(
        'Actualizando base de datos a versión 7 (Asegurar Columnas)...',
      );
      try {
        try {
          await db.execute(
            "ALTER TABLE parking_records ADD COLUMN amount_paid REAL",
          );
        } catch (_) {}
        try {
          await db.execute(
            "ALTER TABLE parking_records ADD COLUMN payment_status TEXT",
          );
        } catch (_) {}
      } catch (e) {
        LogService().error('Error en migración v7: $e');
      }
    }

    if (oldVersion < 8) {
      LogService().info('Actualizando base de datos a versión 8 (Gastos)...');
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS expenses (
            id TEXT PRIMARY KEY,
            description TEXT,
            amount REAL,
            category TEXT,
            expense_date INTEGER,
            user_id TEXT,
            is_synced INTEGER,
            created_at TEXT
          )
        ''');
      } catch (e) {
        LogService().error('Error en migración v8: $e');
      }
    }

    if (oldVersion < 9) {
      LogService().info(
        'Actualizando base de datos a versión 9 (Configuración Avanzada)...',
      );
      try {
        // Add expense_categories table
        await db.execute('''
          CREATE TABLE IF NOT EXISTS expense_categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT,
            is_active INTEGER NOT NULL,
            is_synced INTEGER NOT NULL DEFAULT 1,
            created_at TEXT,
            updated_at TEXT
          )
        ''');

        // Add default_tariff_id to entry_types
        await db.execute(
          "ALTER TABLE entry_types ADD COLUMN default_tariff_id TEXT",
        );
      } catch (e) {
        LogService().error('Error en migración v9: $e');
      }
    }
    if (oldVersion < 10) {
      LogService().info(
        'Actualizando base de datos a versión 10 (Print Config)...',
      );
      try {
        await db.execute(
          "ALTER TABLE entry_types ADD COLUMN should_print_ticket INTEGER DEFAULT 1",
        );
      } catch (e) {
        LogService().error('Error en migración v10: $e');
      }
    }

    if (oldVersion < 11) {
      LogService().info(
        'Actualizando base de datos a versión 11 (Default Entry Type)...',
      );
      try {
        await db.execute(
          "ALTER TABLE entry_types ADD COLUMN is_default INTEGER DEFAULT 0",
        );
      } catch (e) {
        LogService().error('Error en migración v11: $e');
      }
    }

    if (oldVersion < 12) {
      LogService().info(
        'Actualizando base de datos a versión 12 (Safety Check)...',
      );
      // Asegurar que existan columnas críticas
      try {
        await db.execute(
          "ALTER TABLE entry_types ADD COLUMN is_default INTEGER DEFAULT 0",
        );
      } catch (_) {}
      try {
        await db.execute(
          "ALTER TABLE entry_types ADD COLUMN should_print_ticket INTEGER DEFAULT 1",
        );
      } catch (_) {}
    }

    if (oldVersion < 13) {
      LogService().info(
        'Actualizando base de datos a versión 13 (Periodicidad Pensiones)...',
      );
      try {
        await db.execute(
          "ALTER TABLE pension_subscribers ADD COLUMN periodicity TEXT DEFAULT 'MONTHLY'",
        );
      } catch (e) {
        LogService().error('Error en migración v13: $e');
      }
    }
  }

  Future _createDB(Database db, int version) async {
    bool remoteSuccess = false;
    try {
      final schema = await _fetchRemoteSchema();
      if (schema.isNotEmpty) {
        LogService().info('Iniciando BD desde esquema REMOTO...');
        print('Inicializando BD desde esquema REMOTO...');
        for (var tableName in schema.keys) {
          String sql = schema[tableName]!;
          // Verificación básica de compatibilidad SQLite/limpieza si es necesario
          try {
            await db.execute(sql);
            LogService().success(
              'Tabla $tableName creada desde esquema remoto.',
            );
          } catch (e) {
            LogService().error('Error creando tabla $tableName: $e');
            print('SQL FAILED for $tableName: $sql');
            print('Error creando tabla $tableName desde SQL remoto: $e');
            throw Exception('SQL Remoto falló para $tableName');
          }
        }
        remoteSuccess = true;
      }
    } catch (e) {
      LogService().error(
        'Fallo al iniciar desde esquema remoto: $e. Usando LOCAL.',
      );
      print('Fallo al inicializar desde esquema remoto: $e. Usando LOCAL.');
    }

    if (!remoteSuccess) {
      LogService().warning('Usando esquema LOCAL de respaldo.');
      await _createLocalDB(db);
    }

    // Intentar obtener datos iniciales
    await _fetchInitialData(db);
  }

  // Método público para obtener datos iniciales
  Future<void> fetchInitialData() async {
    final db = await instance.database;
    await _fetchInitialData(db);
  }

  // --- Helper Methods ---

  Future<EntryType?> getDefaultEntryType() async {
    final db = await database;
    // 1. Buscar el marcado como default
    final List<Map<String, dynamic>> defaults = await db.query(
      'entry_types',
      where: 'is_default = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (defaults.isNotEmpty) {
      return EntryType.fromMap(defaults.first);
    }

    // 2. Si no hay default, usar el primero disponible
    final List<Map<String, dynamic>> all = await db.query(
      'entry_types',
      limit: 1,
      orderBy: 'name ASC',
    );
    if (all.isNotEmpty) {
      return EntryType.fromMap(all.first);
    }

    return null;
  }

  Future<void> _fetchInitialData(Database db) async {
    try {
      LogService().info('Descargando datos iniciales del servidor...');
      final response = await Dio().get(
        '${ConfigService.instance.apiUrl}/pull.php',
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        final data = response.data['data'];
        await processRemoteData(
          Map<String, dynamic>.from(data),
          existingDb: db,
        );
      } else {
        LogService().error(
          'Error en respuesta del servidor al descargar datos.',
        );
      }
    } catch (e) {
      LogService().error('Error descargando datos iniciales: $e');
      print('Error al obtener datos iniciales: $e');
    }
  }

  // Método público para procesar datos sincronizados (reutilizable por SyncService)
  /// Procesa los datos recibidos del servidor (pull.php) e inserta/actualiza la BD local.
  ///
  /// ### Lógica de Sincronización y Fechas:
  /// 1. **Prioridad Local**: Evita sobrescribir registros que tienen cambios pendientes en la App (`is_synced = 0`).
  ///    Esto previene que un usuario pierda datos si editó algo offline y luego sincronizó.
  /// 2. **Inserción/Actualización**: Los datos del servidor reemplazan a los locales (si no hay cambios pendientes).
  /// 3. **Poda (Pruning)**: Elimina registros locales que ya no están en la respuesta del servidor.
  ///    - Si el servidor filtra por fecha (ej. "solo ayer y hoy"), la App eliminará todo lo anterior para mantenerse ligera.
  ///    - **Excepción Crucial**: Registros locales no sincronizados (`is_synced = 0`) NUNCA se eliminan, aunque el servidor no los envíe.
  ///
  /// ### Manejo de Tipos y Integridad de Datos:
  /// - **Conversión de Tipos**: Convierte robustamente Strings numéricos (JSON) a `int`/`double`/`bool` nativos de SQLite.
  /// - **Mapeo de Relaciones**: Resuelve IDs foráneos (ej. `entry_type_id`) a nombres descriptivos (`entry_type`)
  ///   usando catálogos locales. Esto asegura que la UI muestre "NOCTURNO" en lugar de un ID numérico "1".
  /// - **Fallbacks**: Si un mapeo falla, usa el valor original para evitar errores nulos.
  Future<void> processRemoteData(
    Map<String, dynamic> data, {
    Database? existingDb,
  }) async {
    final db = existingDb ?? await instance.database;

    // Usuarios
    if (data['users'] != null) {
      final List<Map<String, dynamic>> unsynced = await db.query(
        'users',
        columns: ['id'],
        where: 'is_synced = 0',
      );
      final unsyncedIds = unsynced.map((e) => e['id'] as String).toSet();

      final batch = db.batch();
      for (var item in data['users']) {
        if (unsyncedIds.contains(item['id'])) continue;

        var mutableItem = Map<String, dynamic>.from(item);
        mutableItem['is_synced'] = 1;

        // Limpieza: Eliminar 'password' si existe (campo heredado del remoto)
        if (mutableItem.containsKey('password')) {
          mutableItem.remove('password');
        }

        // Limpiar columnas no permitidas
        final allowedColumns = [
          'id',
          'name',
          'role',
          'pin',
          'is_active',
          'is_synced',
          'created_at',
          'updated_at',
        ];
        mutableItem.removeWhere((key, value) => !allowedColumns.contains(key));

        batch.insert(
          'users',
          mutableItem,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      LogService().info('Usuarios actualizados: ${data['users'].length}');

      // Poda de Usuarios
      final remoteIds = (data['users'] as List)
          .map((e) => e['id'].toString())
          .toSet();
      final localSynced = await db.query(
        'users',
        columns: ['id'],
        where: 'is_synced = 1',
      );
      final localSyncedIds = localSynced.map((e) => e['id'] as String).toSet();

      final idsToDelete = localSyncedIds.difference(remoteIds);
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) {
          batchDelete.delete('users', where: 'id = ?', whereArgs: [id]);
        }
        await batchDelete.commit(noResult: true);
        LogService().info('Poda: Eliminados ${idsToDelete.length} usuarios.');
      }
    }

    // Tipos de Ingreso
    if (data['entry_types'] != null) {
      final List<Map<String, dynamic>> unsynced = await db.query(
        'entry_types',
        columns: ['id'],
        where: 'is_synced = 0',
      );
      final unsyncedIds = unsynced.map((e) => e['id'] as String).toSet();

      final batch = db.batch();
      for (var item in data['entry_types']) {
        if (unsyncedIds.contains(item['id'])) continue;

        var mutableItem = Map<String, dynamic>.from(item);
        mutableItem['is_synced'] = 1;

        // Limpieza
        final allowedColumns = [
          'id',
          'name',
          'is_active',
          'is_synced',
          'default_tariff_id',
          'created_at',
          'updated_at',
        ];
        mutableItem.removeWhere((key, value) => !allowedColumns.contains(key));

        batch.insert(
          'entry_types',
          mutableItem,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      LogService().info(
        'Tipos de Ingreso actualizados: ${data['entry_types'].length}',
      );

      // Poda de Tipos de Ingreso
      final remoteIds = (data['entry_types'] as List)
          .map((e) => e['id'].toString())
          .toSet();
      final localSynced = await db.query(
        'entry_types',
        columns: ['id'],
        where: 'is_synced = 1',
      );
      final localSyncedIds = localSynced.map((e) => e['id'] as String).toSet();

      final idsToDelete = localSyncedIds.difference(remoteIds);
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) {
          batchDelete.delete('entry_types', where: 'id = ?', whereArgs: [id]);
        }
        await batchDelete.commit(noResult: true);
        LogService().info(
          'Poda: Eliminados ${idsToDelete.length} tipos de ingreso.',
        );
      }
    }

    // Tipos de Tarifa
    if (data['tariff_types'] != null) {
      final List<Map<String, dynamic>> unsynced = await db.query(
        'tariff_types',
        columns: ['id'],
        where: 'is_synced = 0',
      );
      final unsyncedIds = unsynced.map((e) => e['id'] as String).toSet();

      final batch = db.batch();
      for (var item in data['tariff_types']) {
        if (unsyncedIds.contains(item['id'])) continue;

        var mutableItem = Map<String, dynamic>.from(item);
        mutableItem['is_synced'] = 1;

        // Limpieza
        final allowedColumns = [
          'id',
          'name',
          'is_active',
          'is_synced',
          'created_at',
          'updated_at',
        ];
        mutableItem.removeWhere((key, value) => !allowedColumns.contains(key));

        batch.insert(
          'tariff_types',
          mutableItem,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      LogService().info(
        'Tipos de Tarifa actualizados: ${data['tariff_types'].length}',
      );

      // Poda de Tipos de Tarifa
      final remoteIds = (data['tariff_types'] as List)
          .map((e) => e['id'].toString())
          .toSet();
      final localSynced = await db.query(
        'tariff_types',
        columns: ['id'],
        where: 'is_synced = 1',
      );
      final localSyncedIds = localSynced.map((e) => e['id'] as String).toSet();

      final idsToDelete = localSyncedIds.difference(remoteIds);
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) {
          batchDelete.delete('tariff_types', where: 'id = ?', whereArgs: [id]);
        }
        await batchDelete.commit(noResult: true);
        LogService().info('Poda: Eliminados ${idsToDelete.length} tarifas.');
      }
    }

    // Categorías de Gasto
    if (data['expense_categories'] != null) {
      final List<Map<String, dynamic>> unsynced = await db.query(
        'expense_categories',
        columns: ['id'],
        where: 'is_synced = 0',
      );
      final unsyncedIds = unsynced.map((e) => e['id'] as String).toSet();

      final batch = db.batch();
      for (var item in data['expense_categories']) {
        if (unsyncedIds.contains(item['id'])) continue;

        var mutableItem = Map<String, dynamic>.from(item);
        mutableItem['is_synced'] = 1;

        // Limpieza
        final allowedColumns = [
          'id',
          'name',
          'description',
          'is_active',
          'is_synced',
          'created_at',
          'updated_at',
        ];
        mutableItem.removeWhere((key, value) => !allowedColumns.contains(key));

        batch.insert(
          'expense_categories',
          mutableItem,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      LogService().info(
        'Categorías de Gasto actualizadas: ${data['expense_categories'].length}',
      );

      // Poda de Categorías de Gasto
      final remoteIds = (data['expense_categories'] as List)
          .map((e) => e['id'].toString())
          .toSet();
      final localSynced = await db.query(
        'expense_categories',
        columns: ['id'],
        where: 'is_synced = 1',
      );
      final localSyncedIds = localSynced.map((e) => e['id'] as String).toSet();

      final idsToDelete = localSyncedIds.difference(remoteIds);
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) {
          batchDelete.delete(
            'expense_categories',
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        await batchDelete.commit(noResult: true);
        LogService().info(
          'Poda: Eliminadas ${idsToDelete.length} categorías de gasto.',
        );
      }
    }

    // Suscriptores de Pensión
    if (data['pension_subscribers'] != null) {
      // Obtener IDs de items no sincronizados para evitar sobrescribir cambios locales
      final List<Map<String, dynamic>> unsynced = await db.query(
        'pension_subscribers',
        columns: ['id'],
        where: 'is_synced = 0',
      );
      final unsyncedIds = unsynced.map((e) => e['id'] as String).toSet();

      // Cargar mapa de Tipos de Ingreso para resolución ID -> Nombre
      final entryTypesList = await db.query('entry_types');
      final entryTypeMap = {
        for (var et in entryTypesList)
          et['id'].toString(): et['name'].toString(),
      };

      final batch = db.batch();
      for (var item in data['pension_subscribers']) {
        if (unsyncedIds.contains(item['id']))
          continue; // Saltar si tenemos cambios locales

        // Asegurar que el mapa sea mutable
        var mutableItem = Map<String, dynamic>.from(item);
        mutableItem['is_synced'] = 1;

        // Conversión de tipos para campos de pension_subscribers
        if (mutableItem.containsKey('folio')) {
          mutableItem['folio'] = mutableItem['folio'] is String
              ? int.tryParse(mutableItem['folio'])
              : mutableItem['folio'];
        }

        // Mapear entry_type_id (JSON) a entry_type (Nombre de Columna en BD)
        // Si el remoto envía entry_type_id, intentamos resolverlo al Nombre (ej. "NOCTURNO")
        // que es lo que la UI de la App espera en la columna TEXT 'entry_type'.
        if (mutableItem.containsKey('entry_type_id')) {
          final typeId = mutableItem['entry_type_id'].toString();
          if (entryTypeMap.containsKey(typeId)) {
            mutableItem['entry_type'] = entryTypeMap[typeId];
          } else {
            // Fallback: usar el ID o el entry_type existente si está presente
            mutableItem['entry_type'] = mutableItem['entry_type_id'];
          }
        }

        if (mutableItem.containsKey('monthly_fee')) {
          mutableItem['monthly_fee'] = mutableItem['monthly_fee'] is String
              ? double.tryParse(mutableItem['monthly_fee'])
              : mutableItem['monthly_fee'];
        }
        if (mutableItem.containsKey('entry_date')) {
          mutableItem['entry_date'] = mutableItem['entry_date'] is String
              ? int.tryParse(mutableItem['entry_date'])
              : mutableItem['entry_date'];
        }
        if (mutableItem.containsKey('paid_until')) {
          mutableItem['paid_until'] = mutableItem['paid_until'] is String
              ? int.tryParse(mutableItem['paid_until'])
              : mutableItem['paid_until'];
        }
        if (mutableItem.containsKey('is_active')) {
          // Asegurar 1/0 para SQLite
          if (mutableItem['is_active'] is bool) {
            mutableItem['is_active'] = mutableItem['is_active'] ? 1 : 0;
          } else {
            mutableItem['is_active'] =
                int.tryParse(mutableItem['is_active'].toString()) ?? 0;
          }
        }

        // GARANTÍA DE INTEGRIDAD: Asegurar que entry_type nunca sea nulo
        if (!mutableItem.containsKey('entry_type') ||
            mutableItem['entry_type'] == null) {
          // Intentar obtener el tipo default, si no, usar el primero disponible
          final defaultType = await getDefaultEntryType();
          if (defaultType != null) {
            mutableItem['entry_type'] = defaultType.name;
          } else if (entryTypesList.isNotEmpty) {
            mutableItem['entry_type'] = entryTypesList.first['name'].toString();
          } else {
            // Último recurso absoluto si la tabla entry_types está vacía
            mutableItem['entry_type'] = AppConstants.fallbackEntryTypeName;
          }
        }

        // Limpieza
        final allowedColumns = [
          'id',
          'folio',
          'plate',
          'entry_type',
          'monthly_fee',
          'name',
          'notes',
          'entry_date',
          'paid_until',
          'is_active',
          'is_synced',
          'created_at',
          'updated_at',
        ];
        mutableItem.removeWhere((key, value) => !allowedColumns.contains(key));

        batch.insert(
          'pension_subscribers',
          mutableItem,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      LogService().info(
        'Suscriptores actualizados: ${data['pension_subscribers'].length}',
      );

      // Poda: Eliminar suscriptores sincronizados que no están en la lista activa remota
      final remoteIds = (data['pension_subscribers'] as List)
          .map((e) => e['id'].toString())
          .toSet();
      final localSynced = await db.query(
        'pension_subscribers',
        columns: ['id'],
        where: 'is_synced = 1',
      );
      final localSyncedIds = localSynced.map((e) => e['id'] as String).toSet();

      final idsToDelete = localSyncedIds.difference(remoteIds);
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) {
          batchDelete.delete(
            'pension_subscribers',
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        await batchDelete.commit(noResult: true);
        LogService().info(
          'Poda: Eliminados ${idsToDelete.length} suscriptores inactivos/cerrados.',
        );
      }
    }

    // Pagos de Pensión
    if (data['pension_payments'] != null) {
      final List<Map<String, dynamic>> unsynced = await db.query(
        'pension_payments',
        columns: ['id'],
        where: 'is_synced = 0',
      );
      final unsyncedIds = unsynced.map((e) => e['id'] as String).toSet();

      final batch = db.batch();
      for (var item in data['pension_payments']) {
        if (unsyncedIds.contains(item['id'])) continue;

        var mutableItem = Map<String, dynamic>.from(item);
        mutableItem['is_synced'] = 1;

        // Limpieza
        final allowedColumns = [
          'id',
          'subscriber_id',
          'amount',
          'payment_date',
          'coverage_start_date',
          'coverage_end_date',
          'notes',
          'is_synced',
          'created_at',
          'updated_at',
        ];
        mutableItem.removeWhere((key, value) => !allowedColumns.contains(key));

        batch.insert(
          'pension_payments',
          mutableItem,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      LogService().info(
        'Pagos actualizados: ${data['pension_payments'].length}',
      );
    }

    // Registros de Estacionamiento
    if (data['parking_records'] != null) {
      final List<Map<String, dynamic>> unsynced = await db.query(
        'parking_records',
        columns: ['id'],
        where: 'is_synced = 0',
      );
      final unsyncedIds = unsynced.map((e) => e['id'] as String).toSet();

      final batch = db.batch();
      for (var item in data['parking_records']) {
        if (unsyncedIds.contains(item['id'])) continue;

        var mutableItem = Map<String, dynamic>.from(item);
        mutableItem['is_synced'] = 1;

        // Conversión de tipos para campos de parking_records
        if (mutableItem.containsKey('folio')) {
          mutableItem['folio'] = mutableItem['folio'] is String
              ? int.tryParse(mutableItem['folio'])
              : mutableItem['folio'];
        }
        if (mutableItem.containsKey('entry_time')) {
          mutableItem['entry_time'] = mutableItem['entry_time'] is String
              ? int.tryParse(mutableItem['entry_time'])
              : mutableItem['entry_time'];
        }
        if (mutableItem.containsKey('exit_time')) {
          mutableItem['exit_time'] = mutableItem['exit_time'] is String
              ? int.tryParse(mutableItem['exit_time'])
              : mutableItem['exit_time'];
        }
        if (mutableItem.containsKey('cost')) {
          mutableItem['cost'] = mutableItem['cost'] is String
              ? double.tryParse(mutableItem['cost'])
              : mutableItem['cost'];
        }
        if (mutableItem.containsKey('amount_paid')) {
          mutableItem['amount_paid'] = mutableItem['amount_paid'] is String
              ? double.tryParse(mutableItem['amount_paid'])
              : mutableItem['amount_paid'];
        }

        // Limpieza
        final allowedColumns = [
          'id',
          'folio',
          'plate',
          'description',
          'client_type',
          'entry_type_id',
          'entry_user_id',
          'entry_time',
          'exit_time',
          'cost',
          'tariff',
          'tariff_type_id',
          'exit_user_id',
          'notes',
          'is_synced',
          'pension_subscriber_id',
          'amount_paid',
          'payment_status',
          'created_at',
          'updated_at',
        ];
        mutableItem.removeWhere((key, value) => !allowedColumns.contains(key));

        batch.insert(
          'parking_records',
          mutableItem,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      LogService().info(
        'Registros actualizados: ${data['parking_records'].length}',
      );

      // Poda: Eliminar registros sincronizados que no están en la lista activa/hoy remota
      final remoteIds = (data['parking_records'] as List)
          .map((e) => e['id'].toString())
          .toSet();
      final localSynced = await db.query(
        'parking_records',
        columns: ['id'],
        where: 'is_synced = 1',
      );
      final localSyncedIds = localSynced.map((e) => e['id'] as String).toSet();

      final idsToDelete = localSyncedIds.difference(remoteIds);
      if (idsToDelete.isNotEmpty) {
        final batchDelete = db.batch();
        for (var id in idsToDelete) {
          batchDelete.delete(
            'parking_records',
            where: 'id = ?',
            whereArgs: [id],
          );
        }
        await batchDelete.commit(noResult: true);
        LogService().info(
          'Poda: Eliminados ${idsToDelete.length} registros antiguos.',
        );
      }
    }

    // Gastos
    if (data['expenses'] != null) {
      final List<Map<String, dynamic>> unsynced = await db.query(
        'expenses',
        columns: ['id'],
        where: 'is_synced = 0',
      );
      final unsyncedIds = unsynced.map((e) => e['id'] as String).toSet();

      final batch = db.batch();
      for (var item in data['expenses']) {
        if (unsyncedIds.contains(item['id'])) continue;

        var mutableItem = Map<String, dynamic>.from(item);
        mutableItem['is_synced'] = 1;

        // Eliminar 'table' si está presente (del backend)
        mutableItem.remove('table');

        // Limpieza
        final allowedColumns = [
          'id',
          'description',
          'amount',
          'category',
          'expense_date',
          'user_id',
          'is_synced',
          'created_at',
          'updated_at',
        ];
        mutableItem.removeWhere((key, value) => !allowedColumns.contains(key));

        batch.insert(
          'expenses',
          mutableItem,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
      LogService().info('Gastos actualizados: ${data['expenses'].length}');
    }
  }

  Future<Map<String, String>> _fetchRemoteSchema() async {
    try {
      LogService().info('Conectando a servidor para obtener esquema...');
      // Timeout corto para evitar bloquear el inicio
      final response = await Dio().get(
        '${ConfigService.instance.apiUrl}/schema.php',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      if (response.statusCode == 200 && response.data['status'] == 'success') {
        LogService().success('Esquema remoto obtenido exitosamente.');
        return Map<String, String>.from(response.data['schema']);
      }
    } catch (e) {
      LogService().error('Error conectando al servidor: $e');
      print('Error al obtener esquema remoto: $e');
    }
    return {};
  }

  Future _createLocalDB(Database db) async {
    await db.execute('''
    CREATE TABLE parking_records (
      id TEXT PRIMARY KEY,
      folio INTEGER,
      plate TEXT NOT NULL,
      description TEXT,
      client_type TEXT NOT NULL DEFAULT 'SIN_CATEGORIA',
      entry_type_id TEXT,
      entry_user_id TEXT,
      entry_time INTEGER NOT NULL,
      exit_time INTEGER,
      cost REAL,
      tariff TEXT,
      tariff_type_id TEXT,
      exit_user_id TEXT,
      notes TEXT,
      is_synced INTEGER NOT NULL,
      pension_subscriber_id TEXT,
      amount_paid REAL,
      payment_status TEXT,
      created_at TEXT,
      updated_at TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE pension_subscribers (
      id TEXT PRIMARY KEY,
      folio INTEGER,
      plate TEXT,
      entry_type TEXT NOT NULL,
      monthly_fee REAL NOT NULL,
      name TEXT,
      notes TEXT,
      entry_date INTEGER,
      paid_until INTEGER,
      is_active INTEGER NOT NULL,
      is_synced INTEGER NOT NULL,
      periodicity TEXT DEFAULT 'MONTHLY',
      created_at TEXT,
      updated_at TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE pension_payments (
      id TEXT PRIMARY KEY,
      subscriber_id TEXT NOT NULL,
      amount REAL NOT NULL,
      payment_date INTEGER NOT NULL,
      coverage_start_date INTEGER NOT NULL,
      coverage_end_date INTEGER NOT NULL,
      notes TEXT,
      is_synced INTEGER NOT NULL,
      created_at TEXT,
      updated_at TEXT,
      FOREIGN KEY(subscriber_id) REFERENCES pension_subscribers(id)
    )
    ''');

    await db.execute('''
    CREATE TABLE users (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      role TEXT NOT NULL,
      pin TEXT,
      is_active INTEGER NOT NULL,
      is_synced INTEGER NOT NULL DEFAULT 1,
      created_at TEXT,
      updated_at TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE entry_types (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      is_active INTEGER NOT NULL,
      is_synced INTEGER NOT NULL DEFAULT 1,
      default_tariff_id TEXT,
      should_print_ticket INTEGER DEFAULT 1,
      is_default INTEGER DEFAULT 0,
      created_at TEXT,
      updated_at TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE tariff_types (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      default_cost REAL DEFAULT 0.0,
      cost_first_period REAL DEFAULT 0.0,
      cost_next_period REAL DEFAULT 0.0,
      period_minutes INTEGER DEFAULT 60,
      tolerance_minutes INTEGER DEFAULT 15,
      is_active INTEGER NOT NULL,
      is_synced INTEGER NOT NULL DEFAULT 1,
      created_at TEXT,
      updated_at TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE sequences (
      name TEXT PRIMARY KEY,
      current_val INTEGER NOT NULL DEFAULT 0
    )
    ''');

    await db.execute('''
    CREATE TABLE expenses (
      id TEXT PRIMARY KEY,
      description TEXT,
      amount REAL,
      category TEXT,
      expense_date INTEGER,
      user_id TEXT,
      is_synced INTEGER,
      created_at TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE expense_categories (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      description TEXT,
      is_active INTEGER NOT NULL,
      is_synced INTEGER NOT NULL DEFAULT 1,
      created_at TEXT,
      updated_at TEXT
    )
    ''');

    // Sin datos iniciales (seeders) según requerimiento de iniciar limpio
  }

  // Método auxiliar para obtener el siguiente valor de secuencia
  Future<int> getNextSequence(String sequenceName) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      await txn.rawInsert(
        'INSERT OR IGNORE INTO sequences(name, current_val) VALUES(?, 0)',
        [sequenceName],
      );
      await txn.rawUpdate(
        'UPDATE sequences SET current_val = current_val + 1 WHERE name = ?',
        [sequenceName],
      );
      final result = await txn.query(
        'sequences',
        columns: ['current_val'],
        where: 'name = ?',
        whereArgs: [sequenceName],
      );
      return result.first['current_val'] as int;
    });
  }

  // Método de Respaldo
  Future<String> backupDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'parking_app_prod.db');
    final backupPath = join(
      dbPath,
      'parking_app_prod_backup_${DateTime.now().millisecondsSinceEpoch}.db',
    );

    final file = File(path);
    if (await file.exists()) {
      await file.copy(backupPath);
      return backupPath;
    }
    throw Exception('Database file not found');
  }

  // Métodos de Registros (Records)
  Future<void> insertRecord(ParkingRecord record) async {
    final db = await instance.database;
    // Si no se proporciona folio (lo cual es usual), obtener el siguiente
    var recordToInsert = record.toMap();
    if (record.folio == null) {
      final nextFolio = await getNextSequence('parking_record');
      recordToInsert['folio'] = nextFolio;
    }

    await db.insert(
      'parking_records',
      recordToInsert,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ParkingRecord?> getRecordById(String id) async {
    final db = await instance.database;
    final result = await db.query(
      'parking_records',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      return ParkingRecord.fromMap(result.first);
    }
    return null;
  }

  Future<List<ParkingRecord>> getAllRecords() async {
    final db = await instance.database;
    final result = await db.query(
      'parking_records',
      orderBy: 'entry_time DESC',
    );
    return result.map((json) => ParkingRecord.fromMap(json)).toList();
  }

  /// Obtiene registros para la pantalla principal (Home).
  ///
  /// Filtro:
  /// - Vehículos activos (exit_time IS NULL).
  /// - Vehículos que salieron HOY (según la fecha local del dispositivo).
  ///
  /// Nota: Aunque el servidor envía registros desde "ayer" para seguridad por zona horaria,
  /// aquí filtramos estrictamente para mostrar la operación del día en curso.
  Future<List<ParkingRecord>> getTodayAndActiveRecords(DateTime now) async {
    final db = await instance.database;
    final startOfDay = DateTime(now.year, now.month, now.day, 0, 0, 0);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final startMs = startOfDay.millisecondsSinceEpoch;
    final endMs = endOfDay.millisecondsSinceEpoch;

    final result = await db.query(
      'parking_records',
      where: 'exit_time IS NULL OR (exit_time >= ? AND exit_time <= ?)',
      whereArgs: [startMs, endMs],
      orderBy: 'entry_time DESC',
    );
    return result.map((json) => ParkingRecord.fromMap(json)).toList();
  }

  Future<List<ParkingRecord>> getParkingRecordsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await instance.database;
    final startMs = start.millisecondsSinceEpoch;
    final endMs = end.millisecondsSinceEpoch;
    final result = await db.query(
      'parking_records',
      where:
          '(entry_time >= ? AND entry_time <= ?) OR (exit_time >= ? AND exit_time <= ?)',
      whereArgs: [startMs, endMs, startMs, endMs],
      orderBy: 'entry_time DESC',
    );
    return result.map((json) => ParkingRecord.fromMap(json)).toList();
  }

  // Métodos de Gastos
  Future<int> insertExpense(Expense expense) async {
    final db = await instance.database;
    return await db.insert(
      'expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Expense>> getExpenses() async {
    final db = await instance.database;
    final result = await db.query('expenses', orderBy: 'expense_date DESC');
    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<List<Expense>> getExpensesByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await instance.database;
    final result = await db.query(
      'expenses',
      where: 'expense_date >= ? AND expense_date <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'expense_date DESC',
    );
    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<int> deleteExpense(String id) async {
    final db = await instance.database;
    return await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateExpense(Expense expense) async {
    final db = await instance.database;
    return await db.update(
      'expenses',
      expense.toMap(),
      where: 'id = ?',
      whereArgs: [expense.id],
    );
  }

  Future<List<Expense>> getUnsyncedExpenses() async {
    final db = await instance.database;
    final result = await db.query('expenses', where: 'is_synced = 0');
    return result.map((json) => Expense.fromMap(json)).toList();
  }

  Future<List<ParkingRecord>> getUnsyncedRecords() async {
    final db = await instance.database;
    final result = await db.query(
      'parking_records',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return result.map((json) => ParkingRecord.fromMap(json)).toList();
  }

  Future<List<PensionPayment>> getUnsyncedPayments() async {
    final db = await instance.database;
    final result = await db.query(
      'pension_payments',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return result.map((json) => PensionPayment.fromMap(json)).toList();
  }

  Future<void> updateRecord(ParkingRecord record) async {
    final db = await instance.database;
    await db.update(
      'parking_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<void> deleteRecord(String id) async {
    final db = await instance.database;
    await db.delete('parking_records', where: 'id = ?', whereArgs: [id]);
  }

  // Subscribers Methods
  Future<void> insertSubscriber(PensionSubscriber subscriber) async {
    final db = await instance.database;
    // If folio is not provided, get next one
    var subscriberToInsert = subscriber.toMap();
    if (subscriber.folio == null) {
      final nextFolio = await getNextSequence('pension_subscriber');
      subscriberToInsert['folio'] = nextFolio;
    }
    await db.insert(
      'pension_subscribers',
      subscriberToInsert,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PensionSubscriber>> getAllSubscribers() async {
    final db = await instance.database;
    final result = await db.query('pension_subscribers', orderBy: 'name ASC');
    return result.map((json) => PensionSubscriber.fromMap(json)).toList();
  }

  Future<List<PensionSubscriber>> getUnsyncedSubscribers() async {
    final db = await instance.database;
    final result = await db.query(
      'pension_subscribers',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return result.map((json) => PensionSubscriber.fromMap(json)).toList();
  }

  Future<void> updateSubscriber(PensionSubscriber subscriber) async {
    final db = await instance.database;
    await db.update(
      'pension_subscribers',
      subscriber.toMap(),
      where: 'id = ?',
      whereArgs: [subscriber.id],
    );
  }

  Future<void> deleteSubscriber(String id) async {
    final db = await instance.database;
    await db.delete('pension_subscribers', where: 'id = ?', whereArgs: [id]);
  }

  Future<PensionSubscriber?> getSubscriberByPlate(String plate) async {
    final db = await instance.database;
    final result = await db.query(
      'pension_subscribers',
      where: 'plate = ? AND is_active = 1',
      whereArgs: [plate],
    );

    if (result.isNotEmpty) {
      return PensionSubscriber.fromMap(result.first);
    }
    return null;
  }

  Future<PensionSubscriber?> getSubscriberById(String id) async {
    final db = await instance.database;
    final result = await db.query(
      'pension_subscribers',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (result.isNotEmpty) {
      return PensionSubscriber.fromMap(result.first);
    }
    return null;
  }

  // Payment Methods
  Future<void> insertPayment(PensionPayment payment) async {
    final db = await instance.database;
    await db.insert(
      'pension_payments',
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<PensionSubscriber>> getAllPensionSubscribers() async {
    final db = await instance.database;
    final result = await db.query('pension_subscribers', orderBy: 'folio DESC');
    return result.map((json) => PensionSubscriber.fromMap(json)).toList();
  }

  Future<void> insertPensionSubscriber(PensionSubscriber subscriber) async {
    final db = await instance.database;
    await db.insert(
      'pension_subscribers',
      subscriber.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updatePensionSubscriber(PensionSubscriber subscriber) async {
    final db = await instance.database;
    await db.update(
      'pension_subscribers',
      subscriber.toMap(),
      where: 'id = ?',
      whereArgs: [subscriber.id],
    );
  }

  Future<void> deletePensionSubscriber(String id) async {
    final db = await instance.database;
    await db.delete('pension_subscribers', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<PensionSubscriber>> getUnsyncedPensionSubscribers() async {
    final db = await instance.database;
    final result = await db.query(
      'pension_subscribers',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return result.map((json) => PensionSubscriber.fromMap(json)).toList();
  }

  Future<List<PensionPayment>> getPaymentsBySubscriber(
    String subscriberId,
  ) async {
    final db = await instance.database;
    final result = await db.query(
      'pension_payments',
      where: 'subscriber_id = ?',
      whereArgs: [subscriberId],
      orderBy: 'payment_date DESC',
    );
    return result.map((json) => PensionPayment.fromMap(json)).toList();
  }

  Future<List<PensionPayment>> getPensionPaymentsByDateRange(
    DateTime start,
    DateTime end,
  ) async {
    final db = await instance.database;
    final result = await db.query(
      'pension_payments',
      where: 'payment_date >= ? AND payment_date <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'payment_date DESC',
    );
    return result.map((json) => PensionPayment.fromMap(json)).toList();
  }

  Future<void> updatePayment(PensionPayment payment) async {
    final db = await instance.database;
    await db.update(
      'pension_payments',
      payment.toMap(),
      where: 'id = ?',
      whereArgs: [payment.id],
    );
  }

  // Config Methods
  Future<List<User>> getActiveUsers() async {
    final db = await instance.database;
    final result = await db.query(
      'users',
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
    return result.map((json) => User.fromMap(json)).toList();
  }

  Future<List<User>> getAllUsers() async {
    final db = await instance.database;
    final result = await db.query('users', orderBy: 'name ASC');
    return result.map((json) => User.fromMap(json)).toList();
  }

  Future<void> insertUser(User user) async {
    final db = await instance.database;
    await db.insert(
      'users',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateUser(User user) async {
    final db = await instance.database;
    await db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  Future<void> deleteUser(String id) async {
    final db = await instance.database;
    await db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<User>> getUnsyncedUsers() async {
    final db = await instance.database;
    final result = await db.query(
      'users',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return result.map((json) => User.fromMap(json)).toList();
  }

  Future<List<EntryType>> getActiveEntryTypes() async {
    final db = await instance.database;
    final result = await db.query(
      'entry_types',
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
    return result.map((json) => EntryType.fromMap(json)).toList();
  }

  Future<List<EntryType>> getAllEntryTypes() async {
    final db = await instance.database;
    final result = await db.query('entry_types', orderBy: 'name ASC');
    return result.map((json) => EntryType.fromMap(json)).toList();
  }

  Future<void> insertEntryType(EntryType type) async {
    final db = await instance.database;
    await db.insert(
      'entry_types',
      type.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateEntryType(EntryType type) async {
    final db = await instance.database;
    await db.update(
      'entry_types',
      type.toMap(),
      where: 'id = ?',
      whereArgs: [type.id],
    );
  }

  Future<void> deleteEntryType(String id) async {
    final db = await instance.database;
    await db.delete('entry_types', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<EntryType>> getUnsyncedEntryTypes() async {
    final db = await instance.database;
    final result = await db.query(
      'entry_types',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return result.map((json) => EntryType.fromMap(json)).toList();
  }

  // Expense Categories Methods
  Future<List<ExpenseCategory>> getActiveExpenseCategories() async {
    final db = await instance.database;
    final result = await db.query(
      'expense_categories',
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
    return result.map((json) => ExpenseCategory.fromMap(json)).toList();
  }

  Future<List<ExpenseCategory>> getAllExpenseCategories() async {
    final db = await instance.database;
    final result = await db.query('expense_categories', orderBy: 'name ASC');
    return result.map((json) => ExpenseCategory.fromMap(json)).toList();
  }

  Future<void> insertExpenseCategory(ExpenseCategory category) async {
    final db = await instance.database;
    await db.insert(
      'expense_categories',
      category.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateExpenseCategory(ExpenseCategory category) async {
    final db = await instance.database;
    await db.update(
      'expense_categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> deleteExpenseCategory(String id) async {
    final db = await instance.database;
    await db.delete('expense_categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<TariffType>> getActiveTariffTypes() async {
    final db = await instance.database;
    final result = await db.query(
      'tariff_types',
      where: 'is_active = 1',
      orderBy: 'name ASC',
    );
    return result.map((json) => TariffType.fromMap(json)).toList();
  }

  Future<List<TariffType>> getAllTariffTypes() async {
    final db = await instance.database;
    final result = await db.query('tariff_types', orderBy: 'name ASC');
    return result.map((json) => TariffType.fromMap(json)).toList();
  }

  Future<List<TariffType>> getUnsyncedTariffTypes() async {
    final db = await instance.database;
    final result = await db.query(
      'tariff_types',
      where: 'is_synced = ?',
      whereArgs: [0],
    );
    return result.map((json) => TariffType.fromMap(json)).toList();
  }

  Future<void> insertTariffType(TariffType type) async {
    final db = await instance.database;
    await db.insert(
      'tariff_types',
      type.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateTariffType(TariffType type) async {
    final db = await instance.database;
    await db.update(
      'tariff_types',
      type.toMap(),
      where: 'id = ?',
      whereArgs: [type.id],
    );
  }

  Future<void> deleteTariffType(String id) async {
    final db = await instance.database;
    await db.delete('tariff_types', where: 'id = ?', whereArgs: [id]);
  }

  // Suggestions
  Future<List<String>> getPlateSuggestions(String query) async {
    final db = await instance.database;
    if (query.length < 2) return [];

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT plate 
      FROM parking_records 
      WHERE plate LIKE ? AND plate IS NOT NULL AND plate != '' 
      GROUP BY plate 
      ORDER BY MAX(entry_time) DESC 
      LIMIT 10
      ''',
      ['%$query%'],
    );

    return List.generate(maps.length, (i) => maps[i]['plate'] as String);
  }

  Future<List<String>> getDescriptionSuggestions(String query) async {
    final db = await instance.database;
    if (query.length < 2) return [];

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT description 
      FROM parking_records 
      WHERE description LIKE ? AND description IS NOT NULL AND description != '' 
      GROUP BY description 
      ORDER BY MAX(entry_time) DESC 
      LIMIT 10
      ''',
      ['%$query%'],
    );

    return List.generate(maps.length, (i) => maps[i]['description'] as String);
  }

  Future<List<String>> getClientNameSuggestions(String query) async {
    final db = await instance.database;
    if (query.length < 2) return [];

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT name 
      FROM pension_subscribers 
      WHERE name LIKE ? AND name IS NOT NULL AND name != '' 
      GROUP BY name 
      ORDER BY MAX(created_at) DESC 
      LIMIT 10
      ''',
      ['%$query%'],
    );

    return List.generate(maps.length, (i) => maps[i]['name'] as String);
  }

  Future<List<String>> getExpenseCategorySuggestions(String query) async {
    final db = await instance.database;
    if (query.length < 2) return [];

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT category 
      FROM expenses 
      WHERE category LIKE ? AND category IS NOT NULL AND category != '' 
      GROUP BY category 
      ORDER BY MAX(expense_date) DESC 
      LIMIT 10
      ''',
      ['%$query%'],
    );

    return List.generate(maps.length, (i) => maps[i]['category'] as String);
  }

  Future<List<String>> getEntryTypeNameSuggestions(String query) async {
    final db = await instance.database;
    if (query.length < 2) return [];

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT name 
      FROM entry_types 
      WHERE name LIKE ? AND name IS NOT NULL AND name != '' 
      GROUP BY name 
      ORDER BY MAX(created_at) DESC 
      LIMIT 10
      ''',
      ['%$query%'],
    );

    return List.generate(maps.length, (i) => maps[i]['name'] as String);
  }

  Future<List<String>> getTariffTypeNameSuggestions(String query) async {
    final db = await instance.database;
    if (query.length < 2) return [];

    final List<Map<String, dynamic>> maps = await db.rawQuery(
      '''
      SELECT name 
      FROM tariff_types 
      WHERE name LIKE ? AND name IS NOT NULL AND name != '' 
      GROUP BY name 
      ORDER BY MAX(created_at) DESC 
      LIMIT 10
      ''',
      ['%$query%'],
    );

    return List.generate(maps.length, (i) => maps[i]['name'] as String);
  }
}
