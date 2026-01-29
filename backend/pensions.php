<?php
require_once 'includes/auth.php';
require_once 'db.php';

requireLogin();

$pdo = getDB();
$message = '';
$error = '';

function gen_uuid() {
    return sprintf( '%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
        mt_rand( 0, 0xffff ), mt_rand( 0, 0xffff ),
        mt_rand( 0, 0xffff ),
        mt_rand( 0, 0x0fff ) | 0x4000,
        mt_rand( 0, 0x3fff ) | 0x8000,
        mt_rand( 0, 0xffff ), mt_rand( 0, 0xffff ), mt_rand( 0, 0xffff )
    );
}

// Handle Form Submissions
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['action'])) {
        try {
            if ($_POST['action'] === 'add_subscriber') {
                $id = gen_uuid();
                $plate = !empty($_POST['plate']) ? strtoupper($_POST['plate']) : null;
                $name = $_POST['name'];
                $notes = $_POST['notes'] ?? null;
                $entry_type = $_POST['entry_type'];
                $monthly_fee = $_POST['monthly_fee'];
                $entry_date = strtotime($_POST['entry_date']) * 1000;
                
                // Generate Folio
                // Ensure sequence exists
                $pdo->exec("INSERT IGNORE INTO sequences (name, current_val) VALUES ('pension_folio', 0)");
                $pdo->exec("UPDATE sequences SET current_val = current_val + 1 WHERE name = 'pension_folio'");
                $stmt = $pdo->query("SELECT current_val FROM sequences WHERE name = 'pension_folio'");
                $folio = $stmt->fetchColumn();
                
                $stmt = $pdo->prepare("INSERT INTO pension_subscribers (id, folio, plate, name, notes, entry_type, monthly_fee, entry_date, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1)");
                $stmt->execute([$id, $folio, $plate, $name, $notes, $entry_type, $monthly_fee, $entry_date]);
                $message = "Pensión agregada exitosamente. Folio: " . $folio;

            } elseif ($_POST['action'] === 'register_payment') {
                $subscriber_id = $_POST['subscriber_id'];
                $amount = $_POST['amount'];
                $payment_date = time() * 1000;
                
                // Use provided dates or fallbacks
                if (!empty($_POST['coverage_start_date']) && !empty($_POST['coverage_end_date'])) {
                    $start_date = strtotime($_POST['coverage_start_date']) * 1000;
                    // Add 23:59:59 to end date to cover the full day if needed, or just start of day
                    // Usually subscriptions end at the same time they started, but for date inputs it's usually 00:00
                    // Let's stick to start of day for consistency with the input, or maybe end of day?
                    // The app usually handles logic. Let's just take the date as provided (00:00 local).
                    $end_date = strtotime($_POST['coverage_end_date']) * 1000;
                } else {
                    // Fallback logic (should not be reached if form is valid)
                    $stmt = $pdo->prepare("SELECT paid_until FROM pension_subscribers WHERE id = ?");
                    $stmt->execute([$subscriber_id]);
                    $sub = $stmt->fetch();
                    $start_date = ($sub['paid_until'] && $sub['paid_until'] > $payment_date) ? $sub['paid_until'] : $payment_date;
                    $end_date = $start_date + (30 * 24 * 60 * 60 * 1000); 
                }
                
                $payment_id = gen_uuid();
                $stmt = $pdo->prepare("INSERT INTO pension_payments (id, subscriber_id, amount, payment_date, coverage_start_date, coverage_end_date) VALUES (?, ?, ?, ?, ?, ?)");
                $stmt->execute([$payment_id, $subscriber_id, $amount, $payment_date, $start_date, $end_date]);
                
                // Update subscriber paid_until
                $stmt = $pdo->prepare("UPDATE pension_subscribers SET paid_until = ? WHERE id = ?");
                $stmt->execute([$end_date, $subscriber_id]);
                
                $message = "Pago registrado exitosamente.";

            } elseif ($_POST['action'] === 'delete_subscriber') {
                $id = $_POST['subscriber_id'];
                $stmt = $pdo->prepare("DELETE FROM pension_subscribers WHERE id = ?");
                $stmt->execute([$id]);
                $message = "Registro eliminado.";
                
            } elseif ($_POST['action'] === 'toggle_status') {
                $id = $_POST['subscriber_id'];
                $current_status = $_POST['current_status'];
                $new_status = $current_status == 1 ? 0 : 1;
                $stmt = $pdo->prepare("UPDATE pension_subscribers SET is_active = ? WHERE id = ?");
                $stmt->execute([$new_status, $id]);
                $message = "Estado actualizado.";
            }
        } catch (Exception $e) {
            $error = "Error: " . $e->getMessage();
        }
    }
}

