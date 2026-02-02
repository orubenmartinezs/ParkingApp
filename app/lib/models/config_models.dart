class User {
  final String id;
  final String name;
  final String role; // 'ADMIN', 'STAFF'
  final String? pin; // Replaced password with pin
  final bool isActive;
  final bool isSynced;

  User({
    required this.id,
    required this.name,
    this.role = 'STAFF',
    this.pin,
    this.isActive = true,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'pin': pin,
      'is_active': isActive ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      role: map['role'],
      pin: map['pin'],
      isActive: map['is_active'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}

class EntryType {
  final String id;
  final String name;
  final bool isActive;
  final bool isSynced;
  final String? defaultTariffId;
  final bool shouldPrintTicket;
  final bool isDefault;

  EntryType({
    required this.id,
    required this.name,
    this.isActive = true,
    this.isSynced = false,
    this.defaultTariffId,
    this.shouldPrintTicket = true,
    this.isDefault = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'is_active': isActive ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
      'default_tariff_id': defaultTariffId,
      'should_print_ticket': shouldPrintTicket ? 1 : 0,
      'is_default': isDefault ? 1 : 0,
    };
  }

  factory EntryType.fromMap(Map<String, dynamic> map) {
    return EntryType(
      id: map['id'],
      name: map['name'],
      isActive: map['is_active'] == 1,
      isSynced: map['is_synced'] == 1,
      defaultTariffId: map['default_tariff_id'],
      shouldPrintTicket:
          map['should_print_ticket'] == 1 ||
          map['should_print_ticket'] ==
              null, // Default to true if null (migration)
      isDefault: map['is_default'] == 1,
    );
  }
}

class ExpenseCategory {
  final String id;
  final String name;
  final String? description;
  final bool isActive;
  final bool isSynced;

  ExpenseCategory({
    required this.id,
    required this.name,
    this.description,
    this.isActive = true,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'is_active': isActive ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseCategory(
      id: map['id'],
      name: map['name'],
      description: map['description'],
      isActive: map['is_active'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}

class TariffType {
  final String id;
  final String name;
  final double defaultCost;
  final double costFirstPeriod;
  final double costNextPeriod;
  final int periodMinutes;
  final int toleranceMinutes;
  final bool isActive;
  final bool isSynced;

  TariffType({
    required this.id,
    required this.name,
    this.defaultCost = 0.0,
    this.costFirstPeriod = 0.0,
    this.costNextPeriod = 0.0,
    this.periodMinutes = 60,
    this.toleranceMinutes = 15,
    this.isActive = true,
    this.isSynced = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'default_cost': defaultCost,
      'cost_first_period': costFirstPeriod,
      'cost_next_period': costNextPeriod,
      'period_minutes': periodMinutes,
      'tolerance_minutes': toleranceMinutes,
      'is_active': isActive ? 1 : 0,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  factory TariffType.fromMap(Map<String, dynamic> map) {
    return TariffType(
      id: map['id'],
      name: map['name'],
      defaultCost: double.tryParse(map['default_cost'].toString()) ?? 0.0,
      costFirstPeriod:
          double.tryParse(map['cost_first_period'].toString()) ?? 0.0,
      costNextPeriod:
          double.tryParse(map['cost_next_period'].toString()) ?? 0.0,
      periodMinutes: int.tryParse(map['period_minutes'].toString()) ?? 60,
      toleranceMinutes: int.tryParse(map['tolerance_minutes'].toString()) ?? 15,
      isActive: map['is_active'] == 1,
      isSynced: map['is_synced'] == 1,
    );
  }
}
