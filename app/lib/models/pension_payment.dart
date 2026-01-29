class PensionPayment {
  final String id;
  final String subscriberId;
  final double amount;
  final DateTime paymentDate;
  final DateTime coverageStartDate;
  final DateTime coverageEndDate;
  final String? notes;
  bool isSynced;

  PensionPayment({
    required this.id,
    required this.subscriberId,
    required this.amount,
    required this.paymentDate,
    required this.coverageStartDate,
    required this.coverageEndDate,
    this.notes,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subscriber_id': subscriberId,
      'amount': amount,
      'payment_date': paymentDate.millisecondsSinceEpoch,
      'coverage_start_date': coverageStartDate.millisecondsSinceEpoch,
      'coverage_end_date': coverageEndDate.millisecondsSinceEpoch,
      'notes': notes,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory PensionPayment.fromMap(Map<String, dynamic> map) {
    return PensionPayment(
      id: map['id'],
      subscriberId: map['subscriber_id'],
      amount: map['amount'] is String
          ? double.tryParse(map['amount']) ?? 0.0
          : (map['amount'] as num?)?.toDouble() ?? 0.0,
      paymentDate: DateTime.fromMillisecondsSinceEpoch(
        map['payment_date'] is String
            ? int.parse(map['payment_date'])
            : map['payment_date'],
      ),
      coverageStartDate: DateTime.fromMillisecondsSinceEpoch(
        map['coverage_start_date'] is String
            ? int.parse(map['coverage_start_date'])
            : map['coverage_start_date'],
      ),
      coverageEndDate: DateTime.fromMillisecondsSinceEpoch(
        map['coverage_end_date'] is String
            ? int.parse(map['coverage_end_date'])
            : map['coverage_end_date'],
      ),
      notes: map['notes'],
      isSynced: map['is_synced'] == 1 || map['is_synced'] == '1',
    );
  }

  PensionPayment copyWith({
    String? id,
    String? subscriberId,
    double? amount,
    DateTime? paymentDate,
    DateTime? coverageStartDate,
    DateTime? coverageEndDate,
    String? notes,
    bool? isSynced,
  }) {
    return PensionPayment(
      id: id ?? this.id,
      subscriberId: subscriberId ?? this.subscriberId,
      amount: amount ?? this.amount,
      paymentDate: paymentDate ?? this.paymentDate,
      coverageStartDate: coverageStartDate ?? this.coverageStartDate,
      coverageEndDate: coverageEndDate ?? this.coverageEndDate,
      notes: notes ?? this.notes,
      isSynced: isSynced ?? this.isSynced,
    );
  }
}
