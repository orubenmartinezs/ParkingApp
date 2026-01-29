<?php
require_once 'includes/auth.php';
require_once 'db.php';
require_once 'includes/helpers.php';
require_once 'includes/init_settings.php';

requireLogin();

$pdo = getDB();
initSystemSettings($pdo);

$currentUser = getCurrentUser();
$isAdmin = isAdmin();

// Filters
$reportType = $_GET['type'] ?? 'sales'; // 'sales' or 'financial'
$filter_start = $_GET['start'] ?? date('Y-m-01');
$filter_end = $_GET['end'] ?? date('Y-m-d');
$startTimestamp = strtotime($filter_start . ' 00:00:00') * 1000;
$endTimestamp = strtotime($filter_end . ' 23:59:59') * 1000;

// Data Fetching
$salesData = [];
$dailyData = [];
$financialSummary = [];

if ($reportType === 'sales') {
    $sql = "SELECT r.folio, r.plate, r.entry_time, r.exit_time, et.name as entry_type_name, r.cost, r.exit_user_id, r.payment_status 
            FROM parking_records r 
            LEFT JOIN entry_types et ON r.entry_type_id = et.id 
            WHERE r.exit_time >= ? AND r.exit_time <= ? 
            ORDER BY r.exit_time DESC";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([$startTimestamp, $endTimestamp]);
    $salesData = $stmt->fetchAll(PDO::FETCH_ASSOC);

} elseif ($reportType === 'financial') {
    // 1. Parking Income (Group by Day)
    $sql = "SELECT DATE(FROM_UNIXTIME(exit_time / 1000)) as day, SUM(cost) as total 
            FROM parking_records 
            WHERE exit_time >= ? AND exit_time <= ? 
            GROUP BY day";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([$startTimestamp, $endTimestamp]);
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $dailyData[$row['day']]['parking'] = $row['total'];
    }

    // 2. Pension Income
    $sql = "SELECT DATE(FROM_UNIXTIME(payment_date / 1000)) as day, SUM(amount) as total 
            FROM pension_payments 
            WHERE payment_date >= ? AND payment_date <= ? 
            GROUP BY day";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([$startTimestamp, $endTimestamp]);
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $dailyData[$row['day']]['pension'] = $row['total'];
    }

    // 3. Expenses
    $sql = "SELECT DATE(FROM_UNIXTIME(expense_date / 1000)) as day, SUM(amount) as total 
            FROM expenses 
            WHERE expense_date >= ? AND expense_date <= ? 
            GROUP BY day";
    $stmt = $pdo->prepare($sql);
    $stmt->execute([$startTimestamp, $endTimestamp]);
    while ($row = $stmt->fetch(PDO::FETCH_ASSOC)) {
        $dailyData[$row['day']]['expense'] = $row['total'];
    }

    // Sort by date descending
    krsort($dailyData);

    // Calculate Totals
    $incomeParking = 0;
    $incomePension = 0;
    $totalExpenses = 0;

    foreach ($dailyData as $day => $data) {
        $incomeParking += $data['parking'] ?? 0;
        $incomePension += $data['pension'] ?? 0;
        $totalExpenses += $data['expense'] ?? 0;
    }

    $financialSummary = [
        'income_parking' => $incomeParking,
        'income_pension' => $incomePension,
        'total_income' => $incomeParking + $incomePension,
        'total_expenses' => $totalExpenses,
        'balance' => ($incomeParking + $incomePension) - $totalExpenses
    ];
}

