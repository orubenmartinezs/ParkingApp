<?php
require_once 'includes/auth.php';
require_once 'db.php';
require_once 'includes/helpers.php';
require_once 'includes/init_settings.php';

requireLogin();

$pdo = getDB();
initSystemSettings($pdo); // Set Timezone

// Fetch Entry Types and Tariff Types
$entryTypes = $pdo->query("SELECT * FROM entry_types WHERE is_active = 1 ORDER BY name")->fetchAll(PDO::FETCH_ASSOC);
$tariffTypes = $pdo->query("SELECT * FROM tariff_types WHERE is_active = 1 ORDER BY name")->fetchAll(PDO::FETCH_ASSOC);

$currentUser = getCurrentUser();
$isAdmin = isAdmin();

$message = '';
$error = '';

// Handle CRUD Actions
if ($_SERVER['REQUEST_METHOD'] === 'POST' && $isAdmin) {
    $action = $_POST['action'] ?? '';
    
    try {
        if ($action === 'create') {
            $id = $_POST['id'] ?: sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x', mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0x0fff) | 0x4000, mt_rand(0, 0x3fff) | 0x8000, mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff));
            $plate = strtoupper(trim($_POST['plate']));
            $description = $_POST['description'] ?: null;
            $entry_type_id = $_POST['entry_type_id'];
            
            // Convert datetime-local string to milliseconds
            $entry_time = strtotime($_POST['entry_time']) * 1000;
            $exit_time = !empty($_POST['exit_time']) ? strtotime($_POST['exit_time']) * 1000 : null;
            
            $cost = !empty($_POST['cost']) ? (float)$_POST['cost'] : 0.0;
            $tariff_type_id = $_POST['tariff_type_id'] ?: null;
            $notes = $_POST['notes'] ?: null;
            $amount_paid = !empty($_POST['amount_paid']) ? (float)$_POST['amount_paid'] : 0.0;
            $payment_status = $_POST['payment_status'] ?? 'PAID';

            $sql = "INSERT INTO parking_records (id, plate, description, entry_type_id, entry_time, exit_time, cost, tariff_type_id, notes, amount_paid, payment_status, is_synced, created_at, updated_at) 
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, NOW(), NOW())";
            $stmt = $pdo->prepare($sql);
            $stmt->execute([$id, $plate, $description, $entry_type_id, $entry_time, $exit_time, $cost, $tariff_type_id, $notes, $amount_paid, $payment_status]);
            $message = "Registro creado correctamente.";

        } elseif ($action === 'update') {
            $id = $_POST['id'];
            $plate = strtoupper(trim($_POST['plate']));
            $description = $_POST['description'] ?: null;
            $entry_type_id = $_POST['entry_type_id'];
            
            $entry_time = strtotime($_POST['entry_time']) * 1000;
            $exit_time = !empty($_POST['exit_time']) ? strtotime($_POST['exit_time']) * 1000 : null;
            
            $cost = !empty($_POST['cost']) ? (float)$_POST['cost'] : 0.0;
            $tariff_type_id = $_POST['tariff_type_id'] ?: null;
            $notes = $_POST['notes'] ?: null;
            $amount_paid = !empty($_POST['amount_paid']) ? (float)$_POST['amount_paid'] : 0.0;
            $payment_status = $_POST['payment_status'] ?? 'PAID';

            $sql = "UPDATE parking_records SET 
                    plate = ?, description = ?, entry_type_id = ?, entry_time = ?, exit_time = ?, 
                    cost = ?, tariff_type_id = ?, notes = ?, amount_paid = ?, payment_status = ?, is_synced = 1, updated_at = NOW()
                    WHERE id = ?";
            $stmt = $pdo->prepare($sql);
            $stmt->execute([$plate, $description, $entry_type_id, $entry_time, $exit_time, $cost, $tariff_type_id, $notes, $amount_paid, $payment_status, $id]);
            $message = "Registro actualizado correctamente.";

        } elseif ($action === 'delete') {
            $id = $_POST['id'];
            $stmt = $pdo->prepare("DELETE FROM parking_records WHERE id = ?");
            $stmt->execute([$id]);
            $message = "Registro eliminado.";
        }
    } catch (Exception $e) {
        $error = "Error: " . $e->getMessage();
    }
}

