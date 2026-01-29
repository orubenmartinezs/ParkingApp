<?php
require_once 'includes/auth.php';
require_once 'db.php';
require_once 'includes/ensure_schema.php';
require_once 'includes/helpers.php';
require_once 'includes/init_settings.php';

requireLogin();

$pdo = getDB();
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

// Ensure DB schema is up to date (Auto-migration)
ensureSettingsTableExists($pdo);

// --- 0. Settings & Company Profile ---
$settings = initSystemSettings($pdo); // This sets the timezone and gets settings

$capacity = !empty($settings['parking_capacity']) ? (int)$settings['parking_capacity'] : 1; // Avoid division by zero
$companyName = $settings['company_name'] ?? 'Mi Estacionamiento';
$companyAddress = $settings['company_address'] ?? '';
$companyPhone = $settings['company_phone'] ?? '';
$companyRfc = $settings['company_rfc'] ?? '';


// Time calculations (timestamps in milliseconds)
// Use DateTime with explicitly set timezone to ensure correct midnight calculation
$timezone = new DateTimeZone('America/Mexico_City');
$dateNow = new DateTime('now', $timezone);
$now = $dateNow->getTimestamp();

$dateTodayStart = clone $dateNow;
$dateTodayStart->modify('today midnight');
$startOfDay = $dateTodayStart->getTimestamp() * 1000;

$dateTodayEnd = clone $dateNow;
$dateTodayEnd->modify('today 23:59:59');
$endOfDay = $dateTodayEnd->getTimestamp() * 1000;

// Monday of this week
$dateWeekStart = clone $dateNow;
$dateWeekStart->modify('monday this week midnight');
$startOfWeek = $dateWeekStart->getTimestamp() * 1000;

$dateWeekEnd = clone $dateNow;
$dateWeekEnd->modify('sunday this week 23:59:59');
$endOfWeek = $dateWeekEnd->getTimestamp() * 1000;

$dateMonthStart = clone $dateNow;
$dateMonthStart->modify('first day of this month midnight');
$startOfMonth = $dateMonthStart->getTimestamp() * 1000;

$dateMonthEnd = clone $dateNow;
$dateMonthEnd->modify('last day of this month 23:59:59');
$endOfMonth = $dateMonthEnd->getTimestamp() * 1000;

// --- 1. Dashboard Lists ---

