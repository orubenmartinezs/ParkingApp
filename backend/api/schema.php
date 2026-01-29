<?php
// api/schema.php
header('Content-Type: application/json');
require_once '../db.php';

try {
    $pdo = getDB();
    
    // Get all tables
    $stmt = $pdo->query("SHOW TABLES");
    $tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    $schema = [];
    
    foreach ($tables as $table) {
        // Get create statement
        $stmt = $pdo->query("SHOW CREATE TABLE `$table`");
        $result = $stmt->fetch(PDO::FETCH_ASSOC);
        
        if ($result && isset($result['Create Table'])) {
            // We need to convert MySQL types to SQLite types roughly if we want to use the EXACT SQL
            // But usually, it's better to send a structural definition or just the SQL and hope it's compatible enough.
            // SQLite is very forgiving with types, but some syntax (AUTO_INCREMENT, ON UPDATE CURRENT_TIMESTAMP) might fail.
            // However, the user asked to "read the structures... and then create".
            // Let's send the raw SQL for now, but we might need to parse/adjust it on the client side 
            // OR we can try to produce SQLite-compatible SQL here.
            
            // For simplicity and robustness given the prompt, let's send the MySQL CREATE statement.
            // The client (Flutter) will likely need to sanitize it for SQLite.
            // Or better: Let's clean it up here to be more SQLite friendly.
            
            $createSql = $result['Create Table'];
            
            // Basic cleanup for SQLite compatibility (naive approach)
            // 1. Remove AUTO_INCREMENT
            $createSql = str_ireplace('AUTO_INCREMENT', '', $createSql);
            // 2. Remove ENGINE=...
            $createSql = preg_replace('/ENGINE=\w+/', '', $createSql);
            // 3. Remove DEFAULT CHARSET=...
            $createSql = preg_replace('/DEFAULT CHARSET=\w+/', '', $createSql);
            // 4. Remove COLLATE=...
            $createSql = preg_replace('/COLLATE=\w+/', '', $createSql);
            // 5. Remove ON UPDATE CURRENT_TIMESTAMP
            $createSql = str_ireplace('ON UPDATE CURRENT_TIMESTAMP', '', $createSql);
            // 6. Replace INT(...) with INTEGER
            $createSql = preg_replace('/INT\(\d+\)/i', 'INTEGER', $createSql);
            // 7. Replace TINYINT(1) with INTEGER
            $createSql = str_ireplace('TINYINT(1)', 'INTEGER', $createSql);
            // 8. Replace BIGINT with INTEGER (SQLite handles 64-bit integers)
            $createSql = str_ireplace('BIGINT', 'INTEGER', $createSql);
            // 9. Remove trailing comma if exists (before closing parenthesis) - tricky with regex
            
            $schema[$table] = $createSql;
        }
    }
    
    echo json_encode(['status' => 'success', 'schema' => $schema]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}
