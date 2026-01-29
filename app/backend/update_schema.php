<?php
require_once 'db.php';

try {
    $pdo = getDB();
    
    // Check if 'notes' column exists in 'pension_subscribers'
    $stmt = $pdo->query("SHOW COLUMNS FROM pension_subscribers LIKE 'notes'");
    if ($stmt->rowCount() == 0) {
        // Column doesn't exist, add it
        echo "Adding 'notes' column to 'pension_subscribers'...\n";
        $pdo->exec("ALTER TABLE pension_subscribers ADD COLUMN notes TEXT COLLATE utf8mb4_unicode_ci AFTER name");
        echo "Column 'notes' added successfully.\n";
    } else {
        echo "Column 'notes' already exists in 'pension_subscribers'.\n";
    }
    
} catch (PDOException $e) {
    echo "Error updating schema: " . $e->getMessage() . "\n";
    logError("Schema update error: " . $e->getMessage());
}