// Filtering
$filter_plate = $_GET['plate'] ?? '';
$filter_description = $_GET['description'] ?? '';
$filter_type = $_GET['type'] ?? '';
$filter_start = $_GET['start'] ?? date('Y-m-d');
$filter_end = $_GET['end'] ?? date('Y-m-d');

$page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
$perPage = 20;
$offset = ($page - 1) * $perPage;

// Build Query
$where = ["1=1"];
$params = [];

if ($filter_plate) {
    $where[] = "plate LIKE ?";
    $params[] = "%$filter_plate%";
}

if ($filter_description) {
    $where[] = "description LIKE ?";
    $params[] = "%$filter_description%";
}

if ($filter_type) {
    $where[] = "entry_type_id = ?";
    $params[] = $filter_type;
}

if ($filter_start) {
    $startTs = strtotime($filter_start . " 00:00:00") * 1000;
    $where[] = "entry_time >= ?";
    $params[] = $startTs;
}

if ($filter_end) {
    $endTs = strtotime($filter_end . " 23:59:59") * 1000;
    $where[] = "entry_time <= ?";
    $params[] = $endTs;
}

$whereSql = implode(' AND ', $where);

// Count total
$countStmt = $pdo->prepare("SELECT COUNT(*) FROM parking_records WHERE $whereSql");
$countStmt->execute($params);
$totalRecords = $countStmt->fetchColumn();
$totalPages = ceil($totalRecords / $perPage);

// Fetch records
$sql = "SELECT r.*, et.name as entry_type_name, tt.name as tariff_name 
        FROM parking_records r 
        LEFT JOIN entry_types et ON r.entry_type_id = et.id 
        LEFT JOIN tariff_types tt ON r.tariff_type_id = tt.id 
        WHERE $whereSql 
        ORDER BY r.entry_time DESC 
        LIMIT $perPage OFFSET $offset";
$stmt = $pdo->prepare($sql);
$stmt->execute($params);
$records = $stmt->fetchAll(PDO::FETCH_ASSOC);

require_once 'includes/header.php';
?>

<div class="d-flex justify-content-between align-items-center mb-3">
    <h2>Estacionamiento</h2>
    <?php if ($isAdmin): ?>
    <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#recordModal" onclick="clearModal()">
        <i class="bi bi-plus-lg"></i> Nuevo Registro
    </button>
    <?php endif; ?>
</div>

<?php if ($message): ?>
    <div class="alert alert-success"><?= htmlspecialchars($message) ?></div>
<?php endif; ?>
<?php if ($error): ?>
    <div class="alert alert-danger"><?= htmlspecialchars($error) ?></div>
<?php endif; ?>

<!-- Filter Form -->
<div class="card shadow-sm mb-4">
    <div class="card-body">
        <form method="GET" class="row g-3">
                <div class="col-md-2">
                    <label class="form-label">Placa</label>
                    <input type="text" name="plate" class="form-control" placeholder="Buscar placa..." value="<?= htmlspecialchars($filter_plate) ?>">
                </div>
                <div class="col-md-2">
                    <label class="form-label">Descripción</label>
                    <input type="text" name="description" class="form-control" placeholder="Buscar descripción..." value="<?= htmlspecialchars($filter_description) ?>">
                </div>
                <div class="col-md-2">
                    <label class="form-label">Tipo</label>
                    <select name="type" class="form-select">
                        <option value="">Todos</option>
                        <?php foreach ($entryTypes as $type): ?>
                            <option value="<?= $type['id'] ?>" <?= $filter_type == $type['id'] ? 'selected' : '' ?>>
                                <?= htmlspecialchars($type['name']) ?>
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="col-md-2">
                    <label class="form-label">Desde</label>
                <input type="date" name="start" class="form-control" value="<?= htmlspecialchars($filter_start) ?>">
            </div>
            <div class="col-md-2">
                <label class="form-label">Hasta</label>
                <input type="date" name="end" class="form-control" value="<?= htmlspecialchars($filter_end) ?>">
            </div>
            <div class="col-md-2 d-flex align-items-end">
                <button type="submit" class="btn btn-primary w-100"><i class="bi bi-search"></i> Filtrar</button>
            </div>
        </form>
    </div>