// Active records (in parking)
$stmtActive = $pdo->query("SELECT r.*, et.name as entry_type_name 
                           FROM parking_records r 
                           LEFT JOIN entry_types et ON r.entry_type_id = et.id 
                           WHERE r.exit_time IS NULL 
                           ORDER BY r.entry_time DESC");
$activeRecords = $stmtActive->fetchAll(PDO::FETCH_ASSOC);

// Occupancy Rate
$currentOccupancy = count($activeRecords);
$occupancyRate = min(100, round(($currentOccupancy / $capacity) * 100));
$availableSpaces = max(0, $capacity - $currentOccupancy);

// Exited Today (Changed from Recent History)
$stmtTodayExits = $pdo->prepare("SELECT r.*, et.name as entry_type_name 
                                 FROM parking_records r 
                                 LEFT JOIN entry_types et ON r.entry_type_id = et.id 
                                 WHERE r.exit_time >= ? AND r.exit_time <= ? 
                                 ORDER BY r.exit_time DESC");
$stmtTodayExits->execute([$startOfDay, $endOfDay]);
$todayExits = $stmtTodayExits->fetchAll(PDO::FETCH_ASSOC);


// --- 2. Financial Summary ---

function getIncome($pdo, $startTime, $endTime) {
    $stmt = $pdo->prepare("SELECT SUM(cost) FROM parking_records WHERE exit_time >= ? AND exit_time <= ?");
    $stmt->execute([$startTime, $endTime]);
    return $stmt->fetchColumn() ?: 0;
}

$incomeDay = getIncome($pdo, $startOfDay, $endOfDay);
$incomeWeek = getIncome($pdo, $startOfWeek, $endOfWeek);
$incomeMonth = getIncome($pdo, $startOfMonth, $endOfMonth);

// --- 3. Chart Data (Last 7 Days) ---
$chartLabels = [];
$chartIncome = [];
$chartTraffic = [];

for ($i = 6; $i >= 0; $i--) {
    $date = date('Y-m-d', strtotime("-$i days"));
    $startTs = strtotime($date . ' 00:00:00') * 1000;
    $endTs = strtotime($date . ' 23:59:59') * 1000;
    
    // Income
    $stmtInc = $pdo->prepare("SELECT SUM(cost) FROM parking_records WHERE exit_time >= ? AND exit_time <= ?");
    $stmtInc->execute([$startTs, $endTs]);
    $chartIncome[] = $stmtInc->fetchColumn() ?: 0;
    
    // Traffic (Entries)
    $stmtTra = $pdo->prepare("SELECT COUNT(*) FROM parking_records WHERE entry_time >= ? AND entry_time <= ?");
    $stmtTra->execute([$startTs, $endTs]);
    $chartTraffic[] = $stmtTra->fetchColumn() ?: 0;
    
    $chartLabels[] = formatDateSpanishShort(strtotime($date));
}

// --- 4. User Performance ---

// Fetch all users
$stmtUsers = $pdo->query("SELECT id, name FROM users ORDER BY name");
$users = $stmtUsers->fetchAll(PDO::FETCH_KEY_PAIR); // id => name

// Correct approach for User Performance
// We need 6 arrays: Entries (Day, Week, Month) and Exits (Day, Week, Month)

function getStatsByField($pdo, $field, $timeField, $startTime, $endTime) {
    $stmt = $pdo->prepare("SELECT $field as user_id, COUNT(*) as total FROM parking_records WHERE $field IS NOT NULL AND $timeField >= ? AND $timeField <= ? GROUP BY $field");
    $stmt->execute([$startTime, $endTime]);
    return $stmt->fetchAll(PDO::FETCH_KEY_PAIR);
}

$entriesDay = getStatsByField($pdo, 'entry_user_id', 'entry_time', $startOfDay, $endOfDay);
$entriesWeek = getStatsByField($pdo, 'entry_user_id', 'entry_time', $startOfWeek, $endOfWeek);
$entriesMonth = getStatsByField($pdo, 'entry_user_id', 'entry_time', $startOfMonth, $endOfMonth);

$exitsDay = getStatsByField($pdo, 'exit_user_id', 'exit_time', $startOfDay, $endOfDay);
$exitsWeek = getStatsByField($pdo, 'exit_user_id', 'exit_time', $startOfWeek, $endOfWeek);
$exitsMonth = getStatsByField($pdo, 'exit_user_id', 'exit_time', $startOfMonth, $endOfMonth);

require_once 'includes/header.php';
?>

<!-- Company & Occupancy Header -->
<div class="row mb-4">
    <div class="col-md-8">
        <div class="card border-primary shadow-sm h-100">
            <div class="card-body d-flex align-items-center">
                <div class="me-4 text-primary">
                    <i class="bi bi-building" style="font-size: 2.5rem;"></i>
                </div>
                <div>
                    <h4 class="mb-1 text-primary fw-bold"><?= htmlspecialchars($companyName) ?></h4>
                    <p class="mb-0 text-muted">
                        <?= htmlspecialchars($companyAddress) ?> 
                        <?php if ($companyPhone): ?>| <i class="bi bi-telephone"></i> <?= htmlspecialchars($companyPhone) ?><?php endif; ?>
                        <?php if ($companyRfc): ?>| RFC: <?= htmlspecialchars($companyRfc) ?><?php endif; ?>
                    </p>
                </div>
            </div>
        </div>
    </div>
    <div class="col-md-4">
        <div class="card bg-white shadow-sm h-100 border-0">
            <div class="card-body text-center">
                <h6 class="text-muted mb-3">Ocupación Actual</h6>
                <div class="position-relative d-inline-block">
                    <div style="width: 120px; height: 120px;">
                        <canvas id="occupancyChart"></canvas>
                    </div>
                    <div class="position-absolute top-50 start-50 translate-middle text-center">
                        <h3 class="mb-0 fw-bold"><?= $occupancyRate ?>%</h3>
                    </div>
                </div>
                <div class="mt-2 text-muted small">
                    <span class="fw-bold text-dark"><?= $currentOccupancy ?></span> ocupados de <span class="fw-bold text-dark"><?= $capacity ?></span>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Financial Summary -->
<div class="row mb-4">
    <div class="col-md-4">
        <div class="card bg-primary text-white shadow-sm">
            <div class="card-body">
                <h6 class="card-title opacity-75">Ingresos Hoy</h6>
                <h3 class="card-text fw-bold">$<?= number_format($incomeDay, 2) ?></h3>
            </div>
        </div>
    </div>
    <div class="col-md-4">
        <div class="card bg-info text-white shadow-sm">
            <div class="card-body">
                <h6 class="card-title opacity-75">Ingresos Semana</h6>
                <h3 class="card-text fw-bold">$<?= number_format($incomeWeek, 2) ?></h3>
            </div>
        </div>
    </div>
    <div class="col-md-4">
        <div class="card bg-success text-white shadow-sm">
            <div class="card-body">
                <h6 class="card-title opacity-75">Ingresos Mes</h6>
                <h3 class="card-text fw-bold">$<?= number_format($incomeMonth, 2) ?></h3>
            </div>
        </div>
    </div>
</div>

<!-- Charts Row -->
<div class="row mb-4">
    <div class="col-md-8">
        <div class="card shadow-sm h-100">
            <div class="card-header bg-white">
                <h6 class="mb-0 fw-bold text-secondary">Ingresos (Últimos 7 días)</h6>
            </div>
            <div class="card-body">
                <canvas id="incomeChart" height="100"></canvas>
            </div>
        </div>
    </div>
    <div class="col-md-4">
        <div class="card shadow-sm h-100">
            <div class="card-header bg-white">
                <h6 class="mb-0 fw-bold text-secondary">Tráfico (Entradas)</h6>
            </div>
            <div class="card-body">
                <canvas id="trafficChart" height="200"></canvas>
            </div>
        </div>
    </div>
</div>

<!-- Dashboard Lists -->
<div class="row mb-4">
    <!-- Active Vehicles -->
    <div class="col-12 mb-4">
        <div class="card shadow-sm h-100">
            <div class="card-header bg-success text-white d-flex justify-content-between align-items-center">
                <h5 class="mb-0"><i class="bi bi-car-front-fill me-2"></i>Vehículos en Sitio</h5>
                <span class="badge bg-light text-success fs-6"><?= count($activeRecords) ?></span>
            </div>
            <div class="card-body p-0">
                <div class="table-responsive" style="max-height: 400px; overflow-y: auto;">
                    <table class="table table-hover mb-0">
                        <thead class="table-light sticky-top">
                            <tr>
                                <th>Placa</th>
                                <th>Entrada</th>
                                <th>Tipo</th>
                                <th>Descripción</th>
                                <th>Tiempo</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($activeRecords)): ?>
                            <tr>
                                <td colspan="5" class="text-center py-4 text-muted">No hay vehículos en sitio</td>
                            </tr>
                            <?php else: ?>
                                <?php foreach ($activeRecords as $r): ?>
                                <tr>
                                    <td class="fw-bold"><?= htmlspecialchars($r['plate']) ?></td>
                                    <td><?= formatDateSpanish($r['entry_time']) ?></td>
                                    <td><?= htmlspecialchars($r['entry_type_name'] ?? 'N/A') ?></td>
                                    <td><small class="text-muted"><?= htmlspecialchars($r['description']) ?></small></td>
                                    <td>
                                        <?php
                                        $entry = $r['entry_time'] / 1000;
                                        $now_ts = time();
                                        $diff = $now_ts - $entry;
                                        $hours = floor($diff / 3600);
                                        $minutes = floor(($diff % 3600) / 60);
                                        echo "{$hours}h {$minutes}m";
                                        ?>
                                    </td>
                                </tr>
                                <?php endforeach; ?>
                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>

    <!-- Exits Today -->
    <div class="col-12">
        <div class="card shadow-sm h-100">
            <div class="card-header bg-secondary text-white d-flex justify-content-between align-items-center">
                <h5 class="mb-0"><i class="bi bi-clock-history me-2"></i>Salidas de Hoy</h5>
                <a href="records.php" class="btn btn-sm btn-light text-secondary fw-bold">Ver Todo</a>
            </div>
            <div class="card-body p-0">
                <div class="table-responsive" style="max-height: 400px; overflow-y: auto;">
                    <table class="table table-hover mb-0">
                        <thead class="table-light sticky-top">
                            <tr>
                                <th>Placa</th>
                                <th>Salida</th>
                                <th>Descripción</th>
                                <th>Costo</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($todayExits)): ?>
                            <tr>
                                <td colspan="4" class="text-center py-4 text-muted">No hubo salidas hoy</td>
                            </tr>
                            <?php else: ?>
                                <?php foreach ($todayExits as $r): ?>
                                <tr>
                                    <td class="fw-bold"><?= htmlspecialchars($r['plate']) ?></td>
                                    <td><?= formatDateSpanish($r['exit_time']) ?></td>
                                    <td><small class="text-muted"><?= htmlspecialchars($r['description']) ?></small></td>
                                    <td>$<?= number_format($r['cost'], 2) ?></td>
                                </tr>
                                <?php endforeach; ?>
                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- User Performance -->
