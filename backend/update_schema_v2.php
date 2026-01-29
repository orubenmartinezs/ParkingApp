<?php
require_once 'db.php';

try {
    $pdo = getDB();
    
    echo "Updating schema for Dynamic Tariffs and Debt Management...\n";

    // 1. Update tariff_types
    $columns = [
        'default_cost' => "DECIMAL(10,2) DEFAULT 0",
        'cost_first_period' => "DECIMAL(10,2) DEFAULT 0",
        'cost_next_period' => "DECIMAL(10,2) DEFAULT 0",
        'period_minutes' => "INT DEFAULT 60",
        'tolerance_minutes' => "INT DEFAULT 15"
    ];

    foreach ($columns as $col => $def) {
        $stmt = $pdo->query("SHOW COLUMNS FROM tariff_types LIKE '$col'");
        if ($stmt->rowCount() == 0) {
            echo "Adding '$col' to 'tariff_types'...\n";
            $pdo->exec("ALTER TABLE tariff_types ADD COLUMN $col $def");
        } else {
            echo "Column '$col' already exists in 'tariff_types'.\n";
        }
    }

    // 2. Update parking_records
    $recordColumns = [
        'amount_paid' => "DECIMAL(10,2) DEFAULT 0",
        'payment_status' => "VARCHAR(20) DEFAULT 'PAID'"
    ];

    foreach ($recordColumns as $col => $def) {
        $stmt = $pdo->query("SHOW COLUMNS FROM parking_records LIKE '$col'");
        if ($stmt->rowCount() == 0) {
            echo "Adding '$col' to 'parking_records'...\n";
            $pdo->exec("ALTER TABLE parking_records ADD COLUMN $col $def");
            
            // Backfill amount_paid for existing records
            if ($col === 'amount_paid') {
                $pdo->exec("UPDATE parking_records SET amount_paid = cost WHERE cost IS NOT NULL");
            }
        } else {
            echo "Column '$col' already exists in 'parking_records'.\n";
        }
    }

    echo "Schema update completed successfully.\n";
    
} catch (PDOException $e) {
    echo "Error updating schema: " . $e->getMessage() . "\n";
    logError("Schema update error: " . $e->getMessage());
}
