<?php
// includes/init_settings.php
require_once __DIR__ . '/../db.php';

function initSystemSettings($pdo) {
    // Fetch settings
    $stmt = $pdo->query("SELECT setting_key, setting_value FROM settings");
    $settings = $stmt->fetchAll(PDO::FETCH_KEY_PAIR);
    
    // Set Timezone
    $timezone = $settings['timezone'] ?? 'America/Mexico_City';
    // Force Mexico City if not set or invalid, as requested by user
    if (empty($timezone) || !in_array($timezone, timezone_identifiers_list())) {
        $timezone = 'America/Mexico_City';
    }
    date_default_timezone_set($timezone);
    
    // Return settings array for use in other files
    return $settings;
}

// If included in global scope, we can optionally init immediately if $pdo is available
// But usually better to call explicitly.
