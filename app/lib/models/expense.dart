class Expense {
  final String id;
  final String description;
  final double amount;
  final String category;
  final DateTime expenseDate;
  final String? userId;
  final bool isSynced;
  final DateTime? createdAt;

  Expense({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.expenseDate,
    this.userId,
    this.isSynced = false,
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'category': category,
      'expense_date': expenseDate.millisecondsSinceEpoch,
      'user_id': userId,
      'is_synced': isSynced ? 1 : 0,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      description: map['description'],
      amount: map['amount'] is String
          ? double.tryParse(map['amount']) ?? 0.0
          : (map['amount'] as num?)?.toDouble() ?? 0.0,
      category: map['category'],
      expenseDate: DateTime.fromMillisecondsSinceEpoch(
        map['expense_date'] is String
            ? int.parse(map['expense_date'])
            : map['expense_date'],
      ),
      userId: map['user_id'],
      isSynced: map['is_synced'] == 1 || map['is_synced'] == '1',
      createdAt:
          map['created_at'] != null ? DateTime.tryParse(map['created_at']) : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'description': description,
      'amount': amount,
      'category': category,
      'expense_date': expenseDate.millisecondsSinceEpoch,
      'user_id': userId,
      'table': 'expenses',
    };
  }
}
