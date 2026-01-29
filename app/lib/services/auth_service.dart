import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/config_models.dart';
import '../database/database_helper.dart';

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._init();
  AuthService._init();

  User? _currentUser;
  Timer? _inactivityTimer;
  static const int _timeoutMinutes = 30;

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;
  bool get isAdmin => _currentUser?.role == 'ADMIN';

  Future<bool> login(String userId, String pin) async {
    final db = DatabaseHelper.instance;
    // En una app real, esto debería usar hashing. Aquí es texto plano por simplicidad del prototipo.
    final users = await db.getAllUsers();
    try {
      final user = users.firstWhere(
        (u) => u.id == userId && u.isActive,
      );
      
      // Verificación simple de PIN
      if (user.pin == pin || (user.pin == null && pin.isEmpty)) {
        _currentUser = user;
        _startInactivityTimer();
        notifyListeners();
        return true;
      }
    } catch (e) {
      // Usuario no encontrado
    }
    return false;
  }

  void logout() {
    _currentUser = null;
    _inactivityTimer?.cancel();
    notifyListeners();
  }

  void _startInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(const Duration(minutes: _timeoutMinutes), () {
      logout();
    });
  }

  void resetInactivityTimer() {
    if (isAuthenticated) {
      _startInactivityTimer();
    }
  }
}
