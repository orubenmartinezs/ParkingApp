import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

class LogEntry {
  final DateTime timestamp;
  final String message;
  final String type; // 'INFO', 'ERROR', 'WARNING', 'SUCCESS'

  LogEntry({
    required this.message,
    this.type = 'INFO',
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

class LogService extends ChangeNotifier {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs.reversed);

  void log(String message, {String type = 'INFO'}) {
    final entry = LogEntry(message: message, type: type);
    _logs.add(entry);
    
    // Also print to console for development
    debugPrint('[${type}] ${DateFormat('HH:mm:ss').format(entry.timestamp)}: $message');
    
    notifyListeners();
  }

  void info(String message) => log(message, type: 'INFO');
  void error(String message) => log(message, type: 'ERROR');
  void warning(String message) => log(message, type: 'WARNING');
  void success(String message) => log(message, type: 'SUCCESS');

  void clear() {
    _logs.clear();
    notifyListeners();
  }
}
