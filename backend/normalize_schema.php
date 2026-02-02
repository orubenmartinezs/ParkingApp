<?php
// normalize_schema.php
require_once 'db.php';

header('Content-Type: text/plain; charset=utf-8');

$pdo = getDB();

echo "Iniciando Normalización de Base de Datos...\n";
echo "----------------------------------------\n";

try {
    $pdo->beginTransaction();

    // 1. Crear 'entry_types' si no existen basados en lo que hay en parking_records
    echo "1. Analizando Tipos de Entrada (client_type)...\n";
    
    // Mapeo de unificación eliminado para evitar hardcoding.
    // Se utilizará el nombre existente en mayúsculas.
    // El administrador puede renombrar los tipos desde el panel de control.

    $sqlUniqueClients = "SELECT DISTINCT client_type FROM parking_records WHERE entry_type_id IS NULL AND client_type IS NOT NULL";
    $stmtClients = $pdo->query($sqlUniqueClients);
    $clients = $stmtClients->fetchAll(PDO::FETCH_COLUMN);

    foreach ($clients as $clientName) {
        $normalizedName = strtoupper($clientName);
        
        // Buscar si ya existe este tipo de entrada
        $stmtCheck = $pdo->prepare("SELECT id FROM entry_types WHERE UPPER(name) = ?");
        $stmtCheck->execute([$normalizedName]);
        $typeId = $stmtCheck->fetchColumn();

        if (!$typeId) {
            // Crear nuevo tipo
            $typeId = bin2hex(random_bytes(16)); // UUID simple
            $stmtInsert = $pdo->prepare("INSERT INTO entry_types (id, name, is_active) VALUES (?, ?, 1)");
            $stmtInsert->execute([$typeId, $normalizedName]);
            echo "   -> Creado Tipo Entrada: $normalizedName ($typeId)\n";
        }

        // Actualizar parking_records
        $stmtUpdate = $pdo->prepare("UPDATE parking_records SET entry_type_id = ? WHERE client_type = ? AND entry_type_id IS NULL");
        $stmtUpdate->execute([$typeId, $clientName]);
        $count = $stmtUpdate->rowCount();
        echo "   -> Actualizados $count registros de '$clientName' a ID $typeId\n";
    }

    // 2. Crear 'tariff_types' si no existen basados en parking_records
    echo "\n2. Analizando Tarifas (tariff)...\n";
    
    $sqlUniqueTariffs = "SELECT DISTINCT tariff FROM parking_records WHERE tariff_type_id IS NULL AND tariff IS NOT NULL";
    $stmtTariffs = $pdo->query($sqlUniqueTariffs);
    $tariffs = $stmtTariffs->fetchAll(PDO::FETCH_COLUMN);

    foreach ($tariffs as $tariffName) {
        $normalizedTariff = strtoupper($tariffName);

        // Buscar si ya existe
        $stmtCheck = $pdo->prepare("SELECT id FROM tariff_types WHERE UPPER(name) = ?");
        $stmtCheck->execute([$normalizedTariff]);
        $tariffId = $stmtCheck->fetchColumn();

        if (!$tariffId) {
            $tariffId = bin2hex(random_bytes(16));
            $stmtInsert = $pdo->prepare("INSERT INTO tariff_types (id, name, is_active) VALUES (?, ?, 1)");
            $stmtInsert->execute([$tariffId, $normalizedTariff]);
            echo "   -> Creada Tarifa: $normalizedTariff ($tariffId)\n";
        }

        // Actualizar parking_records
        $stmtUpdate = $pdo->prepare("UPDATE parking_records SET tariff_type_id = ? WHERE tariff = ? AND tariff_type_id IS NULL");
        $stmtUpdate->execute([$tariffId, $tariffName]);
        $count = $stmtUpdate->rowCount();
        echo "   -> Actualizados $count registros de '$tariffName' a ID $tariffId\n";
    }

    // 3. Normalizar pension_subscribers
    echo "\n3. Analizando Pension Subscribers...\n";

    // Verificar si existe la columna entry_type_id
    $stmtCol = $pdo->query("SHOW COLUMNS FROM pension_subscribers LIKE 'entry_type_id'");
    if (!$stmtCol->fetch()) {
        echo "   -> Agregando columna entry_type_id a pension_subscribers...\n";
        $pdo->exec("ALTER TABLE pension_subscribers ADD COLUMN entry_type_id VARCHAR(36)");
        $pdo->exec("ALTER TABLE pension_subscribers ADD FOREIGN KEY (entry_type_id) REFERENCES entry_types(id) ON DELETE SET NULL");
    }

    // Actualizar subscribers
    $sqlSubs = "SELECT DISTINCT entry_type FROM pension_subscribers WHERE entry_type_id IS NULL AND entry_type IS NOT NULL";
    $stmtSubs = $pdo->query($sqlSubs);
    $subTypes = $stmtSubs->fetchAll(PDO::FETCH_COLUMN);

    foreach ($subTypes as $subTypeName) {
        $normalizedName = strtoupper($subTypeName);

        // Buscar ID
        $stmtCheck = $pdo->prepare("SELECT id FROM entry_types WHERE UPPER(name) = ?");
        $stmtCheck->execute([$normalizedName]);
        $typeId = $stmtCheck->fetchColumn();

        if (!$typeId) {
             // Crear nuevo tipo si no existe (aunque debería existir por paso 1)
            $typeId = bin2hex(random_bytes(16));
            $stmtInsert = $pdo->prepare("INSERT INTO entry_types (id, name, is_active) VALUES (?, ?, 1)");
            $stmtInsert->execute([$typeId, $normalizedName]);
            echo "   -> Creado Tipo Entrada (desde Subscribers): $normalizedName ($typeId)\n";
        }

        // Actualizar pension_subscribers
        $stmtUpdate = $pdo->prepare("UPDATE pension_subscribers SET entry_type_id = ? WHERE entry_type = ? AND entry_type_id IS NULL");
        $stmtUpdate->execute([$typeId, $subTypeName]);
        $count = $stmtUpdate->rowCount();
        echo "   -> Actualizados $count suscriptores de '$subTypeName' a ID $typeId\n";
    }

    $pdo->commit();
    echo "\n----------------------------------------\n";
    echo "Normalización completada con éxito.\n";

} catch (Exception $e) {
    $pdo->rollBack();
    echo "\nERROR CRITICO: " . $e->getMessage() . "\n";
    echo "Se han revertido todos los cambios.\n";
}
