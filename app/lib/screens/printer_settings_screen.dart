import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen> {
  final PrinterService _printerService = PrinterService.instance;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initPrinter();
  }

  Future<void> _initPrinter() async {
    setState(() => _isLoading = true);
    await _printerService.init();
    await _printerService.scan();
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Impresora'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initPrinter,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _printerService,
        builder: (context, _) {
          return Column(
            children: [
              // Estado de Conexión
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey[100],
                child: Row(
                  children: [
                    Icon(
                      _printerService.isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                      color: _printerService.isConnected ? Colors.green : Colors.grey,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _printerService.isConnected ? 'Conectado' : 'Desconectado',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        if (_printerService.connectedDeviceId != null)
                          Text(_printerService.connectedDeviceId!, style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    const Spacer(),
                    if (_printerService.isConnected)
                      TextButton(
                        onPressed: () async {
                          await _printerService.disconnect();
                          setState(() {});
                        },
                        child: const Text('Desconectar', style: TextStyle(color: Colors.red)),
                      ),
                  ],
                ),
              ),
              
              const Divider(height: 1),

              // Botón de Prueba
              if (_printerService.isConnected)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.print),
                      label: const Text('IMPRIMIR TICKET DE PRUEBA'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () async {
                        final success = await _printerService.testPrint();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(success ? 'Impresión enviada' : 'Error al imprimir'),
                              backgroundColor: success ? Colors.green : Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ),

              // Lista de Dispositivos
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Dispositivos Emparejados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _printerService.devices.isEmpty
                        ? const Center(child: Text('No se encontraron impresoras.\nAsegúrate de que esté encendida y emparejada en los ajustes de Bluetooth.'))
                        : ListView.builder(
                            itemCount: _printerService.devices.length,
                            itemBuilder: (context, index) {
                              final device = _printerService.devices[index];
                              final isConnected = device.macAdress == _printerService.connectedDeviceId;

                              return ListTile(
                                leading: const Icon(Icons.print),
                                title: Text(device.name ?? 'Dispositivo desconocido'),
                                subtitle: Text(device.macAdress),
                                trailing: isConnected
                                    ? const Icon(Icons.check_circle, color: Colors.green)
                                    : ElevatedButton(
                                        child: const Text('Conectar'),
                                        onPressed: () async {
                                          setState(() => _isLoading = true);
                                          final success = await _printerService.connect(device.macAdress);
                                          setState(() => _isLoading = false);
                                          
                                          if (success && mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Conectado exitosamente')),
                                            );
                                          }
                                        },
                                      ),
                              );
                            },
                          ),
              ),
            ],
          );
        },
      ),
    );
  }
}