</div>

<!-- Records Table -->
<div class="card shadow-sm">
    <div class="table-responsive">
        <table class="table table-hover align-middle mb-0">
            <thead class="table-light">
                <tr>
                    <th>Placa</th>
                    <th>Tipo</th>
                    <th>Descripción</th>
                    <th>Entrada</th>
                    <th>Salida</th>
                    <th>Costo</th>
                    <th>Estado</th>
                    <?php if ($isAdmin): ?>
                    <th class="text-end">Acciones</th>
                    <?php endif; ?>
                </tr>
            </thead>
            <tbody>
                <?php if (empty($records)): ?>
                <tr>
                    <td colspan="8" class="text-center py-4 text-muted">No se encontraron registros.</td>
                </tr>
                <?php else: ?>
                    <?php foreach ($records as $r): ?>
                    <tr>
                        <td class="fw-bold"><?= htmlspecialchars($r['plate']) ?></td>
                        <td>
                            <?php if (!empty($r['entry_type_name'])): ?>
                                <span class="badge bg-info text-dark"><?= htmlspecialchars($r['entry_type_name']) ?></span>
                            <?php else: ?>
                                <span class="badge bg-secondary" title="<?= htmlspecialchars($r['entry_type_id'] ?? '') ?>">
                                    <?= $r['entry_type_id'] ? 'ID: '.substr($r['entry_type_id'], 0, 4) : 'N/A' ?>
                                </span>
                            <?php endif; ?>
                        </td>
                        <td><small class="text-muted"><?= htmlspecialchars($r['description']) ?></small></td>
                        <td><?= formatDateSpanish($r['entry_time']) ?></td>
                        <td>
                            <?php if ($r['exit_time']): ?>
                                <?= formatDateSpanish($r['exit_time']) ?>
                            <?php else: ?>
                                <span class="badge bg-warning text-dark">En Sitio</span>
                            <?php endif; ?>
                        </td>
                        <td>$<?= number_format($r['cost'], 2) ?></td>
                        <td>
                            <?php if ($r['exit_time']): ?>
                                <span class="badge bg-success">Completado</span>
                            <?php else: ?>
                                <span class="badge bg-primary">Activo</span>
                            <?php endif; ?>
                        </td>
                        <?php if ($isAdmin): ?>
                        <td class="text-end">
                            <button class="btn btn-sm btn-outline-primary me-1" 
                                onclick='editRecord(<?= json_encode($r) ?>)'>
                                <i class="bi bi-pencil"></i>
                            </button>
                            <form method="POST" class="d-inline" onsubmit="return confirm('¿Está seguro de eliminar este registro?');">
                                <input type="hidden" name="action" value="delete">
                                <input type="hidden" name="id" value="<?= $r['id'] ?>">
                                <button type="submit" class="btn btn-sm btn-outline-danger">
                                    <i class="bi bi-trash"></i>
                                </button>
                            </form>
                        </td>
                        <?php endif; ?>
                    </tr>
                    <?php endforeach; ?>
                <?php endif; ?>
            </tbody>
        </table>
    </div>
    
    <!-- Pagination -->
    <?php if ($totalPages > 1): ?>
    <div class="card-footer d-flex justify-content-center">
        <nav>
            <ul class="pagination mb-0">
                <li class="page-item <?= $page <= 1 ? 'disabled' : '' ?>">
                    <a class="page-link" href="?page=<?= $page - 1 ?>&plate=<?= urlencode($filter_plate) ?>&description=<?= urlencode($filter_description) ?>&type=<?= urlencode($filter_type) ?>&start=<?= urlencode($filter_start) ?>&end=<?= urlencode($filter_end) ?>">Anterior</a>
                </li>
                <?php for ($i = 1; $i <= $totalPages; $i++): ?>
                <li class="page-item <?= $page == $i ? 'active' : '' ?>">
                    <a class="page-link" href="?page=<?= $i ?>&plate=<?= urlencode($filter_plate) ?>&description=<?= urlencode($filter_description) ?>&type=<?= urlencode($filter_type) ?>&start=<?= urlencode($filter_start) ?>&end=<?= urlencode($filter_end) ?>"><?= $i ?></a>
                </li>
                <?php endfor; ?>
                <li class="page-item <?= $page >= $totalPages ? 'disabled' : '' ?>">
                    <a class="page-link" href="?page=<?= $page + 1 ?>&plate=<?= urlencode($filter_plate) ?>&description=<?= urlencode($filter_description) ?>&type=<?= urlencode($filter_type) ?>&start=<?= urlencode($filter_start) ?>&end=<?= urlencode($filter_end) ?>">Siguiente</a>
                </li>
            </ul>
        </nav>
    </div>
    <?php endif; ?>
