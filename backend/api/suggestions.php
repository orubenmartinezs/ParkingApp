<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With');

require_once '../db.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$pdo = getDB();
$type = $_GET['type'] ?? '';
$q = $_GET['q'] ?? '';

// Require at least 2 characters to start searching
if (strlen($q) < 2) {
    echo json_encode([]);
    exit;
}

$results = [];

try {
    if ($type === 'plate') {
        // Search in parking_records
        $stmt = $pdo->prepare("
            SELECT DISTINCT plate 
            FROM parking_records 
            WHERE plate LIKE :q 
            AND plate IS NOT NULL 
            AND plate != ''
            ORDER BY entry_time DESC 
            LIMIT 10
        ");
        $stmt->execute([':q' => "%$q%"]);
        $results = $stmt->fetchAll(PDO::FETCH_COLUMN);
    } elseif ($type === 'description') {
        // Search in parking_records
        $stmt = $pdo->prepare("
            SELECT DISTINCT description 
            FROM parking_records 
            WHERE description LIKE :q 
            AND description IS NOT NULL 
            AND description != ''
            ORDER BY entry_time DESC 
            LIMIT 10
        ");
        $stmt->execute([':q' => "%$q%"]);
        $results = $stmt->fetchAll(PDO::FETCH_COLUMN);
    } elseif ($type === 'client_name') {
        // Search in pension_subscribers
        $stmt = $pdo->prepare("
            SELECT DISTINCT name 
            FROM pension_subscribers 
            WHERE name LIKE :q 
            AND name IS NOT NULL 
            AND name != ''
            ORDER BY created_at DESC 
            LIMIT 10
        ");
        $stmt->execute([':q' => "%$q%"]);
        $results = $stmt->fetchAll(PDO::FETCH_COLUMN);
    } elseif ($type === 'expense_category') {
        // Search in expenses
        $stmt = $pdo->prepare("
            SELECT DISTINCT category 
            FROM expenses 
            WHERE category LIKE :q 
            AND category IS NOT NULL 
            AND category != ''
            ORDER BY expense_date DESC 
            LIMIT 10
        ");
        $stmt->execute([':q' => "%$q%"]);
        $results = $stmt->fetchAll(PDO::FETCH_COLUMN);
    } elseif ($type === 'entry_type_name') {
        // Search in entry_types
        $stmt = $pdo->prepare("
            SELECT DISTINCT name 
            FROM entry_types 
            WHERE name LIKE :q 
            AND name IS NOT NULL 
            AND name != ''
            ORDER BY created_at DESC 
            LIMIT 10
        ");
        $stmt->execute([':q' => "%$q%"]);
        $results = $stmt->fetchAll(PDO::FETCH_COLUMN);
    } elseif ($type === 'tariff_type_name') {
        // Search in tariff_types
        $stmt = $pdo->prepare("
            SELECT DISTINCT name 
            FROM tariff_types 
            WHERE name LIKE :q 
            AND name IS NOT NULL 
            AND name != ''
            ORDER BY created_at DESC 
            LIMIT 10
        ");
        $stmt->execute([':q' => "%$q%"]);
        $results = $stmt->fetchAll(PDO::FETCH_COLUMN);
    }
} catch (PDOException $e) {
    // Log error if needed, but return empty array to client
    error_log("Suggestions API Error: " . $e->getMessage());
    echo json_encode([]);
    exit;
}

echo json_encode($results);
