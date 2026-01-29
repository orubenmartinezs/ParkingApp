<?php
require_once 'includes/auth.php';
require_once 'db.php';
require_once 'includes/helpers.php';
require_once 'includes/init_settings.php';

requireLogin();

$pdo = getDB();
initSystemSettings($pdo); // Set Timezone

$currentUser = getCurrentUser();
$isAdmin = isAdmin();

$message = '';
$error = '';

// Handle CRUD Actions
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';
    
    try {
        if ($action === 'create') {
            $id = $_POST['id'] ?: sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x', mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0x0fff) | 0x4000, mt_rand(0, 0x3fff) | 0x8000, mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff));
            $description = $_POST['description'];
            $amount = (float)$_POST['amount'];
            $category = $_POST['category'];
            
            // Convert datetime-local string to milliseconds
            $expense_date = strtotime($_POST['expense_date']) * 1000;
            $user_id = $currentUser['id']; // Current user records the expense

            $sql = "INSERT INTO expenses (id, description, amount, category, expense_date, user_id, is_synced, created_at, updated_at) 
                    VALUES (?, ?, ?, ?, ?, ?, 1, NOW(), NOW())";
            $stmt = $pdo->prepare($sql);
            $stmt->execute([$id, $description, $amount, $category, $expense_date, $user_id]);
            $message = "Gasto registrado correctamente.";

        } elseif ($action === 'update' && $isAdmin) {
            $id = $_POST['id'];
            $description = $_POST['description'];
            $amount = (float)$_POST['amount'];
            $category = $_POST['category'];
            $expense_date = strtotime($_POST['expense_date']) * 1000;

            $sql = "UPDATE expenses SET 
                    description = ?, amount = ?, category = ?, expense_date = ?, is_synced = 1, updated_at = NOW()
                    WHERE id = ?";
            $stmt = $pdo->prepare($sql);
            $stmt->execute([$description, $amount, $category, $expense_date, $id]);
            $message = "Gasto actualizado correctamente.";

        } elseif ($action === 'delete' && $isAdmin) {
            $id = $_POST['id'];
            $stmt = $pdo->prepare("DELETE FROM expenses WHERE id = ?");
            $stmt->execute([$id]);
            $message = "Gasto eliminado.";
        }
    } catch (Exception $e) {
        $error = "Error: " . $e->getMessage();
    }
}

// Filtering
$filter_start = $_GET['start'] ?? date('Y-m-01'); // First day of current month
$filter_end = $_GET['end'] ?? date('Y-m-d'); // Today

$page = isset($_GET['page']) ? (int)$_GET['page'] : 1;
$perPage = 20;
$offset = ($page - 1) * $perPage;

// Build Query
$where = ["expense_date >= ? AND expense_date <= ?"];
// Add 23:59:59 to end date for filter
$startTimestamp = strtotime($filter_start . ' 00:00:00') * 1000;
$endTimestamp = strtotime($filter_end . ' 23:59:59') * 1000;

$params = [$startTimestamp, $endTimestamp];

$sql = "SELECT * FROM expenses WHERE " . implode(" AND ", $where) . " ORDER BY expense_date DESC LIMIT $perPage OFFSET $offset";
$stmt = $pdo->prepare($sql);
$stmt->execute($params);
$expenses = $stmt->fetchAll(PDO::FETCH_ASSOC);

// Total Count for Pagination
$sqlCount = "SELECT COUNT(*) FROM expenses WHERE " . implode(" AND ", $where);
$stmtCount = $pdo->prepare($sqlCount);
$stmtCount->execute($params);
$totalRecords = $stmtCount->fetchColumn();
$totalPages = ceil($totalRecords / $perPage);

// Calculate Total for Period
$sqlTotal = "SELECT SUM(amount) FROM expenses WHERE " . implode(" AND ", $where);
$stmtTotal = $pdo->prepare($sqlTotal);
$stmtTotal->execute($params);
$periodTotal = $stmtTotal->fetchColumn() ?: 0;