</div>

<!-- Modal Create/Edit -->
<div class="modal fade" id="recordModal" tabindex="-1">
    <div class="modal-dialog">
        <form method="POST" class="modal-content">
            <input type="hidden" name="action" id="modalAction" value="create">
            <input type="hidden" name="id" id="recordId">
            
            <div class="modal-header">
                <h5 class="modal-title" id="modalTitle">Nuevo Registro</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <div class="mb-3">
                    <label class="form-label">Placa</label>
                    <input type="text" name="plate" id="plate" class="form-control" required style="text-transform: uppercase;" list="plateList" autocomplete="off">
                    <datalist id="plateList"></datalist>
                </div>
                <div class="mb-3">
                    <label class="form-label">Descripción</label>
                    <input type="text" name="description" id="description" class="form-control" placeholder="Ej: Aveo Rojo" list="descList" autocomplete="off">
                    <datalist id="descList"></datalist>
                </div>
                <div class="mb-3">
                    <label class="form-label">Tipo de Cliente</label>
                    <select name="entry_type_id" id="entry_type_id" class="form-select" onchange="updateDefaultTariff()">
                        <?php foreach ($entryTypes as $type): ?>
                            <option value="<?= htmlspecialchars($type['id']) ?>" data-default-tariff="<?= htmlspecialchars($type['default_tariff_id'] ?? '') ?>"><?= htmlspecialchars($type['name']) ?></option>
                        <?php endforeach; ?>
                    </select>
                </div>
                <div class="row">
                    <div class="col-md-6 mb-3">
                        <label class="form-label">Entrada</label>
                        <input type="datetime-local" name="entry_time" id="entry_time" class="form-control" required onchange="updateCost()">
                    </div>
                    <div class="col-md-6 mb-3">
                        <label class="form-label">Salida (Opcional)</label>
                        <input type="datetime-local" name="exit_time" id="exit_time" class="form-control" onchange="updateCost()">
                    </div>
                </div>
                <div class="row">
                    <div class="col-md-6 mb-3">
                        <label class="form-label">Costo (Total)</label>
                        <input type="number" step="0.01" name="cost" id="cost" class="form-control" value="0.00">
                    </div>
                    <div class="col-md-6 mb-3">
                        <label class="form-label">Tarifa (Nombre)</label>
                        <select name="tariff_type_id" id="tariff_type_id" class="form-select" onchange="updateCost()">
                            <option value="">-- Seleccionar --</option>
                            <?php foreach ($tariffTypes as $tariff): ?>
                                <option value="<?= htmlspecialchars($tariff['id']) ?>" 
                                    data-id="<?= $tariff['id'] ?>"
                                    data-cost="<?= $tariff['default_cost'] ?>"
                                    data-cost-first="<?= $tariff['cost_first_period'] ?>"
                                    data-cost-next="<?= $tariff['cost_next_period'] ?>"
                                    data-period="<?= $tariff['period_minutes'] ?>"
                                    data-tolerance="<?= $tariff['tolerance_minutes'] ?>"
                                ><?= htmlspecialchars($tariff['name']) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                </div>
                <div class="row">
                    <div class="col-md-6 mb-3">
                        <label class="form-label">Monto Pagado</label>
                        <input type="number" step="0.01" name="amount_paid" id="amount_paid" class="form-control" value="0.00" onchange="updatePaymentStatus()">
                    </div>
                    <div class="col-md-6 mb-3">
                        <label class="form-label">Estado de Pago</label>
                        <select name="payment_status" id="payment_status" class="form-select">
                            <option value="PAID">Pagado</option>
                            <option value="PENDING">Pendiente</option>
                            <option value="PARTIAL">Parcial</option>
                        </select>
                    </div>
                </div>
                <div class="mb-3">
                    <label class="form-label">Notas</label>
                    <textarea name="notes" id="notes" class="form-control" rows="2"></textarea>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
                <button type="submit" class="btn btn-primary">Guardar</button>
            </div>
        </form>
    </div>
