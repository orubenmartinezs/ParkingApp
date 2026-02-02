<?php
require_once 'db.php';

try {
    $pdo = getDB();
    
    echo "Updating schema for Entry Types (Default & Ticket Printing)...\n";

    // 1. Update entry_types
    $columns = [
        'is_default' => "TINYINT(1) DEFAULT 0",
        'should_print_ticket' => "TINYINT(1) DEFAULT 1"
    ];

    foreach ($columns as $col => $def) {
        $stmt = $pdo->query("SHOW COLUMNS FROM entry_types LIKE '$col'");
        if ($stmt->rowCount() == 0) {
            echo "Adding '$col' to 'entry_types'...\n";
            $pdo->exec("ALTER TABLE entry_types ADD COLUMN $col $def");
        } else {
            echo "Column '$col' already exists in 'entry_types'.\n";
        }
    }

    echo "Schema update completed successfully.\n";
    
} catch (PDOException $e) {
    echo "Error updating schema: " . $e->getMessage() . "\n";
    logError("Schema update error: " . $e->getMessage());
}
