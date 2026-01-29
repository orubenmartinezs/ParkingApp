<?php
require_once 'db.php';
$pdo = getDB();

// Insert some dummy data for testing suggestions if table is empty
$count = $pdo->query("SELECT COUNT(*) FROM parking_records")->fetchColumn();
if ($count < 5) {
    echo "Seeding data...\n";
    $stmt = $pdo->prepare("INSERT INTO parking_records (id, plate, description, entry_time) VALUES (?, ?, ?, ?)");
    $stmt->execute(['test1', 'ABC-123', 'Toyota Corolla Rojo', time() * 1000]);
    $stmt->execute(['test2', 'XYZ-789', 'Nissan Sentra Gris', time() * 1000]);
    $stmt->execute(['test3', 'DEF-456', 'Honda Civic Azul', time() * 1000]);
}

echo "Testing Suggestions API logic...\n";

function testQuery($pdo, $type, $q) {
    echo "Querying type='$type', q='$q'...\n";
    $sql = "";
    if ($type === 'plate') {
        $sql = "SELECT DISTINCT plate FROM parking_records WHERE plate LIKE :q AND plate IS NOT NULL AND plate != '' ORDER BY entry_time DESC LIMIT 10";
    } elseif ($type === 'description') {
        $sql = "SELECT DISTINCT description FROM parking_records WHERE description LIKE :q AND description IS NOT NULL AND description != '' ORDER BY entry_time DESC LIMIT 10";
    }
    
    if ($sql) {
        $stmt = $pdo->prepare($sql);
        $stmt->execute([':q' => "%$q%"]);
        $results = $stmt->fetchAll(PDO::FETCH_COLUMN);
        print_r($results);
    } else {
        echo "Invalid type\n";
    }
}

testQuery($pdo, 'plate', 'ABC');
testQuery($pdo, 'description', 'Toyota');