</div>

<script>
document.addEventListener('DOMContentLoaded', function() {
    setupAutocomplete('plate', 'plateList', 'plate');
    setupAutocomplete('description', 'descList', 'description');
});

function setupAutocomplete(inputId, listId, type) {
    const input = document.getElementById(inputId);
    const list = document.getElementById(listId);
    let timeout = null;

    if (!input || !list) return;

    input.addEventListener('input', function() {
        const val = this.value;
        if (val.length < 2) return;

        clearTimeout(timeout);
        timeout = setTimeout(() => {
            fetch(`api/suggestions.php?type=${type}&q=${encodeURIComponent(val)}`)
                .then(response => response.json())
                .then(data => {
                    list.innerHTML = '';
                    if (data && Array.isArray(data)) {
                        data.forEach(item => {
                            const option = document.createElement('option');
                            option.value = item;
                            list.appendChild(option);
                        });
                    }
                })
                .catch(console.error);
        }, 300);
    });
}

function updateDefaultTariff() {
    const clientTypeSelect = document.getElementById('entry_type_id');
    const selectedOption = clientTypeSelect.options[clientTypeSelect.selectedIndex];
    const defaultTariffId = selectedOption.getAttribute('data-default-tariff');
    
    const tariffSelect = document.getElementById('tariff_type_id');
    
    if (defaultTariffId) {
        for (let i = 0; i < tariffSelect.options.length; i++) {
            if (tariffSelect.options[i].getAttribute('data-id') === defaultTariffId) {
                tariffSelect.selectedIndex = i;
                updateCost();
                break;
            }
        }
    }
}

function updatePaymentStatus() {
    const cost = parseFloat(document.getElementById('cost').value) || 0;
    const amountPaid = parseFloat(document.getElementById('amount_paid').value) || 0;
    const statusSelect = document.getElementById('payment_status');
    
    if (amountPaid >= cost && cost > 0) {
        statusSelect.value = 'PAID';
    } else if (amountPaid > 0 && amountPaid < cost) {
        statusSelect.value = 'PARTIAL';
    } else {
        // If paid is 0, it could be PENDING or PAID (if cost is 0)
        if (cost === 0) {
            statusSelect.value = 'PAID';
        } else {
            statusSelect.value = 'PENDING';
        }
    }
}

function updateCost() {
    const tariffSelect = document.getElementById('tariff_type_id');
    const costInput = document.getElementById('cost');
    const entryTimeInput = document.getElementById('entry_time');
    const exitTimeInput = document.getElementById('exit_time');
    const selectedOption = tariffSelect.options[tariffSelect.selectedIndex];
    
    if (!selectedOption.value) {
        // If no tariff selected, don't auto-calculate unless we want to clear it?
        // Keep existing value or set to 0? Let's keep 0 if it was 0.
        return;
    }
    
    const defaultCost = selectedOption.getAttribute('data-cost');
    const costFirst = selectedOption.getAttribute('data-cost-first');
    const costNext = selectedOption.getAttribute('data-cost-next');
    const period = selectedOption.getAttribute('data-period');
    const tolerance = selectedOption.getAttribute('data-tolerance');
    
    // If we don't have entry/exit times, or if dynamic rules are not set (0/0), use default cost
    if (!entryTimeInput.value || !exitTimeInput.value || (costFirst == 0 && costNext == 0)) {
        // Only update if we are just selecting tariff, or if times are missing
        // But if times are present and it's a flat rate, we should set it.
        costInput.value = parseFloat(defaultCost).toFixed(2);
        updatePaymentStatus();
        return;
    }
    
    const entryTime = new Date(entryTimeInput.value);
    const exitTime = new Date(exitTimeInput.value);
    const durationMs = exitTime - entryTime;
    const durationMin = durationMs / (1000 * 60);
    
    if (durationMin < 0) {
        // Exit before entry?
        return;
    }
    
    // Tolerance check
    if (durationMin <= tolerance) {
        costInput.value = '0.00';
        updatePaymentStatus();
        return;
    }
    
    // Calculate cost
    // Logic: 
    // If duration > tolerance:
    //   Subtract tolerance from duration? Or just charge for full time?
    //   Usually tolerance is "free time". If exceeded, you pay for the whole time or time minus tolerance.
    //   Standard parking rules: "15 min tolerance" usually means if you stay 16 mins, you pay for 16 mins (or the first hour).
    //   Let's assume: If exceeded, calculate based on full duration.
    //   Wait, some systems deduct tolerance. Let's stick to "If duration <= tolerance, cost is 0. Else, calculate normal cost".
    
    // Calculation:
    // First period covers X minutes.
    // Remaining minutes cover Y periods.
    
    const firstPeriodCost = parseFloat(costFirst);
    const nextPeriodCost = parseFloat(costNext);
    const periodMin = parseInt(period);
    
    let totalCost = firstPeriodCost;
    let remainingDurationMin = durationMin - periodMin;
    
    if (remainingDurationMin > 0) {
        const nextPeriods = Math.ceil(remainingDurationMin / periodMin);
        totalCost += nextPeriods * nextPeriodCost;
    }
    
    costInput.value = totalCost.toFixed(2);
    updatePaymentStatus();
}

