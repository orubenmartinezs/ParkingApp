<?php
// includes/ensure_schema.php

function ensureSettingsTableExists($pdo) {
    try {
        // Check if table exists
        $result = $pdo->query("SHOW TABLES LIKE 'settings'");
        if ($result->rowCount() == 0) {
            // Table doesn't exist, create it
            $sql = "
            CREATE TABLE IF NOT EXISTS settings (
                setting_key VARCHAR(50) PRIMARY KEY,
                setting_value TEXT,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            ";
            $pdo->exec($sql);

            // Insert defaults
            $sqlInsert = "
            INSERT IGNORE INTO settings (setting_key, setting_value) VALUES 
            ('company_name', 'Mi Estacionamiento'),
            ('company_address', 'Calle Principal 123'),
            ('company_phone', '555-0000'),
            ('company_rfc', 'XAXX010101000'),
            ('parking_capacity', '20');
            ";
            $pdo->exec($sqlInsert);
        }
    } catch (Exception $e) {
        // Log error but don't stop execution if possible, or handle gracefully
        error_log("Schema migration error: " . $e->getMessage());
    }
}