// Fetch Subscribers
$stmt = $pdo->query("SELECT * FROM pension_subscribers ORDER BY created_at DESC");
$subscribers = $stmt->fetchAll();

require_once 'includes/header.php';
?>

<div class="d-flex justify-content-between align-items-center mb-4">
    <h2>Gestión de Pensiones</h2>
    <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#addSubscriberModal">
        <i class="bi bi-plus-lg me-2"></i>Nueva Pensión
    </button>
</div>

<?php if ($message): ?>
    <div class="alert alert-success alert-dismissible fade show"><?= htmlspecialchars($message) ?>
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
<?php endif; ?>
<?php if ($error): ?>
    <div class="alert alert-danger alert-dismissible fade show"><?= htmlspecialchars($error) ?>
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    </div>
<?php endif; ?>

<div class="card shadow-sm">
    <div class="card-body p-0">
        <div class="table-responsive">
            <table class="table table-hover align-middle mb-0">
                <thead class="table-light">
                    <tr>
                        <th>Folio</th>
                        <th>Placa</th>
                        <th>Nombre / Notas</th>
                        <th>Tipo</th>
                        <th>Mensualidad</th>
                        <th>Pagado Hasta</th>
                        <th>Estado</th>
                        <th class="text-end">Acciones</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($subscribers as $s): ?>
                    <tr class="<?= $s['is_active'] ? '' : 'table-secondary' ?>">
                        <td><?= htmlspecialchars($s['folio'] ?? 'N/A') ?></td>
                        <td class="fw-bold"><?= htmlspecialchars($s['plate'] ?? '-') ?></td>
                        <td>
                            <?= htmlspecialchars($s['name']) ?>
                            <?php if (!empty($s['notes'])): ?>
                                <br><small class="text-muted"><i class="bi bi-card-text me-1"></i><?= htmlspecialchars($s['notes']) ?></small>
                            <?php endif; ?>
                        </td>
                        <td><?= htmlspecialchars($s['entry_type']) ?></td>
                        <td>$<?= number_format($s['monthly_fee'], 2) ?></td>
                        <td>
                            <?php if ($s['paid_until']): ?>
                                <span class="<?= ($s['paid_until'] < time() * 1000) ? 'text-danger fw-bold' : 'text-success' ?>">
                                    <?= date('d/m/Y', $s['paid_until'] / 1000) ?>
                                </span>
                            <?php else: ?>
                                <span class="text-warning">Sin Pagos</span>
                            <?php endif; ?>
                        </td>
                        <td>
                            <?php if ($s['is_active']): ?>
                                <span class="badge bg-success">Activo</span>
                            <?php else: ?>
                                <span class="badge bg-secondary">Inactivo</span>
                            <?php endif; ?>
                        </td>
                        <td class="text-end">
                            <button class="btn btn-sm btn-success me-1" onclick="openPaymentModal('<?= $s['id'] ?>', '<?= $s['plate'] ?>', <?= $s['monthly_fee'] ?>, <?= $s['paid_until'] ?? 0 ?>)" title="Registrar Pago">
                                <i class="bi bi-cash-coin"></i>
                            </button>
                            <form method="POST" class="d-inline" onsubmit="return confirm('¿Cambiar estado de cuenta?');">
                                <input type="hidden" name="action" value="toggle_status">
                                <input type="hidden" name="subscriber_id" value="<?= $s['id'] ?>">
                                <input type="hidden" name="current_status" value="<?= $s['is_active'] ?>">
                                <button type="submit" class="btn btn-sm btn-warning me-1" title="<?= $s['is_active'] ? 'Desactivar' : 'Activar' ?>">
                                    <i class="bi bi-power"></i>
                                </button>
                            </form>
                            <form method="POST" class="d-inline" onsubmit="return confirm('¿Eliminar DEFINITIVAMENTE este registro?');">
                                <input type="hidden" name="action" value="delete_subscriber">
                                <input type="hidden" name="subscriber_id" value="<?= $s['id'] ?>">
                                <button type="submit" class="btn btn-sm btn-danger" title="Eliminar">
                                    <i class="bi bi-trash"></i>
                                </button>
                            </form>
                        </td>
                    </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        </div>
    </div>
