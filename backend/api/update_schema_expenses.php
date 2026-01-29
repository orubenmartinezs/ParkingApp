<?php
require_once '../db.php';
$pdo = getDB();

// Create expenses table
$sql = "CREATE TABLE IF NOT EXISTS expenses (
    id VARCHAR(36) PRIMARY KEY,
    description TEXT,
    amount DECIMAL(10,2) NOT NULL,
    category VARCHAR(50),
    expense_date BIGINT NOT NULL,
    user_id VARCHAR(36),
    is_synced TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
)";

try {
    $pdo->exec($sql);
    echo "Table 'expenses' created successfully.\n";
} catch (PDOException $e) {
    echo "Error creating table: " . $e->getMessage() . "\n";
}
?>
