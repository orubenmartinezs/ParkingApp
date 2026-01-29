<?php
/**
 * API Endpoint: pull.php
 * 
 * Este endpoint es responsable de proporcionar a la aplicación móvil (cliente)
 * todos los datos necesarios para su funcionamiento offline-first.
 * 
 * Lógica de Sincronización y Fechas:
 * ----------------------------------
 * 1. Configuración Regional: Se fuerza la zona horaria 'America/Mexico_City' para
 *    garantizar consistencia en los cálculos de "ayer" y "hoy", independientemente
 *    de la configuración del servidor.
 * 
 * 2. Registros de Estacionamiento (Parking Records):
 *    - Se recuperan TODOS los vehículos actualmente en el sitio (activos).
 *    - Se recuperan los vehículos que salieron desde "ayer a medianoche".
 *    - MOTIVO: Al traer registros desde ayer, aseguramos que ningún vehículo del día actual
 *      se pierda por diferencias de zona horaria entre servidor y tableta.
 *      La aplicación móvil es responsable de filtrar visualmente solo los de "Hoy",
 *      pero necesita tener los datos disponibles localmente.
 * 
 * 3. Pensiones:
 *    - Se envían TODOS los suscriptores para historial completo.
 *    - Se envían los últimos 1000 pagos para historial.
 * 
 * 4. Gastos:
 *    - Se limitan a los últimos 90 días para no sobrecargar la sincronización.
 */

header('Content-Type: application/json');
require_once '../db.php';

try {
    $pdo = getDB();
    $data = [];

    /**
     * 1. Usuarios del Sistema
     * Se sincronizan todos los usuarios para permitir login offline.
     */
    $stmt = $pdo->query("SELECT * FROM users");
    $data['users'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

    /**
     * 2. Tipos de Ingreso (Entry Types)
     * Catálogo de tipos de entrada (Normal, Pensión, etc.) y sus tarifas por defecto.
     */
    $stmt = $pdo->query("SELECT * FROM entry_types");
    $data['entry_types'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

    /**
     * 3. Tipos de Tarifa (Tariff Types)
     * Catálogo de reglas de cobro.
     */
    $stmt = $pdo->query("SELECT * FROM tariff_types");
    $data['tariff_types'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

    /**
     * 4. Categorías de Gastos
     * Solo se envían las categorías activas para nuevos registros.
     */
    $stmt = $pdo->query("SELECT * FROM expense_categories WHERE is_active = 1");
    $data['expense_categories'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

    /**
     * 5. Configuración del Sistema
     * Se recuperan configuraciones clave como la zona horaria.
     */
    $stmt = $pdo->query("SELECT setting_key, setting_value FROM settings");
    $settings = $stmt->fetchAll(PDO::FETCH_KEY_PAIR);
    
    // Asegurar zona horaria por defecto si no está configurada
    if (!isset($settings['timezone'])) {
        $settings['timezone'] = 'America/Mexico_City';
    }
    $data['settings'] = $settings;

    /**
     * 6. Suscriptores de Pensión
     * Se envían TODOS los suscriptores (activos e inactivos).
     * MOTIVO: El usuario necesita ver el historial completo de contratos en la App.
     * La App se encarga de mostrar visualmente cuáles están inactivos.
     */
    $stmt = $pdo->query("SELECT * FROM pension_subscribers");
    $data['pension_subscribers'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

    /**
     * 7. Pagos de Pensión
     * Limitado a los últimos 1000 para historial reciente.
     */
    $stmt = $pdo->query("SELECT * FROM pension_payments ORDER BY payment_date DESC LIMIT 1000");
    $data['pension_payments'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

    /**
     * 8. Gastos Registrados
     * Limitado a 90 días atrás.
     * Cálculo: UNIX_TIMESTAMP * 1000 para compatibilidad con milisegundos de Dart/Flutter.
     */
    $stmt = $pdo->query("SELECT * FROM expenses WHERE expense_date >= UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 90 DAY)) * 1000 ORDER BY expense_date DESC");
    $data['expenses'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

    /**
     * 9. Registros de Estacionamiento (Core)
     * Estrategia de Fechas:
     * - Definimos la zona horaria explícita.
     * - Calculamos el timestamp de "ayer a medianoche".
     * - Seleccionamos donde:
     *      a) exit_time IS NULL (El auto sigue en el estacionamiento)
     *      b) exit_time >= ayer (El auto salió recientemente)
     */
    $timezone = new DateTimeZone('America/Mexico_City');
    $date = new DateTime('now', $timezone);
    $date->modify('yesterday midnight');
    $startOfQueryMs = $date->getTimestamp() * 1000;

    $stmt = $pdo->prepare("SELECT * FROM parking_records WHERE exit_time IS NULL OR exit_time >= ? ORDER BY entry_time DESC");
    $stmt->execute([$startOfQueryMs]);
    $data['parking_records'] = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Respuesta exitosa
    echo json_encode(['status' => 'success', 'data' => $data]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}