</div>

<!-- Add Subscriber Modal -->
<div class="modal fade" id="addSubscriberModal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Nueva Pensión</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <form method="POST">
                <div class="modal-body">
                    <input type="hidden" name="action" value="add_subscriber">
                    <div class="mb-3">
                        <label class="form-label">Placa (Opcional)</label>
                        <input type="text" class="form-control" name="plate" style="text-transform: uppercase;">
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Nombre / Alias</label>
                        <input type="text" class="form-control" name="name" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Observaciones</label>
                        <textarea class="form-control" name="notes" rows="2"></textarea>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Tipo de Ingreso</label>
                        <select class="form-select" name="entry_type">
                            <option value="NOCTURNO">NOCTURNO</option>
                            <option value="DIA y NOCHE">DIA y NOCHE</option>
                        </select>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Mensualidad ($)</label>
                        <input type="number" step="0.01" class="form-control" name="monthly_fee" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Fecha de Ingreso</label>
                        <input type="date" class="form-control" name="entry_date" value="<?= date('Y-m-d') ?>" required>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-primary">Guardar</button>
                </div>
            </form>
        </div>
    </div>
</div>

<!-- Payment Modal -->
<div class="modal fade" id="paymentModal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Registrar Pago</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <form method="POST">
                <div class="modal-body">
                    <input type="hidden" name="action" value="register_payment">
                    <input type="hidden" name="subscriber_id" id="payment_subscriber_id">
                    <p class="mb-3">Placa: <strong id="payment_plate"></strong></p>
                    <div class="mb-3">
                        <label class="form-label">Monto ($)</label>
                        <input type="number" step="0.01" class="form-control" name="amount" id="payment_amount" required>
                    </div>
                    <div class="row">
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Inicio Cobertura</label>
                            <input type="date" class="form-control" name="coverage_start_date" id="payment_start_date" required>
                        </div>
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Fin Cobertura</label>
                            <input type="date" class="form-control" name="coverage_end_date" id="payment_end_date" required>
                        </div>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-success">Registrar Pago</button>
                </div>
            </form>
        </div>
    </div>
</div>

<script>
function openPaymentModal(id, plate, fee, paidUntil) {
    document.getElementById('payment_subscriber_id').value = id;
    document.getElementById('payment_plate').innerText = plate;
    document.getElementById('payment_amount').value = fee;
    
    // Calculate dates
    const now = new Date();
    let startDate = new Date();
    
    // If paidUntil is valid and in the future, start from there
    if (paidUntil > 0) {
        const paidUntilDate = new Date(paidUntil);
        if (paidUntilDate > now) {
            startDate = paidUntilDate;
        }
    }
    
    // Calculate end date (start date + 1 month)
    const endDate = new Date(startDate);
    endDate.setMonth(endDate.getMonth() + 1);
    
    // Format to YYYY-MM-DD
    const formatDate = (date) => {
        const d = new Date(date);
        let month = '' + (d.getMonth() + 1);
        let day = '' + d.getDate();
        const year = d.getFullYear();

        if (month.length < 2) month = '0' + month;
        if (day.length < 2) day = '0' + day;

        return [year, month, day].join('-');
    };
    
    document.getElementById('payment_start_date').value = formatDate(startDate);
    document.getElementById('payment_end_date').value = formatDate(endDate);
    
    new bootstrap.Modal(document.getElementById('paymentModal')).show();
}
</script>

<?php require_once 'includes/footer.php'; ?>
