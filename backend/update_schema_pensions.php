<?php
require_once 'db.php';
try {
    $pdo = getDB();
    $pdo->exec("ALTER TABLE pension_subscribers ADD COLUMN periodicity VARCHAR(20) DEFAULT 'MONTHLY'");
    echo "Column added successfully\n";
} catch (Exception $e) {
    echo "Error (maybe column exists): " . $e->getMessage() . "\n";
}
?>
