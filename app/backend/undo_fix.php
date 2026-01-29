<?php
// backend/undo_fix.php
require_once 'includes/auth.php';
require_once 'db.php';
require_once 'includes/helpers.php';
require_once 'includes/init_settings.php';

requireLogin();
if (!isAdmin()) {
    die("Acceso denegado.");
}

$pdo = getDB();
initSystemSettings($pdo);

$message = '';

// Handle Bulk Update
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['update_exits'])) {
    $updates = 0;
    foreach ($_POST['exit_times'] as $id => $timeStr) {
        if (!empty($timeStr)) {
            // Convert datetime-local string to timestamp (ms)
            $timestamp = strtotime($timeStr) * 1000;
            if ($timestamp > 0) {
                // Calculate cost roughly (optional, but good to have)
                // We'll just set the time and let them fix cost later if needed, 
                // or we can calculate it if we have the rate. 
                // For now, let's just update the exit time.
                
                // Fetch entry time to calculate cost if possible
                // (Simplification: just update time, cost remains 0 or user edits later)
                
                $stmt = $pdo->prepare("UPDATE parking_records SET exit_time = ? WHERE id = ?");
                $stmt->execute([$timestamp, $id]);
                $updates++;
            }
        }
    }
    $message = "Se actualizaron $updates registros correctamente.";
}

// Find candidates for restoration
// Criteria:
// 1. Exit time is NULL (currently "En Sitio")
// 2. Updated in the last 24 hours (generous window)
// 3. Created BEFORE the last 2 hours (to exclude genuine new cars that just arrived)
// 4. (Optional) We could also check if they HAD an exit time before? No, history is gone.

$sql = "
    SELECT * FROM parking_records 
    WHERE exit_time IS NULL 
    AND updated_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)
    AND created_at < DATE_SUB(NOW(), INTERVAL 2 HOUR)
    ORDER BY updated_at DESC
    LIMIT 200
";

$stmt = $pdo->query($sql);
$candidates = $stmt->fetchAll();

require_once 'includes/header.php';
?>

<div class="container mt-4">
    <div class="card shadow">
        <div class="card-header bg-info text-white">
            <h4 class="mb-0"><i class="bi bi-clock-history"></i> Restaurar Salidas Recientes</h4>
        </div>
        <div class="card-body">
            <p>Esta herramienta te ayuda a restaurar rápidamente las fechas de salida de los vehículos que fueron modificados recientemente.</p>
            <p class="text-muted small">
                Se muestran registros modificados en las últimas 24 horas que actualmente están "En Sitio" pero fueron creados hace más de 2 horas.
            </p>
            
            <?php if ($message): ?>
                <div class="alert alert-success alert-dismissible fade show">
                    <?= htmlspecialchars($message) ?>
                    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                </div>
            <?php endif; ?>

            <?php if (empty($candidates)): ?>
                <div class="alert alert-info">
                    No se encontraron registros recientes para restaurar.
                </div>
            <?php else: ?>
                <form method="POST">
                    <div class="table-responsive mb-3" style="max-height: 600px; overflow-y: auto;">
                        <table class="table table-striped table-hover">
                            <thead class="table-light sticky-top">
                                <tr>
                                    <th>Placa</th>
                                    <th>Descripción</th>
                                    <th>Entrada</th>
                                    <th>Salida Nueva</th>
                                    <th>Acciones Rápidas</th>
                                </tr>
                            </thead>
                            <tbody>
                                <?php foreach ($candidates as $r): ?>
                                <?php 
                                    // Pre-calculate suggested exit (e.g. 1 hour after entry)
                                    // or just leave empty
                                    $entryTs = $r['entry_time'] / 1000;
                                    $entryDate = date('Y-m-d\TH:i', $entryTs);
                                    
                                    // Suggestion: Entry + 1 hour
                                    $suggestedExit = date('Y-m-d\TH:i', $entryTs + 3600);
                                ?>
                                <tr>
                                    <td class="fw-bold"><?= htmlspecialchars($r['plate']) ?></td>
                                    <td>
                                        <small class="text-muted"><?= htmlspecialchars($r['description'] ?? '') ?></small>
                                    </td>
                                    <td>
                                        <?= formatDateSpanish($r['entry_time']) ?>
                                        <input type="hidden" name="entry_times[<?= $r['id'] ?>]" value="<?= $entryTs ?>">
                                    </td>
                                    <td>
                                        <input type="datetime-local" 
                                               name="exit_times[<?= $r['id'] ?>]" 
                                               class="form-control form-control-sm exit-input"
                                               data-entry="<?= $entryTs ?>"
                                               >
                                    </td>
                                    <td>
                                        <button type="button" class="btn btn-outline-secondary btn-sm" onclick="setExit(this, 3600)">+1h</button>
                                        <button type="button" class="btn btn-outline-secondary btn-sm" onclick="setExit(this, 7200)">+2h</button>
                                        <button type="button" class="btn btn-outline-secondary btn-sm" onclick="setExit(this, 18000)">+5h</button>
                                    </td>
                                </tr>
                                <?php endforeach; ?>
                            </tbody>
                        </table>
                    </div>
                    
                    <div class="d-flex justify-content-between align-items-center bg-light p-3 rounded">
                        <div>
                            <button type="button" class="btn btn-outline-primary btn-sm me-2" onclick="fillAll(3600)">
                                Llenar todos (+1h)
                            </button>
                            <button type="button" class="btn btn-outline-secondary btn-sm" onclick="clearAll()">
                                Limpiar
                            </button>
                        </div>
                        <button type="submit" name="update_exits" class="btn btn-primary">
                            <i class="bi bi-save"></i> Guardar Cambios
                        </button>
                    </div>
                </form>
            <?php endif; ?>
        </div>
    </div>
</div>

<script>
function setExit(btn, seconds) {
    const row = btn.closest('tr');
    const input = row.querySelector('.exit-input');
    const entryTs = parseInt(input.dataset.entry);
    
    const exitDate = new Date((entryTs + seconds) * 1000);
    
    // Format for datetime-local: YYYY-MM-DDTHH:mm
    const year = exitDate.getFullYear();
    const month = String(exitDate.getMonth() + 1).padStart(2, '0');
    const day = String(exitDate.getDate()).padStart(2, '0');
    const hours = String(exitDate.getHours()).padStart(2, '0');
    const minutes = String(exitDate.getMinutes()).padStart(2, '0');
    
    input.value = `${year}-${month}-${day}T${hours}:${minutes}`;
}

function fillAll(seconds) {
    document.querySelectorAll('.exit-input').forEach(input => {
        if (!input.value) { // Only fill empty ones
            const entryTs = parseInt(input.dataset.entry);
            const exitDate = new Date((entryTs + seconds) * 1000);
            const year = exitDate.getFullYear();
            const month = String(exitDate.getMonth() + 1).padStart(2, '0');
            const day = String(exitDate.getDate()).padStart(2, '0');
            const hours = String(exitDate.getHours()).padStart(2, '0');
            const minutes = String(exitDate.getMinutes()).padStart(2, '0');
            input.value = `${year}-${month}-${day}T${hours}:${minutes}`;
        }
    });
}

function clearAll() {
    document.querySelectorAll('.exit-input').forEach(input => input.value = '');
}
</script>
