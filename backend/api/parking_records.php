<?php
// api/parking_records.php
header('Content-Type: application/json');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE');
header('Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With');

require_once '../db.php';

// Check for CORS preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

$pdo = getDB();
$method = $_SERVER['REQUEST_METHOD'];

// Helper to check admin role
function isAdmin($pdo, $userId) {
    if (empty($userId)) return false;
    
    $stmt = $pdo->prepare("SELECT role FROM users WHERE id = :id");
    $stmt->execute([':id' => $userId]);
    $user = $stmt->fetch();
    
    // Check for 'ADMIN' (case-insensitive just in case)
    return $user && strtoupper($user['role']) === 'ADMIN';
}

// Get JSON input for non-GET requests
$input = null;
if ($method !== 'GET') {
    $rawInput = file_get_contents('php://input');
    $input = json_decode($rawInput, true);
}

switch ($method) {
    case 'GET':
        handleGet($pdo);
        break;
    case 'POST':
        handlePost($pdo, $input);
        break;
    case 'PUT':
        handlePut($pdo, $input);
        break;
    case 'DELETE':
        handleDelete($pdo, $input);
        break;
    default:
        http_response_code(405);
        echo json_encode(['error' => 'Method not allowed']);
        break;
}

function handleGet($pdo) {
    // Regular users can view information
    // Optional Filters
    $startDate = $_GET['start_date'] ?? null; // Milliseconds
    $endDate = $_GET['end_date'] ?? null;     // Milliseconds
    $plate = $_GET['plate'] ?? null;
    $limit = isset($_GET['limit']) ? (int)$_GET['limit'] : 100;
    $offset = isset($_GET['offset']) ? (int)$_GET['offset'] : 0;
    
    // Build Query
    $sql = "SELECT * FROM parking_records WHERE 1=1";
    $params = [];
    
    if ($startDate) {
        $sql .= " AND entry_time >= :start_date";
        $params[':start_date'] = $startDate;
    }
    
    if ($endDate) {
        $sql .= " AND entry_time <= :end_date";
        $params[':end_date'] = $endDate;
    }
    
    if ($plate) {
        $sql .= " AND plate LIKE :plate";
        $params[':plate'] = "%$plate%";
    }
    
    $sql .= " ORDER BY entry_time DESC LIMIT :limit OFFSET :offset";
    
    // Bind limit/offset manually as they are integers
    $stmt = $pdo->prepare($sql);
    
    foreach ($params as $key => $value) {
        $stmt->bindValue($key, $value);
    }
    $stmt->bindValue(':limit', $limit, PDO::PARAM_INT);
    $stmt->bindValue(':offset', $offset, PDO::PARAM_INT);
    
    try {
        $stmt->execute();
        $records = $stmt->fetchAll();
        echo json_encode(['status' => 'success', 'data' => $records]);
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['error' => $e->getMessage()]);
    }
}

function handlePost($pdo, $input) {
    // Only Admin can create via this endpoint (Correction/Manual Entry)
    $userId = $input['requesting_user_id'] ?? null;
    
    if (!isAdmin($pdo, $userId)) {
        http_response_code(403);
        echo json_encode(['error' => 'Unauthorized: Only Admins can create records here.']);
        return;
    }
    
    // Required fields
    if (empty($input['id']) || empty($input['plate'])) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing required fields (id, plate)']);
        return;
    }
    
    $sql = "INSERT INTO parking_records (
        id, folio, plate, description, entry_type_id, entry_user_id, 
        entry_time, exit_time, cost, tariff_type_id, exit_user_id, notes, 
        is_synced, pension_subscriber_id, amount_paid, payment_status
    ) VALUES (
        :id, :folio, :plate, :description, :entry_type_id, :entry_user_id, 
        :entry_time, :exit_time, :cost, :tariff_type_id, :exit_user_id, :notes, 
        1, :pension_subscriber_id, :amount_paid, :payment_status
    )";
    
    try {
        $stmt = $pdo->prepare($sql);
        $stmt->execute([
            ':id' => $input['id'],
            ':folio' => $input['folio'] ?? null,
            ':plate' => $input['plate'],
            ':description' => $input['description'] ?? null,
            // Replaced client_type with entry_type_id
            ':entry_type_id' => $input['entry_type_id'] ?? null,
            ':entry_user_id' => $input['entry_user_id'] ?? null,
            ':entry_time' => $input['entry_time'] ?? round(microtime(true) * 1000),
            ':exit_time' => $input['exit_time'] ?? null,
            ':cost' => $input['cost'] ?? null,
            // Replaced tariff with tariff_type_id
            ':tariff_type_id' => $input['tariff_type_id'] ?? null,
            ':exit_user_id' => $input['exit_user_id'] ?? null,
            ':notes' => $input['notes'] ?? null,
            ':pension_subscriber_id' => $input['pension_subscriber_id'] ?? null,
            ':amount_paid' => $input['amount_paid'] ?? null,
            ':payment_status' => $input['payment_status'] ?? 'PENDING',
        ]);
        
        echo json_encode(['status' => 'success', 'message' => 'Record created']);
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['error' => $e->getMessage()]);
    }
}

