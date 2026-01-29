<?php
require_once 'db.php';
$pdo = getDB();
$stmt = $pdo->query("SHOW COLUMNS FROM parking_records");
$columns = $stmt->fetchAll(PDO::FETCH_ASSOC);
foreach ($columns as $col) {
    echo $col['Field'] . " (" . $col['Type'] . ")\n";
}
