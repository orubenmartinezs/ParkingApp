<?php
// api/sync.php
header('Content-Type: application/json');
require_once '../db.php';

// Only allow POST requests
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['error' => 'Method not allowed']);
    exit;
}

// Get JSON input
$input = file_get_contents('php://input');
$data = json_decode($input, true);

if (!$data) {
    http_response_code(400);
    echo json_encode(['error' => 'Invalid JSON']);
    exit;
}

$pdo = getDB();

// Helper to upsert record
function upsertRecord($pdo, $record) {
    $sql = "INSERT INTO parking_records (
        id, folio, plate, description, entry_type_id, entry_user_id, 
        entry_time, exit_time, cost, tariff_type_id, exit_user_id, notes, 
        is_synced, pension_subscriber_id, amount_paid, payment_status
    ) VALUES (
        :id, :folio, :plate, :description, :entry_type_id, :entry_user_id, 
        :entry_time, :exit_time, :cost, :tariff_type_id, :exit_user_id, :notes, 
        1, :pension_subscriber_id, :amount_paid, :payment_status
    ) ON DUPLICATE KEY UPDATE 
        plate = VALUES(plate),
        description = VALUES(description),
        entry_type_id = VALUES(entry_type_id),
        entry_user_id = VALUES(entry_user_id),
        entry_time = VALUES(entry_time),
        exit_time = VALUES(exit_time),
        cost = VALUES(cost),
        tariff_type_id = VALUES(tariff_type_id),
        exit_user_id = VALUES(exit_user_id),
        notes = VALUES(notes),
        is_synced = 1,
        pension_subscriber_id = VALUES(pension_subscriber_id),
        amount_paid = VALUES(amount_paid),
        payment_status = VALUES(payment_status)";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':id' => $record['id'],
        ':folio' => $record['folio'] ?? null,
        ':plate' => $record['plate'],
        ':description' => $record['description'] ?? null,
        ':entry_type_id' => $record['entry_type_id'] ?? null,
        ':entry_user_id' => $record['entry_user_id'] ?? null,
        ':entry_time' => $record['entry_time'],
        ':exit_time' => $record['exit_time'] ?? null,
        ':cost' => $record['cost'] ?? null,
        ':tariff_type_id' => $record['tariff_type_id'] ?? null,
        ':exit_user_id' => $record['exit_user_id'] ?? null,
        ':notes' => $record['notes'] ?? null,
        ':pension_subscriber_id' => $record['pension_subscriber_id'] ?? null,
        ':amount_paid' => $record['amount_paid'] ?? null,
        ':payment_status' => $record['payment_status'] ?? 'PENDING',
    ]);
}

// Helper to upsert payment
function upsertPayment($pdo, $payment) {
    $sql = "INSERT INTO pension_payments (
        id, subscriber_id, amount, payment_date, 
        coverage_start_date, coverage_end_date, notes, is_synced
    ) VALUES (
        :id, :subscriber_id, :amount, :payment_date,
        :coverage_start_date, :coverage_end_date, :notes, 1
    ) ON DUPLICATE KEY UPDATE 
        subscriber_id = VALUES(subscriber_id),
        amount = VALUES(amount),
        payment_date = VALUES(payment_date),
        coverage_start_date = VALUES(coverage_start_date),
        coverage_end_date = VALUES(coverage_end_date),
        notes = VALUES(notes),
        is_synced = 1";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':id' => $payment['id'],
        ':subscriber_id' => $payment['subscriber_id'],
        ':amount' => $payment['amount'],
        ':payment_date' => $payment['payment_date'],
        ':coverage_start_date' => $payment['coverage_start_date'],
        ':coverage_end_date' => $payment['coverage_end_date'],
        ':notes' => $payment['notes'] ?? null,
    ]);
}

// Helper to upsert subscriber
function upsertSubscriber($pdo, $subscriber) {
    $sql = "INSERT INTO pension_subscribers (
        id, folio, plate, entry_type_id, monthly_fee, name, 
        entry_date, paid_until, is_active, notes
    ) VALUES (
        :id, :folio, :plate, :entry_type_id, :monthly_fee, :name,
        :entry_date, :paid_until, :is_active, :notes
    ) ON DUPLICATE KEY UPDATE 
        plate = VALUES(plate),
        entry_type_id = VALUES(entry_type_id),
        monthly_fee = VALUES(monthly_fee),
        name = VALUES(name),
        entry_date = VALUES(entry_date),
        paid_until = VALUES(paid_until),
        is_active = VALUES(is_active),
        notes = VALUES(notes)";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':id' => $subscriber['id'],
        ':folio' => $subscriber['folio'] ?? null,
        ':plate' => $subscriber['plate'] ?? null,
        ':entry_type_id' => $subscriber['entry_type_id'] ?? null,
        ':monthly_fee' => $subscriber['monthly_fee'],
        ':name' => $subscriber['name'] ?? null,
        ':entry_date' => $subscriber['entry_date'] ?? null,
        ':paid_until' => $subscriber['paid_until'] ?? null,
        ':is_active' => isset($subscriber['is_active']) ? $subscriber['is_active'] : 1,
        ':notes' => $subscriber['notes'] ?? null,
    ]);
}

