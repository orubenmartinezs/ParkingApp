import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/parking_record.dart';

class TicketPreviewDialog extends StatelessWidget {
  final ParkingRecord record;
  final VoidCallback onPrint;
  final VoidCallback onCancel;

  const TicketPreviewDialog({
    super.key,
    required this.record,
    required this.onPrint,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Vista Previa del Ticket',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTicketContent(),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Cancelar'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onPrint,
                  icon: const Icon(Icons.print),
                  label: const Text('Imprimir'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTicketContent() {
    // Check if it's an Exit Ticket (has exitTime) or Entry Ticket
    bool isExit = record.exitTime != null;

    if (isExit) {
      return _buildExitTicket();
    } else {
      return _buildEntryTicket();
    }
  }

  Widget _buildEntryTicket() {
    return Column(
      children: [
        _text('PARKING CONTROL', isBold: true, size: 18, align: TextAlign.center),
        const SizedBox(height: 8),
        if (record.folio != null)
          _text('Folio: #${record.folio}', isBold: true, size: 16, align: TextAlign.center),
        const SizedBox(height: 8),
        _text(record.plate, isBold: true, size: 24, align: TextAlign.center),
        const SizedBox(height: 8),
        _text('Entrada:', align: TextAlign.center),
        _text(DateFormat('dd/MM/yyyy HH:mm').format(record.entryTime), isBold: true, align: TextAlign.center),
        const SizedBox(height: 8),
        _text('Tipo: ${record.clientType}', align: TextAlign.center),
        if (record.tariff != null && record.tariff!.isNotEmpty)
          _text('Tarifa: ${record.tariff}', align: TextAlign.center),
        if (record.description != null && record.description!.isNotEmpty)
          _text(record.description!, align: TextAlign.center),
        
        if ((record.amountPaid ?? 0) > 0) ...[
          const SizedBox(height: 16),
          _text('¡PAGADO!', isBold: true, size: 20, align: TextAlign.center),
          _text('Abonado: \$${record.amountPaid!.toStringAsFixed(2)}', isBold: true, align: TextAlign.center),
        ],
        
        const SizedBox(height: 16),
        _text('--------------------------------', align: TextAlign.center),
        _text('1. Boleto necesario para entrega.', align: TextAlign.left, size: 12),
        _text('2. No nos hacemos responsables por objetos olvidados o fallas.', align: TextAlign.left, size: 12),
        const SizedBox(height: 8),
        _text('NO ES COMPROBANTE FISCAL', isBold: true, align: TextAlign.center),
      ],
    );
  }

  Widget _buildExitTicket() {
    final duration = record.exitTime!.difference(record.entryTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final total = record.cost ?? 0.0;

    return Column(
      children: [
        _text('PARKING CONTROL', isBold: true, size: 18, align: TextAlign.center),
        const SizedBox(height: 8),
        _text('COMPROBANTE DE PAGO', align: TextAlign.center),
        if (record.folio != null)
          _text('Folio: #${record.folio}', align: TextAlign.center),
        const SizedBox(height: 8),
        _text(record.plate, isBold: true, size: 24, align: TextAlign.center),
        const SizedBox(height: 8),
        _row('Entrada:', DateFormat('dd/MM HH:mm').format(record.entryTime)),
        _row('Salida:', DateFormat('dd/MM HH:mm').format(record.exitTime!)),
        _row('Tiempo:', '${hours}h ${minutes}m'),
        const SizedBox(height: 8),
        _text('--------------------------------', align: TextAlign.center),
        if (record.tariff != null)
          _text('Tarifa: ${record.tariff}', align: TextAlign.right),
        
        const SizedBox(height: 8),
        _text('TOTAL: \$${total.toStringAsFixed(2)}', isBold: true, size: 18, align: TextAlign.right),
        
        if ((record.amountPaid ?? 0) > 0) ...[
          _text('Abonado: \$${record.amountPaid!.toStringAsFixed(2)}', align: TextAlign.right),
          if ((total - (record.amountPaid ?? 0)) > 0)
            _text('Restante: \$${(total - record.amountPaid!).toStringAsFixed(2)}', align: TextAlign.right),
        ],

        const SizedBox(height: 16),
        _text('ESTE BOLETO NO ES UN', align: TextAlign.center),
        _text('COMPROBANTE FISCAL', align: TextAlign.center),
        _text('Gracias por su preferencia', align: TextAlign.center),
      ],
    );
  }

  Widget _text(String text, {bool isBold = false, double size = 14, TextAlign align = TextAlign.left}) {
    return Text(
      text,
      textAlign: align,
      style: TextStyle(
        fontFamily: 'Courier',
        fontSize: size,
        fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        color: Colors.black,
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _text(label),
          _text(value, align: TextAlign.right),
        ],
      ),
    );
  }
}
