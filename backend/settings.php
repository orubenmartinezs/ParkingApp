<?php
require_once 'includes/auth.php';
require_once 'db.php';
require_once 'includes/ensure_schema.php';
require_once 'includes/init_settings.php';

requireLogin();

if (!isAdmin()) {
    header("Location: index.php");
    exit;
}

$pdo = getDB();
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

ensureSettingsTableExists($pdo);

$currentSettings = initSystemSettings($pdo); // Gets settings and sets timezone

$message = '';
$error = '';

// Default values
$defaults = [
    'company_name' => 'Mi Estacionamiento',
    'company_address' => '',
    'company_phone' => '',
    'company_rfc' => '',
    'parking_capacity' => '20',
    'timezone' => 'America/Mexico_City'
];

$s = array_merge($defaults, $currentSettings);

// Handle Update
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $newSettings = [
        'company_name' => $_POST['company_name'] ?? '',
        'company_address' => $_POST['company_address'] ?? '',
        'company_phone' => $_POST['company_phone'] ?? '',
        'company_rfc' => $_POST['company_rfc'] ?? '',
        'parking_capacity' => $_POST['parking_capacity'] ?? '0',
        'timezone' => $_POST['timezone'] ?? 'America/Mexico_City'
    ];
    
    try {
        $pdo->beginTransaction();
        $stmt = $pdo->prepare("INSERT INTO settings (setting_key, setting_value) VALUES (?, ?) ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)");
        
        foreach ($newSettings as $key => $val) {
            $stmt->execute([$key, $val]);
        }
        
        $pdo->commit();
        $message = "Configuración actualizada correctamente.";
        
        // Refresh settings
        $s = array_merge($defaults, $newSettings);
        
        // Re-init system to apply new timezone immediately if needed for display
        date_default_timezone_set($s['timezone']);
        
    } catch (Exception $e) {
        $pdo->rollBack();
        $error = "Error al actualizar: " . $e->getMessage();
    }
}

require_once 'includes/header.php';
?>

<div class="row justify-content-center">
    <div class="col-md-8">
        <div class="card shadow-sm">
            <div class="card-header bg-primary text-white">
                <h5 class="mb-0"><i class="bi bi-gear-fill me-2"></i>Settings</h5>
            </div>
            <div class="card-body">
                <?php if ($message): ?>
                    <div class="alert alert-success"><?= htmlspecialchars($message) ?></div>
                <?php endif; ?>
                <?php if ($error): ?>
                    <div class="alert alert-danger"><?= htmlspecialchars($error) ?></div>
                <?php endif; ?>

                <div class="list-group mb-4">
                    <a href="tools.php" class="list-group-item list-group-item-action d-flex justify-content-between align-items-center bg-light">
                        <div>
                            <i class="bi bi-tools text-primary me-2"></i>
                            <strong>Ir al Panel de Herramientas</strong>
                            <div class="small text-muted ms-4">Corrección de fechas, duplicados, respaldos y restauración CSV</div>
                        </div>
                        <i class="bi bi-chevron-right"></i>
                    </a>
                </div>

                <form method="POST">
                    <h6 class="border-bottom pb-2 mb-3 text-primary">Perfil de la Empresa</h6>
                    
                    <div class="mb-3">
                        <label class="form-label">Nombre de la Empresa</label>
                        <input type="text" name="company_name" class="form-control" value="<?= htmlspecialchars($s['company_name']) ?>" required>
                    </div>

                    <div class="mb-3">
                        <label class="form-label">Dirección</label>
                        <textarea name="company_address" class="form-control" rows="2"><?= htmlspecialchars($s['company_address']) ?></textarea>
                    </div>

                    <div class="row">
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Teléfono</label>
                            <input type="text" name="company_phone" class="form-control" value="<?= htmlspecialchars($s['company_phone']) ?>">
                        </div>
                        <div class="col-md-6 mb-3">
                            <label class="form-label">RFC</label>
                            <input type="text" name="company_rfc" class="form-control" value="<?= htmlspecialchars($s['company_rfc']) ?>">
                        </div>
                    </div>

                    <div class="mb-3">
                        <label class="form-label">Zona Horaria</label>
                        <select name="timezone" class="form-select">
                            <?php
                            $commonTimezones = [
                                'America/Mexico_City' => 'Ciudad de México, Centro',
                                'America/Monterrey' => 'Monterrey',
                                'America/Tijuana' => 'Tijuana (Pacífico)',
                                'America/Hermosillo' => 'Hermosillo (Sonora)',
                                'America/Chihuahua' => 'Chihuahua',
                                'America/Mazatlan' => 'Mazatlán',
                                'America/Cancun' => 'Cancún',
                                'America/Merida' => 'Mérida',
                                'UTC' => 'UTC (Universal)'
                            ];
                            
                            $currentTimezone = $s['timezone'];
                            foreach ($commonTimezones as $tz => $label) {
                                $selected = ($tz === $currentTimezone) ? 'selected' : '';
                                echo "<option value=\"$tz\" $selected>$label ($tz)</option>";
                            }
                            ?>
                        </select>
                        <div class="form-text">Selecciona la zona horaria donde se encuentra el estacionamiento.</div>
                    </div>

                    <h6 class="border-bottom pb-2 mb-3 mt-4 text-primary">Capacidad Operativa</h6>

                    <div class="mb-3">
                        <label class="form-label">Cantidad Total de Espacios</label>
                        <input type="number" name="parking_capacity" class="form-control" value="<?= htmlspecialchars($s['parking_capacity']) ?>" min="1" required>
                        <div class="form-text">Este valor se usará para calcular el porcentaje de ocupación.</div>
                    </div>

                    <div class="d-grid gap-2 d-md-flex justify-content-md-end mt-4">
                        <button type="submit" class="btn btn-primary px-4">
                            <i class="bi bi-save me-2"></i>Guardar Cambios
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </div>
</div>

<?php require_once 'includes/footer.php'; ?>
