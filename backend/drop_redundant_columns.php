<?php
// drop_redundant_columns.php
require_once 'db.php';

header('Content-Type: text/plain; charset=utf-8');

$pdo = getDB();

echo "Iniciando Limpieza de Columnas Redundantes...\n";
echo "----------------------------------------\n";

try {
    // 1. Limpiar parking_records
    echo "1. Limpiando parking_records...\n";
    
    // Verificar y eliminar client_type
    $stmt = $pdo->query("SHOW COLUMNS FROM parking_records LIKE 'client_type'");
    if ($stmt->fetch()) {
        $pdo->exec("ALTER TABLE parking_records DROP COLUMN client_type");
        echo "   -> Columna 'client_type' eliminada.\n";
    } else {
        echo "   -> Columna 'client_type' ya no existe.\n";
    }

    // Verificar y eliminar tariff
    $stmt = $pdo->query("SHOW COLUMNS FROM parking_records LIKE 'tariff'");
    if ($stmt->fetch()) {
        $pdo->exec("ALTER TABLE parking_records DROP COLUMN tariff");
        echo "   -> Columna 'tariff' eliminada.\n";
    } else {
        echo "   -> Columna 'tariff' ya no existe.\n";
    }

    // 2. Limpiar pension_subscribers
    echo "\n2. Limpiando pension_subscribers...\n";

    // Verificar y eliminar entry_type (texto)
    $stmt = $pdo->query("SHOW COLUMNS FROM pension_subscribers LIKE 'entry_type'");
    if ($stmt->fetch()) {
        // Asegurarse de que no sea la nueva (aunque la nueva se llama entry_type_id)
        $pdo->exec("ALTER TABLE pension_subscribers DROP COLUMN entry_type");
        echo "   -> Columna 'entry_type' eliminada.\n";
    } else {
        echo "   -> Columna 'entry_type' ya no existe.\n";
    }

    echo "\n----------------------------------------\n";
    echo "Limpieza completada con éxito.\n";

} catch (PDOException $e) {
    echo "\nERROR: " . $e->getMessage() . "\n";
}