// Handle Download
if (isset($_GET['download']) && $_GET['download'] == 'true') {
    header('Content-Type: text/csv');
    header('Content-Disposition: attachment; filename="reporte_' . $reportType . '_' . $filter_start . '_' . $filter_end . '.csv"');
    
    $output = fopen('php://output', 'w');
    
    if ($reportType === 'sales') {
        fputcsv($output, ['Folio', 'Placa', 'Entrada', 'Salida', 'Tipo', 'Monto', 'Usuario Salida', 'Estado']);
        foreach ($salesData as $row) {
            fputcsv($output, [
                $row['folio'],
                $row['plate'],
                date('d/m/Y H:i', $row['entry_time'] / 1000),
                date('d/m/Y H:i', $row['exit_time'] / 1000),
                $row['entry_type_name'] ?? 'N/A',
                $row['cost'],
                $row['exit_user_id'],
                $row['payment_status']
            ]);
        }
    } elseif ($reportType === 'financial') {
        fputcsv($output, ['Fecha', 'Ingresos Estacionamiento', 'Ingresos Pensiones', 'Total Ingresos', 'Gastos', 'Balance Diario']);
        
        foreach ($dailyData as $day => $data) {
            $p = $data['parking'] ?? 0;
            $pen = $data['pension'] ?? 0;
            $inc = $p + $pen;
            $exp = $data['expense'] ?? 0;
            $bal = $inc - $exp;
            
            fputcsv($output, [
                $day,
                number_format($p, 2, '.', ''),
                number_format($pen, 2, '.', ''),
                number_format($inc, 2, '.', ''),
                number_format($exp, 2, '.', ''),
                number_format($bal, 2, '.', '')
            ]);
        }
        
        fputcsv($output, []);
        fputcsv($output, [
            'TOTALES',
            number_format($financialSummary['income_parking'], 2, '.', ''),
            number_format($financialSummary['income_pension'], 2, '.', ''),
            number_format($financialSummary['total_income'], 2, '.', ''),
            number_format($financialSummary['total_expenses'], 2, '.', ''),
            number_format($financialSummary['balance'], 2, '.', '')
        ]);
    }
    
    fclose($output);
    exit;
}

include 'includes/header.php';
?>

<div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
    <h1 class="h2">Reportes</h1>
    <div class="btn-toolbar mb-2 mb-md-0">
        <div class="btn-group me-2">
            <a href="?type=sales" class="btn btn-sm btn-outline-secondary <?= $reportType == 'sales' ? 'active' : '' ?>">Ventas</a>
            <a href="?type=financial" class="btn btn-sm btn-outline-secondary <?= $reportType == 'financial' ? 'active' : '' ?>">Financiero</a>
        </div>
        <a href="?type=<?= $reportType ?>&start=<?= $filter_start ?>&end=<?= $filter_end ?>&download=true" class="btn btn-sm btn-outline-success">
            <i class="bi bi-download"></i> Descargar CSV
        </a>
    </div>
</div>

<!-- Date Filter -->
<div class="card mb-4">
    <div class="card-body">
        <form method="GET" class="row g-3 align-items-end">
            <input type="hidden" name="type" value="<?= $reportType ?>">
            <div class="col-md-3">
                <label class="form-label">Desde</label>
                <input type="date" name="start" class="form-control" value="<?= htmlspecialchars($filter_start) ?>">
            </div>
            <div class="col-md-3">
                <label class="form-label">Hasta</label>
                <input type="date" name="end" class="form-control" value="<?= htmlspecialchars($filter_end) ?>">
            </div>
            <div class="col-md-3">
                <button type="submit" class="btn btn-primary w-100">Actualizar</button>
            </div>
        </form>
    </div>
</div>