function clearModal() {
    document.getElementById('modalAction').value = 'create';
    document.getElementById('recordId').value = '';
    document.getElementById('modalTitle').innerText = 'Nuevo Registro';
    document.getElementById('plate').value = '';
    document.getElementById('description').value = '';
    
    // Set first option as default if available
    const clientTypeSelect = document.getElementById('entry_type_id');
    if (clientTypeSelect.options.length > 0) {
        clientTypeSelect.selectedIndex = 0;
        updateDefaultTariff();
    }
    
    document.getElementById('entry_time').value = new Date().toISOString().slice(0, 16);
    document.getElementById('exit_time').value = '';
    document.getElementById('cost').value = '0.00';
    document.getElementById('tariff_type_id').value = '';
    document.getElementById('amount_paid').value = '0.00';
    document.getElementById('payment_status').value = 'PAID';
    document.getElementById('notes').value = '';
}

function editRecord(r) {
    document.getElementById('modalAction').value = 'update';
    document.getElementById('recordId').value = r.id;
    document.getElementById('modalTitle').innerText = 'Editar Registro';
    document.getElementById('plate').value = r.plate;
    document.getElementById('description').value = r.description || '';
    document.getElementById('entry_type_id').value = r.entry_type_id;
    
    // Convert timestamp ms to datetime-local format
    const entryDate = new Date(parseInt(r.entry_time));
    // Adjust for timezone offset to show correct local time in input
    const entryLocal = new Date(entryDate.getTime() - (entryDate.getTimezoneOffset() * 60000)).toISOString().slice(0, 16);
    document.getElementById('entry_time').value = entryLocal;
    
    if (r.exit_time) {
        const exitDate = new Date(parseInt(r.exit_time));
        const exitLocal = new Date(exitDate.getTime() - (exitDate.getTimezoneOffset() * 60000)).toISOString().slice(0, 16);
        document.getElementById('exit_time').value = exitLocal;
    } else {
        document.getElementById('exit_time').value = '';
    }
    
    document.getElementById('cost').value = r.cost;
    document.getElementById('tariff_type_id').value = r.tariff_type_id;
    document.getElementById('amount_paid').value = r.amount_paid || '0.00';
    document.getElementById('payment_status').value = r.payment_status || 'PAID';
    document.getElementById('notes').value = r.notes;
    
    const modal = new bootstrap.Modal(document.getElementById('recordModal'));
    modal.show();
}

function applyMonthFilter(monthValue) {
    if (!monthValue) return;
    const [year, month] = monthValue.split('-');
    
    // Start date is simply YYYY-MM-01
    const startStr = `${year}-${month}-01`;
    
    // End date calculation
    // Get last day of month
    const lastDay = new Date(year, month, 0).getDate();
    const endStr = `${year}-${month}-${lastDay}`;
    
    document.getElementById('startDate').value = startStr;
    document.getElementById('endDate').value = endStr;
}
</script>

<?php require_once 'includes/footer.php'; ?>
