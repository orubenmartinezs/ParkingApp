<?php
require_once 'includes/auth.php';
require_once 'db.php';
require_once 'includes/helpers.php';

requireLogin();

if (!isAdmin()) {
    die("Acceso denegado.");
}

$pdo = getDB();
$message = '';

// Check for future dates (e.g., beyond 2030)
// 2030-01-01 timestamp in ms
$futureThreshold = strtotime('2030-01-01') * 1000;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['fix_dates'])) {
        // Option 1: Set exit_time to NULL (Move to Active)
        $stmt = $pdo->prepare("UPDATE parking_records SET exit_time = NULL, cost = 0 WHERE exit_time > ?");
        $stmt->execute([$futureThreshold]);
        $count = $stmt->rowCount();
        $message = "Se corrigieron $count registros. Ahora aparecen como 'En Sitio' y puedes darles salida correctamente.";
    } elseif (isset($_POST['delete_dates'])) {
        // Option 2: Delete records
        $stmt = $pdo->prepare("DELETE FROM parking_records WHERE exit_time > ?");
        $stmt->execute([$futureThreshold]);
        $count = $stmt->rowCount();
        $message = "Se eliminaron $count registros con fechas erróneas.";
    }
}

// Find problematic records
$stmt = $pdo->prepare("SELECT * FROM parking_records WHERE exit_time > ?");
$stmt->execute([$futureThreshold]);
$badRecords = $stmt->fetchAll();

require_once 'includes/header.php';
?>

<div class="container mt-4">
    <div class="card shadow">
        <div class="card-header bg-warning text-dark">
            <h4 class="mb-0"><i class="bi bi-exclamation-triangle"></i> Corrección de Fechas Futuras</h4>
        </div>
        <div class="card-body">
            <p>Esta herramienta detecta registros con fechas de salida erróneas (posteriores a 2030), como el error del año 2050.</p>
            
            <?php if ($message): ?>
                <div class="alert alert-success"><?= htmlspecialchars($message) ?></div>
            <?php endif; ?>

            <?php if (empty($badRecords)): ?>
                <div class="alert alert-info">¡Todo se ve bien! No se encontraron registros con fechas futuras.</div>
                <a href="index.php" class="btn btn-primary">Volver al Dashboard</a>
            <?php else: ?>
                <div class="alert alert-danger">
                    Se encontraron <strong><?= count($badRecords) ?></strong> registros con fechas incorrectas.
                </div>

                <div class="table-responsive mb-4">
                    <table class="table table-bordered table-striped">
                        <thead>
                            <tr>
                                <th>Placa</th>
                                <th>Entrada</th>
                                <th>Salida (Errónea)</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php foreach ($badRecords as $r): ?>
                            <tr>
                                <td class="fw-bold"><?= htmlspecialchars($r['plate']) ?></td>
                                <td><?= formatDateSpanish($r['entry_time']) ?></td>
                                <td class="text-danger fw-bold"><?= formatDateSpanish($r['exit_time']) ?></td>
                            </tr>
                            <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>

                <div class="d-flex gap-3">
                    <form method="POST" onsubmit="return confirm('¿Seguro que quieres mover estos vehículos a En Sitio?');">
                        <button type="submit" name="fix_dates" class="btn btn-success">
                            <i class="bi bi-arrow-counterclockwise"></i> Mover a "En Sitio" (Recomendado)
                        </button>
                    </form>
                    
                    <form method="POST" onsubmit="return confirm('¿Seguro que quieres ELIMINAR estos registros permanentemente?');">
                        <button type="submit" name="delete_dates" class="btn btn-danger">
                            <i class="bi bi-trash"></i> Eliminar Registros
                        </button>
                    </form>
                </div>
            <?php endif; ?>
        </div>
    </div>
</div>

<?php require_once 'includes/footer.php'; ?>