<?php if ($reportType === 'sales'): ?>
    <div class="table-responsive">
        <table class="table table-striped table-sm">
            <thead>
                <tr>
                    <th>Folio</th>
                    <th>Placa</th>
                    <th>Entrada</th>
                    <th>Salida</th>
                    <th>Tipo</th>
                    <th>Monto</th>
                    <th>Estado</th>
                </tr>
            </thead>
            <tbody>
                <?php 
                $totalSales = 0;
                foreach ($salesData as $row): 
                    $totalSales += $row['cost'];
                ?>
                <tr>
                    <td><?= $row['folio'] ?></td>
                    <td><?= htmlspecialchars($row['plate']) ?></td>
                    <td><?= date('d/m H:i', $row['entry_time'] / 1000) ?></td>
                    <td><?= $row['exit_time'] ? date('d/m H:i', $row['exit_time'] / 1000) : '-' ?></td>
                    <td><?= htmlspecialchars($row['entry_type_name'] ?? 'N/A') ?></td>
                    <td>$<?= number_format($row['cost'], 2) ?></td>
                    <td>
                        <?php if ($row['payment_status'] == 'PAID'): ?>
                            <span class="badge bg-success">Pagado</span>
                        <?php elseif ($row['payment_status'] == 'PARTIAL'): ?>
                            <span class="badge bg-warning text-dark">Parcial</span>
                        <?php else: ?>
                            <span class="badge bg-danger">Pendiente</span>
                        <?php endif; ?>
                    </td>
                </tr>
                <?php endforeach; ?>
                <tr class="table-dark">
                    <td colspan="5" class="text-end"><strong>Total:</strong></td>
                    <td colspan="2"><strong>$<?= number_format($totalSales, 2) ?></strong></td>
                </tr>
            </tbody>
        </table>
    </div>

<?php elseif ($reportType === 'financial'): ?>
    <div class="row">
        <!-- Cards Summary -->
        <div class="col-md-4 mb-3">
            <div class="card text-white bg-success h-100">
                <div class="card-header">Total Ingresos</div>
                <div class="card-body">
                    <h2 class="card-title">$<?= number_format($financialSummary['total_income'], 2) ?></h2>
                    <p class="card-text">
                        Estacionamiento: $<?= number_format($financialSummary['income_parking'], 2) ?><br>
                        Pensiones: $<?= number_format($financialSummary['income_pension'], 2) ?>
                    </p>
                </div>
            </div>
        </div>
        <div class="col-md-4 mb-3">
            <div class="card text-white bg-danger h-100">
                <div class="card-header">Total Gastos</div>
                <div class="card-body">
                    <h2 class="card-title">$<?= number_format($financialSummary['total_expenses'], 2) ?></h2>
                    <p class="card-text">Gastos operativos registrados</p>
                </div>
            </div>
        </div>
        <div class="col-md-4 mb-3">
            <div class="card text-white <?= $financialSummary['balance'] >= 0 ? 'bg-primary' : 'bg-warning' ?> h-100">
                <div class="card-header">Balance Neto</div>
                <div class="card-body">
                    <h2 class="card-title">$<?= number_format($financialSummary['balance'], 2) ?></h2>
                    <p class="card-text"><?= $financialSummary['balance'] >= 0 ? 'Ganancia' : 'Pérdida' ?></p>
                </div>
            </div>
        </div>
    </div>
    
    <!-- Daily Breakdown Table -->
    <h3 class="mt-4">Detalle Diario</h3>
    <div class="table-responsive">
        <table class="table table-striped table-sm">
            <thead>
                <tr>
                    <th>Fecha</th>
                    <th class="text-success">Ingresos Estacionamiento</th>
                    <th class="text-success">Ingresos Pensiones</th>
                    <th class="text-primary">Total Ingresos</th>
                    <th class="text-danger">Gastos</th>
                    <th>Balance</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($dailyData as $day => $data): 
                    $p = $data['parking'] ?? 0;
                    $pen = $data['pension'] ?? 0;
                    $inc = $p + $pen;
                    $exp = $data['expense'] ?? 0;
                    $bal = $inc - $exp;
                ?>
                <tr>
                    <td><?= date('d/m/Y', strtotime($day)) ?></td>
                    <td>$<?= number_format($p, 2) ?></td>
                    <td>$<?= number_format($pen, 2) ?></td>
                    <td><strong>$<?= number_format($inc, 2) ?></strong></td>
                    <td class="text-danger">-$<?= number_format($exp, 2) ?></td>
                    <td class="<?= $bal >= 0 ? 'text-success' : 'text-danger' ?>"><strong>$<?= number_format($bal, 2) ?></strong></td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
    
<?php endif; ?>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