// Helper to upsert user
function upsertUser($pdo, $user) {
    $sql = "INSERT INTO users (
        id, name, role, pin, is_active, is_synced
    ) VALUES (
        :id, :name, :role, :pin, :is_active, 1
    ) ON DUPLICATE KEY UPDATE 
        name = VALUES(name),
        role = VALUES(role),
        pin = VALUES(pin),
        is_active = VALUES(is_active),
        is_synced = 1";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':id' => $user['id'],
        ':name' => $user['name'],
        ':role' => $user['role'],
        ':pin' => $user['pin'] ?? null,
        ':is_active' => isset($user['is_active']) ? $user['is_active'] : 1,
    ]);
}

// Helper to upsert entry type
function upsertEntryType($pdo, $type) {
    $sql = "INSERT INTO entry_types (
        id, name, default_tariff_id, is_active, is_synced
    ) VALUES (
        :id, :name, :default_tariff_id, :is_active, 1
    ) ON DUPLICATE KEY UPDATE 
        name = VALUES(name),
        default_tariff_id = VALUES(default_tariff_id),
        is_active = VALUES(is_active),
        is_synced = 1";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':id' => $type['id'],
        ':name' => $type['name'],
        ':default_tariff_id' => $type['default_tariff_id'] ?? null,
        ':is_active' => isset($type['is_active']) ? $type['is_active'] : 1,
    ]);
}

// Helper to upsert tariff type
function upsertTariffType($pdo, $type) {
    $sql = "INSERT INTO tariff_types (
        id, name, is_active, is_synced
    ) VALUES (
        :id, :name, :is_active, 1
    ) ON DUPLICATE KEY UPDATE 
        name = VALUES(name),
        is_active = VALUES(is_active),
        is_synced = 1";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':id' => $type['id'],
        ':name' => $type['name'],
        ':is_active' => isset($type['is_active']) ? $type['is_active'] : 1,
    ]);
}

// Helper to upsert expense
function upsertExpense($pdo, $expense) {
    $sql = "INSERT INTO expenses (
        id, description, amount, category, expense_date, user_id, is_synced
    ) VALUES (
        :id, :description, :amount, :category, :expense_date, :user_id, 1
    ) ON DUPLICATE KEY UPDATE 
        description = VALUES(description),
        amount = VALUES(amount),
        category = VALUES(category),
        expense_date = VALUES(expense_date),
        user_id = VALUES(user_id),
        is_synced = 1";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':id' => $expense['id'],
        ':description' => $expense['description'],
        ':amount' => $expense['amount'],
        ':category' => $expense['category'],
        ':expense_date' => $expense['expense_date'],
        ':user_id' => $expense['user_id'] ?? null,
    ]);
}

// Helper to upsert expense category
function upsertExpenseCategory($pdo, $category) {
    $sql = "INSERT INTO expense_categories (
        id, name, description, is_active, is_synced
    ) VALUES (
        :id, :name, :description, :is_active, 1
    ) ON DUPLICATE KEY UPDATE 
        name = VALUES(name),
        description = VALUES(description),
        is_active = VALUES(is_active),
        is_synced = 1";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute([
        ':id' => $category['id'],
        ':name' => $category['name'],
        ':description' => $category['description'] ?? null,
        ':is_active' => isset($category['is_active']) ? $category['is_active'] : 1,
    ]);
}

// Main Logic
try {
    if (isset($data['table'])) {
        switch ($data['table']) {
            case 'users':
                upsertUser($pdo, $data);
                echo json_encode(['status' => 'success', 'type' => 'user', 'id' => $data['id']]);
                break;
            case 'expense_categories':
                upsertExpenseCategory($pdo, $data);
                echo json_encode(['status' => 'success', 'type' => 'expense_category', 'id' => $data['id']]);
                break;
            case 'entry_types':
                upsertEntryType($pdo, $data);
                echo json_encode(['status' => 'success', 'type' => 'entry_type', 'id' => $data['id']]);
                break;
            case 'tariff_types':
                upsertTariffType($pdo, $data);
                echo json_encode(['status' => 'success', 'type' => 'tariff_type', 'id' => $data['id']]);
                break;
            case 'expenses':
                upsertExpense($pdo, $data);
                echo json_encode(['status' => 'success', 'type' => 'expense', 'id' => $data['id']]);
                break;
            default:
                throw new Exception("Unknown table: " . $data['table']);
        }
    } elseif (isset($data['subscriber_id']) && isset($data['amount'])) {
        // It's a pension payment
        upsertPayment($pdo, $data);
        echo json_encode(['status' => 'success', 'type' => 'payment', 'id' => $data['id']]);
    } elseif (isset($data['category']) && isset($data['expense_date'])) {
        // It's an expense
        upsertExpense($pdo, $data);
        echo json_encode(['status' => 'success', 'type' => 'expense', 'id' => $data['id']]);
    } elseif (isset($data['monthly_fee'])) {
        // It's a pension subscriber (Must check this before plate because subscribers also have plate)
        upsertSubscriber($pdo, $data);
        echo json_encode(['status' => 'success', 'type' => 'subscriber', 'id' => $data['id']]);
    } elseif (isset($data['plate'])) {
        // It's a parking record
        upsertRecord($pdo, $data);
        echo json_encode(['status' => 'success', 'type' => 'record', 'id' => $data['id']]);
    } else {
        http_response_code(400);
        echo json_encode(['error' => 'Unknown data format', 'received' => $data]);
    }
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}