<div class="row mb-4">
    <div class="col-12">
        <div class="card shadow-sm">
            <div class="card-header bg-dark text-white">
                <h5 class="mb-0"><i class="bi bi-people me-2"></i>Desempeño del Personal</h5>
            </div>
            <div class="card-body p-0">
                <div class="table-responsive">
                    <table class="table table-striped mb-0 text-center">
                        <thead class="table-light">
                            <tr>
                                <th rowspan="2" class="align-middle text-start ps-4">Usuario</th>
                                <th colspan="2" class="border-start">Hoy</th>
                                <th colspan="2" class="border-start">Esta Semana</th>
                                <th colspan="2" class="border-start">Este Mes</th>
                            </tr>
                            <tr>
                                <th class="border-start text-success small">Recibidos</th>
                                <th class="text-danger small">Entregados</th>
                                <th class="border-start text-success small">Recibidos</th>
                                <th class="text-danger small">Entregados</th>
                                <th class="border-start text-success small">Recibidos</th>
                                <th class="text-danger small">Entregados</th>
                            </tr>
                        </thead>
                        <tbody>
                            <?php if (empty($users)): ?>
                                <tr><td colspan="7" class="py-3">No hay usuarios registrados</td></tr>
                            <?php else: ?>
                                <?php foreach ($users as $id => $name): ?>
                                    <?php 
                                        $d_in = $entriesDay[$id] ?? 0;
                                        $d_out = $exitsDay[$id] ?? 0;
                                        $w_in = $entriesWeek[$id] ?? 0;
                                        $w_out = $exitsWeek[$id] ?? 0;
                                        $m_in = $entriesMonth[$id] ?? 0;
                                        $m_out = $exitsMonth[$id] ?? 0;
                                        
                                        if (($m_in + $m_out) == 0) continue;
                                    ?>
                                    <tr>
                                        <td class="text-start ps-4 fw-medium"><?= htmlspecialchars($name) ?></td>
                                        <td class="border-start text-success fw-bold"><?= $d_in ?: '-' ?></td>
                                        <td class="text-danger fw-bold"><?= $d_out ?: '-' ?></td>
                                        <td class="border-start text-success"><?= $w_in ?: '-' ?></td>
                                        <td class="text-danger"><?= $w_out ?: '-' ?></td>
                                        <td class="border-start text-success"><?= $m_in ?: '-' ?></td>
                                        <td class="text-danger"><?= $m_out ?: '-' ?></td>
                                    </tr>
                                <?php endforeach; ?>
                            <?php endif; ?>
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Chart.js -->
<script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
<script>
    // --- Data from PHP ---
    const labels = <?= json_encode($chartLabels) ?>;
    const dataIncome = <?= json_encode($chartIncome) ?>;
    const dataTraffic = <?= json_encode($chartTraffic) ?>;
    const currentOccupancy = <?= $currentOccupancy ?>;
    const availableSpaces = <?= $availableSpaces ?>;

    // --- Income Chart ---
    new Chart(document.getElementById('incomeChart'), {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Ingresos ($)',
                data: dataIncome,
                borderColor: 'rgb(75, 192, 192)',
                backgroundColor: 'rgba(75, 192, 192, 0.2)',
                tension: 0.3,
                fill: true
            }]
        },
        options: {
            responsive: true,
            plugins: { legend: { display: false } },
            scales: { y: { beginAtZero: true } }
        }
    });

    // --- Traffic Chart ---
    new Chart(document.getElementById('trafficChart'), {
        type: 'bar',
        data: {
            labels: labels,
            datasets: [{
                label: 'Entradas',
                data: dataTraffic,
                backgroundColor: 'rgba(54, 162, 235, 0.6)',
                borderColor: 'rgb(54, 162, 235)',
                borderWidth: 1
            }]
        },
        options: {
            responsive: true,
            plugins: { legend: { display: false } },
            scales: { y: { beginAtZero: true, ticks: { stepSize: 1 } } }
        }
    });

    // --- Occupancy Gauge (Doughnut) ---
    new Chart(document.getElementById('occupancyChart'), {
        type: 'doughnut',
        data: {
            labels: ['Ocupados', 'Libres'],
            datasets: [{
                data: [currentOccupancy, availableSpaces],
                backgroundColor: ['#dc3545', '#e9ecef'], // Red for occupied, Light Gray for free
                borderWidth: 0,
                cutout: '75%'
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: { legend: { display: false }, tooltip: { enabled: false } },
            animation: { animateScale: true }
        }
    });
</script>

<?php require_once 'includes/footer.php'; ?>
