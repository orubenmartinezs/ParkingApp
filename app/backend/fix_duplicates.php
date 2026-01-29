<?php
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

// Handle Delete
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['delete_duplicates'])) {
    // Strategy:
    // 1. Find all duplicates
    // 2. For each group of duplicates, keep the one with the lowest ID (or highest, doesn't matter much if they are identical)
    // 3. Delete the rest.
    
    // We can use a self-join delete or a temporary table approach. 
    // Since this is MySQL, we can use a multi-table DELETE.
    
    // DELETE t1 FROM parking_records t1
    // INNER JOIN parking_records t2 
    // WHERE 
    //    t1.id > t2.id AND 
    //    t1.plate = t2.plate AND 
    //    t1.entry_time = t2.entry_time AND 
    //    (t1.exit_time = t2.exit_time OR (t1.exit_time IS NULL AND t2.exit_time IS NULL)) AND
    //    (t1.description = t2.description OR (t1.description IS NULL AND t2.description IS NULL))
    
    // Let's try to be safer and fetch IDs to delete first.
    
    $sql = "
        SELECT t1.id 
        FROM parking_records t1
        INNER JOIN parking_records t2 
        ON t1.plate = t2.plate 
        AND t1.entry_time = t2.entry_time 
        AND (t1.exit_time = t2.exit_time OR (t1.exit_time IS NULL AND t2.exit_time IS NULL))
        AND (t1.description = t2.description OR (t1.description IS NULL AND t2.description IS NULL))
        WHERE t1.id > t2.id
    ";
    
    $stmt = $pdo->query($sql);
    $idsToDelete = $stmt->fetchAll(PDO::FETCH_COLUMN);
    
    if (!empty($idsToDelete)) {
        $count = count($idsToDelete);
        // Delete in chunks to avoid query limits
        $chunks = array_chunk($idsToDelete, 100);
        foreach ($chunks as $chunk) {
            $placeholders = implode(',', array_fill(0, count($chunk), '?'));
            $delStmt = $pdo->prepare("DELETE FROM parking_records WHERE id IN ($placeholders)");
            $delStmt->execute($chunk);
        }
        $message = "Se eliminaron $count registros duplicados correctamente.";
    } else {
        $message = "No se encontraron duplicados para eliminar.";
    }
}

// Find Duplicates for Display
// Group by key fields and count > 1
$sql = "
    SELECT plate, entry_time, exit_time, description, COUNT(*) as count, GROUP_CONCAT(id) as ids
    FROM parking_records
    GROUP BY plate, entry_time, exit_time, description
    HAVING count > 1
";

$stmt = $pdo->query($sql);
$duplicates = $stmt->fetchAll();

require_once 'includes/header.php';
?>

<div class="container mt-4">
    <div class="card shadow">
        <div class="card-header bg-danger text-white">
            <h4 class="mb-0"><i class="bi bi-files"></i> Detector de Duplicados</h4>
        </div>
        <div class="card-body">
            <p>Esta herramienta busca registros idénticos (misma placa, hora de entrada, hora de salida y descripción) y permite dejar solo uno de ellos.</p>
            <p class="text-muted small"><i class="bi bi-info-circle"></i> Nota: Se buscan coincidencias exactas. Si ves duplicados que no aparecen aquí, puede que varíen por milisegundos.</p>
            
            <?php if ($message): ?>
                <div class="alert alert-success alert-dismissible fade show">
                    <?= htmlspecialchars($message) ?>
                    <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                </div>
            <?php endif; ?>

            <?php if (empty($duplicates)): ?>
                <div class="alert alert-info">
                    <i class="bi bi-check-circle-fill me-2"></i>¡Excelente! No se encontraron registros duplicados en la base de datos.
                </div>
                <a href="settings.php" class="btn btn-secondary">Volver a Configuración</a>
            <?php else: ?>
                <div class="alert alert-warning">
                    <i class="bi bi-exclamation-triangle-fill me-2"></i>Se encontraron <strong><?= count($duplicates) ?></strong> grupos de registros duplicados.
                </div>

                <div class="table-responsive mb-4" style="max-height: 500px; overflow-y: auto;">
                    <table class="table table-bordered table-striped">
                        <thead class="table-light sticky-top">
                            <tr>
                                <th>Placa</th>
                                <th>Entrada</th>
                                <th>Salida</th>
                                <th>Descripción</th>
                                <th>Copias Encontradas</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($duplicates as $r): ?>
                            <tr>
                                <td class="fw-bold"><?= htmlspecialchars($r['plate']) ?></td>
                                <td><?= formatDateSpanish($r['entry_time']) ?></td>
                                <td><?= $r['exit_time'] ? formatDateSpanish($r['exit_time']) : '<span class="badge bg-warning text-dark">En Sitio</span>' ?></td>
                                <td><?= htmlspecialchars($r['description'] ?? '-') ?></td>
                                <td class="text-danger fw-bold text-center"><?= $r['count'] ?></td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>

                <form method="POST" onsubmit="return confirm('¿Estás seguro? Se eliminarán las copias extra y se dejará solo UN registro original por cada grupo.');">
                    <button type="submit" name="delete_duplicates" class="btn btn-danger btn-lg w-100">
                        <i class="bi bi-trash-fill me-2"></i>Eliminar Todos los Duplicados
                    </button>
                </form>
            <?php endif; ?>
        </div>
    </div>
</div>

<?php require_once 'includes/footer.php'; ?>
