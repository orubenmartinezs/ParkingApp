import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../services/log_service.dart';

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registros del Sistema'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              context.read<LogService>().clear();
            },
          ),
        ],
      ),
      body: Consumer<LogService>(
        builder: (context, logService, child) {
          final logs = logService.logs;
          if (logs.isEmpty) {
            return const Center(
              child: Text('No hay registros'),
            );
          }
          return ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  leading: _getIconForType(log.type),
                  title: Text(
                    log.message,
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp),
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _getIconForType(String type) {
    switch (type) {
      case 'ERROR':
        return const Icon(Icons.error_outline, color: Colors.red);
      case 'WARNING':
        return const Icon(Icons.warning_amber_rounded, color: Colors.orange);
      case 'SUCCESS':
        return const Icon(Icons.check_circle_outline, color: Colors.green);
      default:
        return const Icon(Icons.info_outline, color: Colors.blue);
    }
  }
}
