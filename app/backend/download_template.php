<?php
require_once 'includes/auth.php';
require_once 'db.php';

requireLogin();

header('Content-Type: text/csv; charset=utf-8');
header('Content-Disposition: attachment; filename=plantilla_importacion_estacionamiento.csv');

$output = fopen('php://output', 'w');

// Add BOM for Excel compatibility
fprintf($output, chr(0xEF).chr(0xBB).chr(0xBF));

// Headers
fputcsv($output, [
    'Placa', 
    'Descripcion', 
    'Tipo de Cliente', 
    'Tarifa', 
    'Entrada (YYYY-MM-DD HH:MM)', 
    'Salida (YYYY-MM-DD HH:MM)', 
    'Costo', 
    'Recibido Por',
    'Entregado Por',
    'Notas', 
    'Folio Pension'
]);

// Example Row
fputcsv($output, [
    'ABC-123', 
    'Sedan Rojo', 
    'GENERAL', 
    'POR HORA', 
    '2025-10-25 14:00', 
    '2025-10-25 16:30', 
    '50.00', 
    'Oscar Jr.',
    'Frida',
    'Ejemplo de registro', 
    ''
]);

// Example Row (Pension)
fputcsv($output, [
    'XYZ-999', 
    'Camioneta Azul', 
    'PENSIÓN', 
    'PENSIÓN', 
    '2025-10-26 08:00', 
    '', 
    '0.00', 
    'Oscar Sr.',
    '',
    'Usuario de pension', 
    '101'
]);

fclose($output);
exit;
