import 'package:uuid/uuid.dart';
import '../config/constants.dart';

/// Modelo de datos que representa a un Suscriptor de Pensión.
///
/// Este modelo mapea la tabla `pension_subscribers` de la base de datos local y remota.
/// Gestiona la información del cliente, su vehículo principal (opcional),
/// el tipo de pensión contratada y el estado de sus pagos.
class PensionSubscriber {
  /// Identificador único (UUID v4).
  final String id;

  /// Número de folio secuencial (puede ser nulo si se genera automáticamente).
  final int? folio;

  /// Placa del vehículo principal (opcional, ya que la pensión es por cliente).
  final String? plate;

  /// Tipo de ingreso/pensión (ej. 'NOCTURNO', 'DIA y NOCHE').
  /// Se mapea desde `entry_type_id` en el backend a un nombre descriptivo localmente.
  final String entryType;

  /// Costo mensual acordado ($).
  final double monthlyFee;

  /// Nombre del cliente o alias (Identificador principal).
  final String? name;

  /// Observaciones o notas adicionales sobre el suscriptor.
  final String? notes;

  /// Fecha de inicio de la pensión (Timestamp en milisegundos).
  final int? entryDate;

  /// Fecha hasta la cual está pagada la pensión (Timestamp en milisegundos).
  final int? paidUntil;

  /// Estado de la suscripción: true (Activa) o false (Cancelada/Baja).
  final bool isActive;

  /// Estado de sincronización: true (Sincronizado con servidor) o false (Cambios pendientes).
  final bool isSynced;

  PensionSubscriber({
    required this.id,
    this.folio,
    this.plate,
    required this.entryType,
    required this.monthlyFee,
    this.name,
    this.notes,
    this.entryDate,
    this.paidUntil,
    this.isActive = true,
    this.isSynced = false,
  });

  /// Convierte la instancia a un Mapa para insertar en SQLite.
  /// Maneja la conversión de booleanos a enteros (1/0).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'folio': folio,
      'plate': plate,
      'entry_type': entryType,
      'monthly_fee': monthlyFee,
      'name': name,
      'notes': notes,
      'entry_date': entryDate,
      'paid_until': paidUntil,
      'is_active': isActive ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  /// Crea una instancia desde un Mapa (DB local o JSON remoto).
  ///
  /// Incluye lógica robusta para conversión de tipos (String -> int/double)
  /// y manejo de valores nulos o formatos inesperados del backend.
  factory PensionSubscriber.fromMap(Map<String, dynamic> map) {
    return PensionSubscriber(
      id: map['id'],
      folio: map['folio'] is String ? int.tryParse(map['folio']) : map['folio'],
      plate: map['plate'],
      entryType:
          map['entry_type'] ??
          AppConstants.fallbackEntryTypeName, // Fallback de seguridad
      monthlyFee: map['monthly_fee'] is String
          ? double.tryParse(map['monthly_fee']) ?? 0.0
          : (map['monthly_fee'] as num?)?.toDouble() ?? 0.0,
      name: map['name'],
      notes: map['notes'],
      entryDate: map['entry_date'] is String
          ? int.tryParse(map['entry_date'])
          : map['entry_date'],
      paidUntil: map['paid_until'] is String
          ? int.tryParse(map['paid_until'])
          : map['paid_until'],
      isActive: map['is_active'] == 1 || map['is_active'] == '1',
      isSynced: map['is_synced'] == 1 || map['is_synced'] == '1',
    );
  }

  /// Crea una copia de la instancia con campos modificados.
  PensionSubscriber copyWith({
    String? id,
    int? folio,
    String? plate,
    String? entryType,
    double? monthlyFee,
    String? name,
    String? notes,
    int? entryDate,
    int? paidUntil,
    bool? isActive,
    bool? isSynced,
  }) {
    return PensionSubscriber(
      id: id ?? this.id,
      folio: folio ?? this.folio,
      plate: plate ?? this.plate,
      entryType: entryType ?? this.entryType,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      entryDate: entryDate ?? this.entryDate,
      paidUntil: paidUntil ?? this.paidUntil,
      isActive: isActive ?? this.isActive,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