function handlePut($pdo, $input) {
    // Only Admin can update
    $userId = $input['requesting_user_id'] ?? null;
    
    if (!isAdmin($pdo, $userId)) {
        http_response_code(403);
        echo json_encode(['error' => 'Unauthorized: Only Admins can update records.']);
        return;
    }
    
    if (empty($input['id'])) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing Record ID']);
        return;
    }
    
    // Construct dynamic UPDATE query
    $fields = [];
    $params = [':id' => $input['id']];
    
    $allowedFields = [
        'folio', 'plate', 'description', 
        'entry_type_id', // Replaced client_type
        'entry_user_id', 'entry_time', 'exit_time', 
        'cost', // Calculated Debt
        'tariff_type_id', // Replaced tariff
        'exit_user_id', 'notes', 'pension_subscriber_id',
        'amount_paid', // Actual Income
        'payment_status'
    ];

    // Backward compatibility for client_type and tariff (Ignored if ID is present)
    if (isset($input['client_type']) && !isset($input['entry_type_id'])) {
        // Logic to find ID from Name could go here, but we want to enforce IDs.
        // For now, we ignore text fields to force frontend update.
    }
    
    foreach ($allowedFields as $field) {
        if (array_key_exists($field, $input)) {
            $fields[] = "$field = :$field";
            $params[":$field"] = $input[$field];
        }
    }
    
    if (empty($fields)) {
        http_response_code(400);
        echo json_encode(['error' => 'No fields to update']);
        return;
    }
    
    // Always mark as synced since this is a direct backend edit
    $fields[] = "is_synced = 1";
    
    $sql = "UPDATE parking_records SET " . implode(', ', $fields) . " WHERE id = :id";
    
    try {
        $stmt = $pdo->prepare($sql);
        $stmt->execute($params);
        
        if ($stmt->rowCount() > 0) {
            echo json_encode(['status' => 'success', 'message' => 'Record updated']);
        } else {
            // Check if record exists
            $check = $pdo->prepare("SELECT id FROM parking_records WHERE id = ?");
            $check->execute([$input['id']]);
            if ($check->fetch()) {
                 echo json_encode(['status' => 'success', 'message' => 'No changes made']);
            } else {
                http_response_code(404);
                echo json_encode(['error' => 'Record not found']);
            }
        }
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['error' => $e->getMessage()]);
    }
}

function handleDelete($pdo, $input) {
    // Only Admin can delete
    $userId = $input['requesting_user_id'] ?? null;
    
    if (!isAdmin($pdo, $userId)) {
        http_response_code(403);
        echo json_encode(['error' => 'Unauthorized: Only Admins can delete records.']);
        return;
    }
    
    if (empty($input['id'])) {
        http_response_code(400);
        echo json_encode(['error' => 'Missing Record ID']);
        return;
    }
    
    $sql = "DELETE FROM parking_records WHERE id = :id";
    
    try {
        $stmt = $pdo->prepare($sql);
        $stmt->execute([':id' => $input['id']]);
        
        if ($stmt->rowCount() > 0) {
            echo json_encode(['status' => 'success', 'message' => 'Record deleted']);
        } else {
            http_response_code(404);
            echo json_encode(['error' => 'Record not found']);
        }
    } catch (PDOException $e) {
        http_response_code(500);
        echo json_encode(['error' => $e->getMessage()]);
    }
}
