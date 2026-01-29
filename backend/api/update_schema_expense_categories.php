<?php
require_once __DIR__ . '/../db.php';

$pdo = getDB();

try {
    // Create expense_categories table
    $sql = "CREATE TABLE IF NOT EXISTS expense_categories (
        id VARCHAR(36) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        description TEXT,
        is_active TINYINT(1) NOT NULL DEFAULT 1,
        is_synced TINYINT(1) NOT NULL DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )";
    $pdo->exec($sql);
    echo "Table 'expense_categories' created or already exists.\n";

    // Seed default categories if empty
    $stmt = $pdo->query("SELECT COUNT(*) FROM expense_categories");
    if ($stmt->fetchColumn() == 0) {
        $defaults = [
            ['Mantenimiento', 'Reparaciones y mantenimiento general'],
            ['Suministros', 'Artículos de oficina y limpieza'],
            ['Servicios', 'Agua, Luz, Internet, etc.'],
            ['Nómina', 'Pago de salarios'],
            ['Publicidad', 'Gastos de marketing y publicidad']
        ];

        $insert = $pdo->prepare("INSERT INTO expense_categories (id, name, description, is_active, is_synced) VALUES (?, ?, ?, 1, 1)");
        
        foreach ($defaults as $cat) {
            $id = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
                mt_rand(0, 0xffff), mt_rand(0, 0xffff),
                mt_rand(0, 0xffff),
                mt_rand(0, 0x0fff) | 0x4000,
                mt_rand(0, 0x3fff) | 0x8000,
                mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
            );
            $insert->execute([$id, $cat[0], $cat[1]]);
            echo "Inserted default category: {$cat[0]}\n";
        }
    } else {
        echo "Categories already exist, skipping seed.\n";
    }

} catch (PDOException $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>