// Fetch Categories for Dropdown
$expenseCategories = $pdo->query("SELECT name FROM expense_categories WHERE is_active = 1 ORDER BY name ASC")->fetchAll(PDO::FETCH_COLUMN);

include 'includes/header.php';
?>

<div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
    <h1 class="h2">Control de Gastos</h1>
    <div class="btn-toolbar mb-2 mb-md-0">
        <button type="button" class="btn btn-sm btn-outline-primary" data-bs-toggle="modal" data-bs-target="#createModal">
            <i class="bi bi-plus-lg"></i> Registrar Gasto
        </button>
    </div>
</div>

<?php if ($message): ?>
    <div class="alert alert-success alert-dismissible fade show" role="alert">
        <?= $message ?>
        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
    </div>
<?php endif; ?>

<?php if ($error): ?>
    <div class="alert alert-danger alert-dismissible fade show" role="alert">
        <?= $error ?>
        <button type="button" class="btn-close" data-bs-dismiss="alert" aria-label="Close"></button>
    </div>
<?php endif; ?>

<!-- Filters -->
<div class="card mb-4">
    <div class="card-body">
        <form method="GET" class="row g-3 align-items-end">
            <div class="col-md-3">
                <label class="form-label">Desde</label>
                <input type="date" name="start" class="form-control" value="<?= htmlspecialchars($filter_start) ?>">
            </div>
            <div class="col-md-3">
                <label class="form-label">Hasta</label>
                <input type="date" name="end" class="form-control" value="<?= htmlspecialchars($filter_end) ?>">
            </div>
            <div class="col-md-3">
                <button type="submit" class="btn btn-primary w-100">Filtrar</button>
            </div>
        </form>
    </div>
</div>

<div class="row mb-3">
    <div class="col-md-12">
        <div class="alert alert-info">
            <strong>Total Gastos (Periodo):</strong> $<?= number_format($periodTotal, 2) ?>
        </div>
    </div>
</div>

<div class="table-responsive">
    <table class="table table-striped table-hover">
        <thead>
            <tr>
                <th>Fecha</th>
                <th>Descripción</th>
                <th>Categoría</th>
                <th>Monto</th>
                <?php if ($isAdmin): ?><th>Acciones</th><?php endif; ?>
            </tr>
        </thead>
        <tbody>
            <?php foreach ($expenses as $expense): ?>
                <tr>
                    <td><?= date('d/m/Y H:i', $expense['expense_date'] / 1000) ?></td>
                    <td><?= htmlspecialchars($expense['description']) ?></td>
                    <td><span class="badge bg-secondary"><?= htmlspecialchars($expense['category']) ?></span></td>
                    <td class="text-danger">-$<?= number_format($expense['amount'], 2) ?></td>
                    <?php if ($isAdmin): ?>
                    <td>
                        <button class="btn btn-sm btn-outline-primary" 
                                onclick="editExpense(<?= htmlspecialchars(json_encode($expense)) ?>)">
                            <i class="bi bi-pencil"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-danger" 
                                onclick="deleteExpense('<?= $expense['id'] ?>')">
                            <i class="bi bi-trash"></i>
                        </button>
                    </td>
                    <?php endif; ?>
                </tr>
            <?php endforeach; ?>
            <?php if (empty($expenses)): ?>
                <tr><td colspan="5" class="text-center text-muted">No hay gastos registrados en este periodo.</td></tr>
            <?php endif; ?>
        </tbody>
    </table>
</div>

<!-- Pagination -->
<?php if ($totalPages > 1): ?>
<nav>
    <ul class="pagination justify-content-center">
        <?php for ($i = 1; $i <= $totalPages; $i++): ?>
            <li class="page-item <?= $i == $page ? 'active' : '' ?>">
                <a class="page-link" href="?page=<?= $i ?>&start=<?= $filter_start ?>&end=<?= $filter_end ?>"><?= $i ?></a>
            </li>
        <?php endfor; ?>
    </ul>
