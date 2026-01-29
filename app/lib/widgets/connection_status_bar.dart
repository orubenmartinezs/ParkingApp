import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sync_service.dart';

class ConnectionStatusBar extends StatelessWidget {
  const ConnectionStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncService>(
      builder: (context, syncService, child) {
        return Container(
          color: syncService.isOnline ? Colors.green : Colors.red,
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                syncService.isOnline ? Icons.wifi : Icons.wifi_off,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                syncService.isOnline
                    ? (syncService.isSyncing
                        ? 'Sincronizando...'
                        : 'Conectado')
                    : 'Sin conexión',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
