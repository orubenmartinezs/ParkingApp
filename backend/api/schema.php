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
            $createSql = $result['Create Table'];
            
            // 1. Clean up table options (ENGINE, CHARSET, etc.)
            $createSql = preg_replace('/ENGINE=.*$/', '', $createSql);
            $createSql = preg_replace('/DEFAULT CHARSET=.*$/', '', $createSql);
            $createSql = preg_replace('/COLLATE=.*$/', '', $createSql);
            $createSql = preg_replace('/ROW_FORMAT=.*$/', '', $createSql);
            
            // 2. Clean up column definitions
            // Remove UNSIGNED
            $createSql = str_ireplace('UNSIGNED', '', $createSql);
            // Remove AUTO_INCREMENT
            $createSql = str_ireplace('AUTO_INCREMENT', '', $createSql);
            // Remove ON UPDATE ...
            $createSql = preg_replace('/ON UPDATE CURRENT_TIMESTAMP(?:\(\))?/', '', $createSql);
            // Remove CHARACTER SET / COLLATE in columns
            $createSql = preg_replace('/CHARACTER SET \w+/', '', $createSql);
            $createSql = preg_replace('/COLLATE \w+/', '', $createSql);
            
            // 3. Map types to SQLite affinities
            // INT, TINYINT, SMALLINT, MEDIUMINT, BIGINT -> INTEGER
            $createSql = preg_replace('/(TINY|SMALL|MEDIUM|BIG)?INT\(\d+\)/i', 'INTEGER', $createSql);
            $createSql = preg_replace('/INT\(\d+\)/i', 'INTEGER', $createSql);
            
            // CHAR, VARCHAR, TEXT, ENUM, DATE, DATETIME, TIMESTAMP -> TEXT
            $createSql = preg_replace('/VARCHAR\(\d+\)/i', 'TEXT', $createSql);
            $createSql = preg_replace('/CHAR\(\d+\)/i', 'TEXT', $createSql);
            $createSql = preg_replace('/ENUM\(.*?\)/i', 'TEXT', $createSql);
            $createSql = preg_replace('/DATETIME/i', 'TEXT', $createSql);
            $createSql = preg_replace('/TIMESTAMP/i', 'TEXT', $createSql);
            
            // DOUBLE, FLOAT, DECIMAL -> REAL
            $createSql = preg_replace('/DECIMAL\(\d+,\d+\)/i', 'REAL', $createSql);
            $createSql = preg_replace('/DOUBLE(\(\d+,\d+\))?/i', 'REAL', $createSql);
            $createSql = preg_replace('/FLOAT(\(\d+,\d+\))?/i', 'REAL', $createSql);
            
            // 4. Clean up Keys (MySQL specific syntax in keys can be problematic)
            $lines = explode("\n", $createSql);
            $newLines = [];
            foreach ($lines as $line) {
                $trimLine = trim($line);
                // Skip non-primary keys (KEY, UNIQUE KEY, FULLTEXT KEY)
                // We keep PRIMARY KEY.
                // Note: MySQL output usually has `PRIMARY KEY (...)` on a separate line.
                if (preg_match('/^\s*(UNIQUE |FULLTEXT )?KEY /i', $trimLine) && stripos($trimLine, 'PRIMARY KEY') === false) {
                    continue; 
                }
                // Skip CONSTRAINT ... FOREIGN KEY for simplicity (SQLite supports them but syntax matches strictness)
                if (stripos($trimLine, 'CONSTRAINT ') === 0) {
                    continue;
                }
                $newLines[] = $line;
            }
            
            // Reconstruct and fix trailing commas
            $createSql = implode("\n", $newLines);
            // Remove comma before the closing parenthesis of the table definition
            $createSql = preg_replace('/,\s*\n\)/', "\n)", $createSql);
            
            $schema[$table] = $createSql;
        }
    }
    
    echo json_encode(['status' => 'success', 'schema' => $schema]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['error' => $e->getMessage()]);
}
