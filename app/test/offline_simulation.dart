import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'dart:io';

// Importamos nuestros modelos (copiados simplificados para no depender de flutter/material en este script puro)
class ParkingRecord {
  final String id;
  final String plate;
  final DateTime entryTime;
  bool isSynced;

  ParkingRecord({
    required this.id,
    required this.plate,
    required this.entryTime,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plate': plate,
      'entry_time': entryTime.millisecondsSinceEpoch,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory ParkingRecord.fromMap(Map<String, dynamic> map) {
    return ParkingRecord(
      id: map['id'],
      plate: map['plate'],
      entryTime: DateTime.fromMillisecondsSinceEpoch(map['entry_time']),
      isSynced: map['is_synced'] == 1,
    );
  }
}

void main() async {
  // Inicializar FFI para SQLite en escritorio
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  print('🚗 INICIANDO SIMULACIÓN OFFLINE-FIRST 🚗');
  print('----------------------------------------');

  // 1. Crear Base de Datos
  final dbPath = join(Directory.current.path, 'simulation_parking.db');
  // Borrar si existe para prueba limpia
  if (File(dbPath).existsSync()) File(dbPath).deleteSync();
  
  print('📦 Creando base de datos local en: $dbPath');
  
  final db = await openDatabase(dbPath, version: 1, onCreate: (db, version) {
    return db.execute('''
      CREATE TABLE parking_records (
        id TEXT PRIMARY KEY,
        plate TEXT NOT NULL,
        entry_time INTEGER NOT NULL,
        exit_time INTEGER,
        cost REAL,
        is_synced INTEGER NOT NULL
      )
    ''');
  });

  // 2. Simular Modo OFFLINE
  print('\n📡 Estado: 🔴 OFFLINE (Sin Internet)');
  
  var record = ParkingRecord(
    id: Uuid().v4(),
    plate: 'TEST-001',
    entryTime: DateTime.now(),
    isSynced: false,
  );

  await db.insert('parking_records', record.toMap());
  print('💾 Vehículo ${record.plate} guardado localmente.');
  print('   Estado de sincronización: ${record.isSynced ? "✅ Sincronizado" : "⏳ Pendiente"}');

  // 3. Simular vuelta a ONLINE y Sincronización
  print('\n📡 Estado: 🟢 ONLINE (Internet detectado)');
  print('🔄 Buscando registros pendientes...');

  final result = await db.query('parking_records', where: 'is_synced = ?', whereArgs: [0]);
  final pendingRecords = result.map((m) => ParkingRecord.fromMap(m)).toList();

  print('📋 Encontrados ${pendingRecords.length} registros por sincronizar.');

  for (var r in pendingRecords) {
    print('☁️  Subiendo ${r.plate} a la nube...');
    await Future.delayed(Duration(milliseconds: 500)); // Simular red
    
    // Marcar como sincronizado
    await db.update(
      'parking_records', 
      {'is_synced': 1}, 
      where: 'id = ?', 
      whereArgs: [r.id]
    );
    print('✅ ${r.plate} sincronizado exitosamente.');
  }

  // 4. Verificar estado final
  final finalResult = await db.query('parking_records', where: 'id = ?', whereArgs: [record.id]);
  final finalRecord = ParkingRecord.fromMap(finalResult.first);
  
  print('\n📊 VERIFICACIÓN FINAL:');
  print('   Vehículo: ${finalRecord.plate}');
  print('   En base de datos local: SÍ');
  print('   Estado Cloud: ${finalRecord.isSynced ? "✅ SINCRONIZADO" : "❌ ERROR"}');

  await db.close();
  print('\n🎉 Simulación completada con éxito.');
}
