import '../config/constants.dart';

class ParkingRecord {
  final String id;
  final int? folio; // New: Sequential ID for receipts
  final String plate;
  final String? description; // Auto / Descripción
  final String
  clientType; // Deprecated but kept for compatibility or use as Entry Type Name
  final String? entryTypeId; // New: Link to EntryType
  final String? entryUserId; // New: Who received the car
  final DateTime entryTime;

  DateTime? exitTime;
  double? cost;
  String?
  tariff; // Deprecated but kept for compatibility or use as Tariff Type Name
  final String? tariffTypeId; // New: Link to TariffType
  final String? exitUserId; // New: Who processed the exit

  String? notes; // COMENTARIOS
  bool isSynced;
  final String? pensionSubscriberId;
  final double? amountPaid; // New: Prepaid amount
  final String? paymentStatus; // New: PAID, PENDING, PARTIAL

  ParkingRecord({
    required this.id,
    this.folio,
    required this.plate,
    this.description,
    this.clientType = AppConstants.fallbackEntryTypeName,
    this.entryTypeId,
    this.entryUserId,
    required this.entryTime,
    this.exitTime,
    this.cost,
    this.tariff,
    this.tariffTypeId,
    this.exitUserId,
    this.notes,
    this.isSynced = false,
    this.pensionSubscriberId,
    this.amountPaid,
    this.paymentStatus,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'folio': folio,
      'plate': plate,
      'description': description,
      'client_type': clientType,
      'entry_type_id': entryTypeId,
      'entry_user_id': entryUserId,
      'entry_time': entryTime.millisecondsSinceEpoch,
      'exit_time': exitTime?.millisecondsSinceEpoch,
      'cost': cost,
      'tariff': tariff,
      'tariff_type_id': tariffTypeId,
      'exit_user_id': exitUserId,
      'notes': notes,
      'is_synced': isSynced ? 1 : 0,
      'pension_subscriber_id': pensionSubscriberId,
      'amount_paid': amountPaid,
      'payment_status': paymentStatus,
    };
  }

  factory ParkingRecord.fromMap(Map<String, dynamic> map) {
    return ParkingRecord(
      id: map['id'],
      folio: map['folio'] is String ? int.tryParse(map['folio']) : map['folio'],
      plate: map['plate'],
      description: map['description'],
      clientType: map['client_type'] ?? AppConstants.fallbackEntryTypeName,
      entryTypeId: map['entry_type_id'],
      entryUserId: map['entry_user_id'],
      entryTime: DateTime.fromMillisecondsSinceEpoch(
        map['entry_time'] is String
            ? int.parse(map['entry_time'])
            : map['entry_time'],
      ),
      exitTime: map['exit_time'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              map['exit_time'] is String
                  ? int.parse(map['exit_time'])
                  : map['exit_time'],
            )
          : null,
      cost: map['cost'] is String
          ? double.tryParse(map['cost'])
          : (map['cost'] as num?)?.toDouble(),
      tariff: map['tariff'],
      tariffTypeId: map['tariff_type_id'],
      exitUserId: map['exit_user_id'],
      notes: map['notes'],
      isSynced: map['is_synced'] == 1 || map['is_synced'] == '1',
      pensionSubscriberId: map['pension_subscriber_id'],
      amountPaid: map['amount_paid'] is String
          ? double.tryParse(map['amount_paid'])
          : (map['amount_paid'] as num?)?.toDouble(),
      paymentStatus: map['payment_status'],
    );
  }

  ParkingRecord copyWith({
    String? id,
    String? plate,
    String? description,
    String? clientType,
    String? entryTypeId,
    String? entryUserId,
    DateTime? entryTime,
    DateTime? exitTime,
    double? cost,
    String? tariff,
    String? tariffTypeId,
    String? exitUserId,
    String? notes,
    bool? isSynced,
    String? pensionSubscriberId,
    double? amountPaid,
    String? paymentStatus,
  }) {
    return ParkingRecord(
      id: id ?? this.id,
      plate: plate ?? this.plate,
      description: description ?? this.description,
      clientType: clientType ?? this.clientType,
      entryTypeId: entryTypeId ?? this.entryTypeId,
      entryUserId: entryUserId ?? this.entryUserId,
      entryTime: entryTime ?? this.entryTime,
      exitTime: exitTime ?? this.exitTime,
      cost: cost ?? this.cost,
      tariff: tariff ?? this.tariff,
      tariffTypeId: tariffTypeId ?? this.tariffTypeId,
      exitUserId: exitUserId ?? this.exitUserId,
      notes: notes ?? this.notes,
      isSynced: isSynced ?? this.isSynced,
      pensionSubscriberId: pensionSubscriberId ?? this.pensionSubscriberId,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentStatus: paymentStatus ?? this.paymentStatus,
    );
  }
}