</nav>
<?php endif; ?>

<!-- Create Modal -->
<div class="modal fade" id="createModal" tabindex="-1">
    <div class="modal-dialog">
        <form method="POST">
            <input type="hidden" name="action" value="create">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Registrar Nuevo Gasto</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <div class="mb-3">
                        <label class="form-label">Descripción</label>
                        <input type="text" name="description" class="form-control" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Monto</label>
                        <input type="number" step="0.01" name="amount" class="form-control" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Categoría</label>
                        <select name="category" class="form-select">
                            <?php foreach ($expenseCategories as $cat): ?>
                                <option value="<?= htmlspecialchars($cat) ?>"><?= htmlspecialchars($cat) ?></option>
                            <?php endforeach; ?>
                            <?php if (empty($expenseCategories)): ?>
                                <option value="General">General</option>
                            <?php endif; ?>
                        </select>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Fecha</label>
                        <input type="datetime-local" name="expense_date" class="form-control" value="<?= date('Y-m-d\TH:i') ?>" required>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-primary">Guardar</button>
                </div>
            </div>
        </form>
    </div>
</div>

<!-- Edit Modal -->
<div class="modal fade" id="editModal" tabindex="-1">
    <div class="modal-dialog">
        <form method="POST">
            <input type="hidden" name="action" value="update">
            <input type="hidden" name="id" id="edit_id">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Editar Gasto</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    <div class="mb-3">
                        <label class="form-label">Descripción</label>
                        <input type="text" name="description" id="edit_description" class="form-control" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Monto</label>
                        <input type="number" step="0.01" name="amount" id="edit_amount" class="form-control" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Categoría</label>
                        <select name="category" id="edit_category" class="form-select">
                            <?php foreach ($expenseCategories as $cat): ?>
                                <option value="<?= htmlspecialchars($cat) ?>"><?= htmlspecialchars($cat) ?></option>
                            <?php endforeach; ?>
                            <?php if (empty($expenseCategories)): ?>
                                <option value="General">General</option>
                            <?php endif; ?>
                        </select>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Fecha</label>
                        <input type="datetime-local" name="expense_date" id="edit_expense_date" class="form-control" required>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-primary">Actualizar</button>
                </div>
            </div>
        </form>
    </div>
</div>

<!-- Delete Modal -->
<div class="modal fade" id="deleteModal" tabindex="-1">
    <div class="modal-dialog">
        <form method="POST">
            <input type="hidden" name="action" value="delete">
            <input type="hidden" name="id" id="delete_id">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">Confirmar Eliminación</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                </div>
                <div class="modal-body">
                    ¿Estás seguro de que deseas eliminar este gasto? Esta acción no se puede deshacer.
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-danger">Eliminar</button>
                </div>
            </div>
        </form>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
<script>
function editExpense(expense) {
    document.getElementById('edit_id').value = expense.id;
    document.getElementById('edit_description').value = expense.description;
    document.getElementById('edit_amount').value = expense.amount;
    document.getElementById('edit_category').value = expense.category;
    
    // Format date for datetime-local input (YYYY-MM-DDTHH:mm)
    let date = new Date(expense.expense_date);
    // Adjust for timezone offset if necessary, or just use string manipulation
    let year = date.getFullYear();
    let month = ('0' + (date.getMonth() + 1)).slice(-2);
    let day = ('0' + date.getDate()).slice(-2);
    let hours = ('0' + date.getHours()).slice(-2);
    let minutes = ('0' + date.getMinutes()).slice(-2);
    
    document.getElementById('edit_expense_date').value = `${year}-${month}-${day}T${hours}:${minutes}`;
    
    new bootstrap.Modal(document.getElementById('editModal')).show();
}

function deleteExpense(id) {
    document.getElementById('delete_id').value = id;
    new bootstrap.Modal(document.getElementById('deleteModal')).show();
}
</script>
</body>
</html>
