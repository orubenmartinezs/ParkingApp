<?php
require_once 'db.php';
$pdo = getDB();

// Logic from pull.php
$timezone = new DateTimeZone('America/Mexico_City');
$date = new DateTime('now', $timezone);
$date->modify('today midnight');
$startOfTodayMs = $date->getTimestamp() * 1000;

echo "Calculated Start of Today (CDMX): " . $startOfTodayMs . " (" . date('Y-m-d H:i:s', $startOfTodayMs/1000) . " UTC)\n";

$stmt = $pdo->prepare("SELECT id, plate, entry_time, exit_time FROM parking_records WHERE exit_time IS NULL OR exit_time >= ? ORDER BY entry_time DESC");
$stmt->execute([$startOfTodayMs]);
$results = $stmt->fetchAll(PDO::FETCH_ASSOC);

echo "Found " . count($results) . " records matching pull.php criteria.\n";

$found = false;
foreach ($results as $r) {
    if (strpos($r['plate'], '806') !== false) {
        echo "FOUND IN RESULTS: " . $r['plate'] . " | Entry: " . $r['entry_time'] . " | Exit: " . $r['exit_time'] . "\n";
        $found = true;
    }
}

if (!$found) {
    echo "Record 806-YVG NOT found in results.\n";
    // Check the specific record again to compare
    $stmt2 = $pdo->prepare("SELECT id, plate, entry_time, exit_time FROM parking_records WHERE plate LIKE ?");
    $stmt2->execute(['%806-YVG%']);
    $record = $stmt2->fetch(PDO::FETCH_ASSOC);
    if ($record) {
        echo "ACTUAL RECORD: " . $record['plate'] . " | Exit: " . $record['exit_time'] . "\n";
        echo "Is " . $record['exit_time'] . " >= " . $startOfTodayMs . "? " . ($record['exit_time'] >= $startOfTodayMs ? "YES" : "NO") . "\n";
    }
}
