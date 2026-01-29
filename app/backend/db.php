<?php
// db.php
require_once 'config.php';

// Enable error logging
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/logs/error.log');

function getDB() {
    static $pdo = null;
    if ($pdo === null) {
        try {
            $dsn = "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4";
            $pdo = new PDO($dsn, DB_USER, DB_PASS, [
                PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES => false,
            ]);
        } catch (PDOException $e) {
            error_log("Database Connection Error: " . $e->getMessage());
            http_response_code(500);
            echo json_encode(['error' => 'Database connection failed. Check server logs.']);
            exit;
        }
    }
    return $pdo;
}

function logError($message) {
    error_log("[" . date('Y-m-d H:i:s') . "] " . $message . "\n", 3, __DIR__ . '/logs/app_errors.log');
}
