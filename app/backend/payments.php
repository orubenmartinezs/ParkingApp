<?php
require_once 'includes/auth.php';
require_once 'db.php';

requireLogin();

$pdo = getDB();

// Fetch Payments
$stmt = $pdo->query("
    SELECT p.*, s.plate, s.name 
    FROM pension_payments p 
    JOIN pension_subscribers s ON p.subscriber_id = s.id 
    ORDER BY p.payment_date DESC 
    LIMIT 100
");
$payments = $stmt->fetchAll();

require_once 'includes/header.php';
?>

<div class="d-flex justify-content-between align-items-center mb-4">
    <h2>Administración <small class="text-muted fs-5">Pagos de Pensiones</small></h2>
</div>

<div class="card shadow-sm">
    <div class="card-body p-0">
        <div class="table-responsive">
            <table class="table table-hover align-middle mb-0">
                <thead class="table-light">
                    <tr>
                        <th>Fecha Pago</th>
                        <th>Placa</th>
                        <th>Nombre</th>
                        <th>Monto</th>
                        <th>Periodo Cubierto</th>
                    </tr>
                </thead>
                <tbody>
                    <?php if (empty($payments)): ?>
                    <tr>
                        <td colspan="5" class="text-center py-4 text-muted">No hay pagos registrados</td>
                    </tr>
                    <?php else: ?>
                        <?php foreach ($payments as $p): ?>
                        <tr>
                            <td><?= date('d/m/Y H:i', $p['payment_date'] / 1000) ?></td>
                            <td class="fw-bold"><?= htmlspecialchars($p['plate']) ?></td>
                            <td><?= htmlspecialchars($p['name']) ?></td>
                            <td class="text-success fw-bold">$<?= number_format($p['amount'], 2) ?></td>
                            <td>
                                <?= date('d/m/Y', $p['coverage_start_date'] / 1000) ?> - 
                                <?= date('d/m/Y', $p['coverage_end_date'] / 1000) ?>
                            </td>
                        </tr>
                        <?php endforeach; ?>
                    <?php endif; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<?php require_once 'includes/footer.php'; ?>
