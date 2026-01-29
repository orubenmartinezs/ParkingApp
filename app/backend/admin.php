<?php
require_once 'includes/auth.php';
require_once 'db.php';

requireLogin();

if (!isAdmin()) {
    echo "Acceso Denegado. Se requieren privilegios de Administrador.";
    exit;
}

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

// Handle Actions
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['action'])) {
        try {
            if ($_POST['action'] === 'add_user') {
                $id = gen_uuid();
                $name = $_POST['name'];
                $role = $_POST['role'];
                $pin = $_POST['pin'];
                
                $stmt = $pdo->prepare("INSERT INTO users (id, name, role, pin, is_active, is_synced) VALUES (?, ?, ?, ?, 1, 1)");
                $stmt->execute([$id, $name, $role, $pin]);
                $message = "Usuario agregado.";

            } elseif ($_POST['action'] === 'update_user') {
                $id = $_POST['user_id'];
                $name = $_POST['name'];
                $role = $_POST['role'];
                
                $stmt = $pdo->prepare("UPDATE users SET name = ?, role = ?, is_synced = 1 WHERE id = ?");
                $stmt->execute([$name, $role, $id]);
                $message = "Usuario actualizado.";

            } elseif ($_POST['action'] === 'delete_user') {
                $id = $_POST['user_id'];
                $stmt = $pdo->prepare("DELETE FROM users WHERE id = ?");
                $stmt->execute([$id]);
                $message = "Usuario eliminado.";

            } elseif ($_POST['action'] === 'update_user_pin') {
                $id = $_POST['user_id'];
                $pin = $_POST['pin'];
                $stmt = $pdo->prepare("UPDATE users SET pin = ?, is_synced = 1 WHERE id = ?");
                $stmt->execute([$pin, $id]);
                $message = "PIN actualizado.";

            } elseif ($_POST['action'] === 'toggle_user_status') {
                $id = $_POST['user_id'];
                $current = $_POST['current_status'];
                $new = $current == 1 ? 0 : 1;
                $stmt = $pdo->prepare("UPDATE users SET is_active = ?, is_synced = 1 WHERE id = ?");
                $stmt->execute([$new, $id]);
                $message = "Estado de usuario actualizado.";

            } elseif ($_POST['action'] === 'add_tariff_type') {
                $id = gen_uuid();
                $name = $_POST['name'];
                $cost = !empty($_POST['cost']) ? $_POST['cost'] : 0.00;
                $cost_first = !empty($_POST['cost_first']) ? $_POST['cost_first'] : 0.00;
                $cost_next = !empty($_POST['cost_next']) ? $_POST['cost_next'] : 0.00;
                $period_min = !empty($_POST['period_min']) ? $_POST['period_min'] : 60;
                $tolerance_min = !empty($_POST['tolerance_min']) ? $_POST['tolerance_min'] : 15;
                
                $stmt = $pdo->prepare("INSERT INTO tariff_types (id, name, default_cost, cost_first_period, cost_next_period, period_minutes, tolerance_minutes, is_active, is_synced) VALUES (?, ?, ?, ?, ?, ?, ?, 1, 1)");
                $stmt->execute([$id, $name, $cost, $cost_first, $cost_next, $period_min, $tolerance_min]);
                $message = "Tarifa agregada.";

            } elseif ($_POST['action'] === 'update_tariff_type') {
                $id = $_POST['id'];
                $name = $_POST['name'];
                $cost = !empty($_POST['cost']) ? $_POST['cost'] : 0.00;
                $cost_first = !empty($_POST['cost_first']) ? $_POST['cost_first'] : 0.00;
                $cost_next = !empty($_POST['cost_next']) ? $_POST['cost_next'] : 0.00;
                $period_min = !empty($_POST['period_min']) ? $_POST['period_min'] : 60;
                $tolerance_min = !empty($_POST['tolerance_min']) ? $_POST['tolerance_min'] : 15;
                
                $stmt = $pdo->prepare("UPDATE tariff_types SET name = ?, default_cost = ?, cost_first_period = ?, cost_next_period = ?, period_minutes = ?, tolerance_minutes = ?, is_synced = 1 WHERE id = ?");
                $stmt->execute([$name, $cost, $cost_first, $cost_next, $period_min, $tolerance_min, $id]);
                $message = "Tarifa actualizada.";

            } elseif ($_POST['action'] === 'delete_tariff_type') {
                $id = $_POST['id'];
                $stmt = $pdo->prepare("DELETE FROM tariff_types WHERE id = ?");
                $stmt->execute([$id]);
                $message = "Tarifa eliminada.";

            } elseif ($_POST['action'] === 'toggle_tariff_status') {
                $id = $_POST['id'];
                $current = $_POST['current_status'];
                $new = $current == 1 ? 0 : 1;
                $stmt = $pdo->prepare("UPDATE tariff_types SET is_active = ?, is_synced = 1 WHERE id = ?");
                $stmt->execute([$new, $id]);
                $message = "Estado de tarifa actualizado.";

            } elseif ($_POST['action'] === 'add_entry_type') {
                $id = gen_uuid();
                $name = $_POST['name'];
                $default_tariff_id = !empty($_POST['default_tariff_id']) ? $_POST['default_tariff_id'] : null;
                $stmt = $pdo->prepare("INSERT INTO entry_types (id, name, default_tariff_id, is_active, is_synced) VALUES (?, ?, ?, 1, 1)");
                $stmt->execute([$id, $name, $default_tariff_id]);
                $message = "Tipo de ingreso agregado.";

            } elseif ($_POST['action'] === 'update_entry_type') {
                $id = $_POST['id'];
                $name = $_POST['name'];
                $default_tariff_id = !empty($_POST['default_tariff_id']) ? $_POST['default_tariff_id'] : null;
                $stmt = $pdo->prepare("UPDATE entry_types SET name = ?, default_tariff_id = ?, is_synced = 1 WHERE id = ?");
                $stmt->execute([$name, $default_tariff_id, $id]);
                $message = "Tipo de ingreso actualizado.";

            } elseif ($_POST['action'] === 'delete_entry_type') {
                $id = $_POST['id'];
                $stmt = $pdo->prepare("DELETE FROM entry_types WHERE id = ?");
                $stmt->execute([$id]);
                $message = "Tipo de ingreso eliminado.";

            } elseif ($_POST['action'] === 'toggle_entry_status') {
                $id = $_POST['id'];
                $current = $_POST['current_status'];
                $new = $current == 1 ? 0 : 1;
                $stmt = $pdo->prepare("UPDATE entry_types SET is_active = ?, is_synced = 1 WHERE id = ?");
                $stmt->execute([$new, $id]);
                $message = "Estado de tipo de ingreso actualizado.";
            }
        } catch (Exception $e) {
            $error = "Error: " . $e->getMessage();
        }
    }
}

// Fetch Data
$users = $pdo->query("SELECT * FROM users ORDER BY name")->fetchAll();
$tariffs = $pdo->query("SELECT * FROM tariff_types ORDER BY name")->fetchAll();
$entryTypes = $pdo->query("SELECT * FROM entry_types ORDER BY name")->fetchAll();

$tariffMap = [];
foreach ($tariffs as $t) {
    $tariffMap[$t['id']] = $t['name'];
}

require_once 'includes/header.php';
?>

<div class="mb-4">
    <h2>Conf</h2>
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

<ul class="nav nav-tabs mb-4" id="adminTab" role="tablist">
    <li class="nav-item">
        <button class="nav-link active" id="users-tab" data-bs-toggle="tab" data-bs-target="#users" type="button">Usuarios</button>
    </li>
    <li class="nav-item">
        <button class="nav-link" id="tariffs-tab" data-bs-toggle="tab" data-bs-target="#tariffs" type="button">Tarifas</button>
    </li>
    <li class="nav-item">
        <button class="nav-link" id="entry-types-tab" data-bs-toggle="tab" data-bs-target="#entry-types" type="button">Tipos de Ingreso</button>
    </li>
</ul>

<div class="tab-content" id="adminTabContent">
    <!-- Users Tab -->
    <div class="tab-pane fade show active" id="users">
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h4>Gestión de Usuarios</h4>
            <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#addUserModal">
                <i class="bi bi-person-plus me-2"></i>Nuevo Usuario
            </button>
        </div>
        
        <div class="card shadow-sm">
            <div class="table-responsive">
                <table class="table table-hover align-middle mb-0">
                    <thead class="table-light">
                        <tr>
                            <th>Nombre</th>
                            <th>Rol</th>
                            <th>PIN</th>
                            <th>Estado</th>
                            <th class="text-end">Acciones</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($users as $u): ?>
                        <tr class="<?= $u['is_active'] ? '' : 'table-secondary' ?>">
                            <td class="fw-bold"><?= htmlspecialchars($u['name']) ?></td>
                            <td>
                                <span class="badge bg-<?= $u['role'] === 'ADMIN' ? 'danger' : 'info' ?>">
                                    <?= $u['role'] ?>
                                </span>
                            </td>
                            <td>****</td>
                            <td>
                                <?php if ($u['is_active']): ?>
                                    <span class="badge bg-success">Activo</span>
                                <?php else: ?>
                                    <span class="badge bg-secondary">Inactivo</span>
                                <?php endif; ?>
                            </td>
                            <td class="text-end">
                                <button class="btn btn-sm btn-outline-primary me-1" onclick="openPinModal('<?= $u['id'] ?>', '<?= $u['name'] ?>')" title="Cambiar PIN">
                                    <i class="bi bi-key"></i>
                                </button>
                                <button class="btn btn-sm btn-outline-info me-1" onclick="openEditUserModal('<?= $u['id'] ?>', '<?= $u['name'] ?>', '<?= $u['role'] ?>')" title="Editar">
                                    <i class="bi bi-pencil"></i>
                                </button>
                                <form method="POST" class="d-inline" onsubmit="return confirm('¿Estás seguro de eliminar este usuario?');">
                                    <input type="hidden" name="action" value="delete_user">
                                    <input type="hidden" name="user_id" value="<?= $u['id'] ?>">
                                    <button type="submit" class="btn btn-sm btn-outline-danger me-1" title="Eliminar">
                                        <i class="bi bi-trash"></i>
                                    </button>
                                </form>
                                <form method="POST" class="d-inline">
                                    <input type="hidden" name="action" value="toggle_user_status">
                                    <input type="hidden" name="user_id" value="<?= $u['id'] ?>">
                                    <input type="hidden" name="current_status" value="<?= $u['is_active'] ?>">
                                    <button type="submit" class="btn btn-sm btn-outline-warning" title="<?= $u['is_active'] ? 'Desactivar' : 'Activar' ?>">
                                        <i class="bi bi-power"></i>
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

    <!-- Tariffs Tab -->
    <div class="tab-pane fade" id="tariffs">
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h4>Gestión de Tarifas</h4>
            <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#addTariffModal">
                <i class="bi bi-plus-lg me-2"></i>Nueva Tarifa
            </button>
        </div>
        <div class="card shadow-sm">
            <div class="table-responsive">
                <table class="table table-hover align-middle mb-0">
                    <thead class="table-light">
                        <tr>
                            <th>Nombre</th>
                            <th>Reglas de Cobro</th>
                            <th>Estado</th>
                            <th class="text-end">Acciones</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($tariffs as $t): ?>
                        <tr class="<?= $t['is_active'] ? '' : 'table-secondary' ?>">
                            <td class="fw-bold"><?= htmlspecialchars($t['name']) ?></td>
                            <td>
                                <div class="small">
                                    <strong>Base:</strong> $<?= number_format($t['default_cost'], 2) ?><br>
                                    <?php if ($t['cost_first_period'] > 0 || $t['cost_next_period'] > 0): ?>
                                    <strong>1er Periodo:</strong> $<?= number_format($t['cost_first_period'], 2) ?><br>
                                    <strong>Sig. Periodos:</strong> $<?= number_format($t['cost_next_period'], 2) ?> (<?= $t['period_minutes'] ?>m)<br>
                                    <strong>Tolerancia:</strong> <?= $t['tolerance_minutes'] ?>m
                                    <?php endif; ?>
                                </div>
                            </td>
                            <td>
                                <?php if ($t['is_active']): ?>
                                    <span class="badge bg-success">Activo</span>
                                <?php else: ?>
                                    <span class="badge bg-secondary">Inactivo</span>
                                <?php endif; ?>
                            </td>
                            <td class="text-end">
                                <button class="btn btn-sm btn-outline-info me-1" onclick="openEditTariffModal('<?= $t['id'] ?>', '<?= $t['name'] ?>', '<?= $t['default_cost'] ?>', '<?= $t['cost_first_period'] ?>', '<?= $t['cost_next_period'] ?>', '<?= $t['period_minutes'] ?>', '<?= $t['tolerance_minutes'] ?>')" title="Editar">
                                    <i class="bi bi-pencil"></i>
                                </button>
                                <form method="POST" class="d-inline" onsubmit="return confirm('¿Estás seguro de eliminar esta tarifa?');">
                                    <input type="hidden" name="action" value="delete_tariff_type">
                                    <input type="hidden" name="id" value="<?= $t['id'] ?>">
                                    <button type="submit" class="btn btn-sm btn-outline-danger me-1" title="Eliminar">
                                        <i class="bi bi-trash"></i>
                                    </button>
                                </form>
                                <form method="POST" class="d-inline">
                                    <input type="hidden" name="action" value="toggle_tariff_status">
                                    <input type="hidden" name="id" value="<?= $t['id'] ?>">
                                    <input type="hidden" name="current_status" value="<?= $t['is_active'] ?>">
                                    <button type="submit" class="btn btn-sm btn-outline-warning" title="<?= $t['is_active'] ? 'Desactivar' : 'Activar' ?>">
                                        <i class="bi bi-power"></i>
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

    <!-- Entry Types Tab -->
    <div class="tab-pane fade" id="entry-types">
        <div class="d-flex justify-content-between align-items-center mb-3">
            <h4>Tipos de Ingreso</h4>
            <button class="btn btn-primary" data-bs-toggle="modal" data-bs-target="#addEntryTypeModal">
                <i class="bi bi-plus-lg me-2"></i>Nuevo Tipo
            </button>
        </div>
        <div class="card shadow-sm">
            <div class="table-responsive">
                <table class="table table-hover align-middle mb-0">
                    <thead class="table-light">
                        <tr>
                            <th>Nombre</th>
                            <th>Tarifa Sugerida</th>
                            <th>Estado</th>
                            <th class="text-end">Acciones</th>
                        </tr>
                    </thead>
                    <tbody>
                        <?php foreach ($entryTypes as $e): ?>
                        <tr class="<?= $e['is_active'] ? '' : 'table-secondary' ?>">
                            <td class="fw-bold"><?= htmlspecialchars($e['name']) ?></td>
                            <td>
                                <?php if (!empty($e['default_tariff_id']) && isset($tariffMap[$e['default_tariff_id']])): ?>
                                    <span class="badge bg-info text-dark"><?= htmlspecialchars($tariffMap[$e['default_tariff_id']]) ?></span>
                                <?php else: ?>
                                    <span class="text-muted small">--</span>
                                <?php endif; ?>
                            </td>
                            <td>
                                <?php if ($e['is_active']): ?>
                                    <span class="badge bg-success">Activo</span>
                                <?php else: ?>
                                    <span class="badge bg-secondary">Inactivo</span>
                                <?php endif; ?>
                            </td>
                            <td class="text-end">
                                <button class="btn btn-sm btn-outline-info me-1" onclick="openEditEntryTypeModal('<?= $e['id'] ?>', '<?= $e['name'] ?>', '<?= $e['default_tariff_id'] ?? '' ?>')" title="Editar">
                                    <i class="bi bi-pencil"></i>
                                </button>
                                <form method="POST" class="d-inline" onsubmit="return confirm('¿Estás seguro de eliminar este tipo de ingreso?');">
                                    <input type="hidden" name="action" value="delete_entry_type">
                                    <input type="hidden" name="id" value="<?= $e['id'] ?>">
                                    <button type="submit" class="btn btn-sm btn-outline-danger me-1" title="Eliminar">
                                        <i class="bi bi-trash"></i>
                                    </button>
                                </form>
                                <form method="POST" class="d-inline">
                                    <input type="hidden" name="action" value="toggle_entry_status">
                                    <input type="hidden" name="id" value="<?= $e['id'] ?>">
                                    <input type="hidden" name="current_status" value="<?= $e['is_active'] ?>">
                                    <button type="submit" class="btn btn-sm btn-outline-warning" title="<?= $e['is_active'] ? 'Desactivar' : 'Activar' ?>">
                                        <i class="bi bi-power"></i>
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
</div>

<!-- Add User Modal -->
<div class="modal fade" id="addUserModal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Nuevo Usuario</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <form method="POST">
                <div class="modal-body">
                    <input type="hidden" name="action" value="add_user">
                    <div class="mb-3">
                        <label class="form-label">Nombre</label>
                        <input type="text" class="form-control" name="name" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Rol</label>
                        <select class="form-select" name="role">
                            <option value="STAFF">STAFF</option>
                            <option value="ADMIN">ADMIN</option>
                        </select>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">PIN (4 dígitos)</label>
                        <input type="number" class="form-control" name="pin" required maxlength="4" placeholder="1234">
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

<!-- Change PIN Modal -->
<div class="modal fade" id="pinModal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Cambiar PIN: <span id="pin_user_name"></span></h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <form method="POST">
                <div class="modal-body">
                    <input type="hidden" name="action" value="update_user_pin">
                    <input type="hidden" name="user_id" id="pin_user_id">
                    <div class="mb-3">
                        <label class="form-label">Nuevo PIN</label>
                        <input type="number" class="form-control" name="pin" required maxlength="4" placeholder="****">
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-primary">Actualizar</button>
                </div>
            </form>
        </div>
    </div>
</div>

<!-- Edit User Modal -->
<div class="modal fade" id="editUserModal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Editar Usuario</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <form method="POST">
                <div class="modal-body">
                    <input type="hidden" name="action" value="update_user">
                    <input type="hidden" name="user_id" id="edit_user_id">
                    <div class="mb-3">
                        <label class="form-label">Nombre</label>
                        <input type="text" class="form-control" name="name" id="edit_user_name" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Rol</label>
                        <select class="form-select" name="role" id="edit_user_role">
                            <option value="STAFF">STAFF</option>
                            <option value="ADMIN">ADMIN</option>
                        </select>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-primary">Guardar Cambios</button>
                </div>
            </form>
        </div>
    </div>
</div>

<!-- Edit Tariff Modal -->
<div class="modal fade" id="editTariffModal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Editar Tarifa</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <form method="POST">
                <div class="modal-body">
                    <input type="hidden" name="action" value="update_tariff_type">
                    <input type="hidden" name="id" id="edit_tariff_id">
                    <div class="mb-3">
                        <label class="form-label">Nombre</label>
                        <input type="text" class="form-control" name="name" id="edit_tariff_name" required>
                    </div>
                    <div class="row">
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Costo Base / Sugerido</label>
                            <input type="number" step="0.01" class="form-control" name="cost" id="edit_tariff_cost" required>
                        </div>
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Tolerancia (min)</label>
                            <input type="number" class="form-control" name="tolerance_min" id="edit_tariff_tolerance" value="15">
                        </div>
                    </div>
                    <h6 class="border-bottom pb-2 mb-3 mt-2">Cálculo por Tiempo</h6>
                    <div class="row">
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Costo 1er Periodo</label>
                            <input type="number" step="0.01" class="form-control" name="cost_first" id="edit_tariff_cost_first" value="0">
                        </div>
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Costo Sig. Periodos</label>
                            <input type="number" step="0.01" class="form-control" name="cost_next" id="edit_tariff_cost_next" value="0">
                        </div>
                        <div class="col-md-12 mb-3">
                            <label class="form-label">Duración Periodo (minutos)</label>
                            <input type="number" class="form-control" name="period_min" id="edit_tariff_period" value="60">
                            <div class="form-text">Ej: 60 para cobro por hora.</div>
                        </div>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-primary">Guardar Cambios</button>
                </div>
            </form>
        </div>
    </div>
</div>

<!-- Edit Entry Type Modal -->
<div class="modal fade" id="editEntryTypeModal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Editar Tipo de Ingreso</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <form method="POST">
                <div class="modal-body">
                    <input type="hidden" name="action" value="update_entry_type">
                    <input type="hidden" name="id" id="edit_entry_id">
                    <div class="mb-3">
                        <label class="form-label">Nombre</label>
                        <input type="text" class="form-control" name="name" id="edit_entry_name" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Tarifa Sugerida</label>
                        <select class="form-select" name="default_tariff_id" id="edit_entry_default_tariff">
                            <option value="">-- Ninguna --</option>
                            <?php foreach ($tariffs as $t): ?>
                                <option value="<?= $t['id'] ?>"><?= htmlspecialchars($t['name']) ?></option>
                            <?php endforeach; ?>
                        </select>
                    </div>
                </div>
                <div class="modal-footer">
                    <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
                    <button type="submit" class="btn btn-primary">Guardar Cambios</button>
                </div>
            </form>
        </div>
    </div>
</div>

<script>
function openPinModal(id, name) {
    document.getElementById('pin_user_id').value = id;
    document.getElementById('pin_user_name').innerText = name;
    new bootstrap.Modal(document.getElementById('pinModal')).show();
}

function openEditUserModal(id, name, role) {
    document.getElementById('edit_user_id').value = id;
    document.getElementById('edit_user_name').value = name;
    document.getElementById('edit_user_role').value = role;
    new bootstrap.Modal(document.getElementById('editUserModal')).show();
}

function openEditTariffModal(id, name, cost, costFirst, costNext, periodMin, toleranceMin) {
    document.getElementById('edit_tariff_id').value = id;
    document.getElementById('edit_tariff_name').value = name;
    document.getElementById('edit_tariff_cost').value = cost;
    document.getElementById('edit_tariff_cost_first').value = costFirst || 0;
    document.getElementById('edit_tariff_cost_next').value = costNext || 0;
    document.getElementById('edit_tariff_period').value = periodMin || 60;
    document.getElementById('edit_tariff_tolerance').value = toleranceMin || 15;
    new bootstrap.Modal(document.getElementById('editTariffModal')).show();
}

function openEditEntryTypeModal(id, name, defaultTariffId) {
    document.getElementById('edit_entry_id').value = id;
    document.getElementById('edit_entry_name').value = name;
    document.getElementById('edit_entry_default_tariff').value = defaultTariffId || '';
    new bootstrap.Modal(document.getElementById('editEntryTypeModal')).show();
}
</script>

<!-- Add Tariff Modal -->
<div class="modal fade" id="addTariffModal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Nueva Tarifa</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <form method="POST">
                <div class="modal-body">
                    <input type="hidden" name="action" value="add_tariff_type">
                    <div class="mb-3">
                        <label class="form-label">Nombre</label>
                        <input type="text" class="form-control" name="name" required>
                    </div>
                    <div class="row">
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Costo Base / Sugerido</label>
                            <input type="number" step="0.01" class="form-control" name="cost" required>
                        </div>
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Tolerancia (min)</label>
                            <input type="number" class="form-control" name="tolerance_min" value="15">
                        </div>
                    </div>
                    <h6 class="border-bottom pb-2 mb-3 mt-2">Cálculo por Tiempo</h6>
                    <div class="row">
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Costo 1er Periodo</label>
                            <input type="number" step="0.01" class="form-control" name="cost_first" value="0">
                        </div>
                        <div class="col-md-6 mb-3">
                            <label class="form-label">Costo Sig. Periodos</label>
                            <input type="number" step="0.01" class="form-control" name="cost_next" value="0">
                        </div>
                        <div class="col-md-12 mb-3">
                            <label class="form-label">Duración Periodo (minutos)</label>
                            <input type="number" class="form-control" name="period_min" value="60">
                            <div class="form-text">Ej: 60 para cobro por hora.</div>
                        </div>
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

<!-- Add Entry Type Modal -->
<div class="modal fade" id="addEntryTypeModal" tabindex="-1">
    <div class="modal-dialog">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Nuevo Tipo de Ingreso</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <form method="POST">
                <div class="modal-body">
                    <input type="hidden" name="action" value="add_entry_type">
                    <div class="mb-3">
                        <label class="form-label">Nombre</label>
                        <input type="text" class="form-control" name="name" required>
                    </div>
                    <div class="mb-3">
                        <label class="form-label">Tarifa Sugerida</label>
                        <select class="form-select" name="default_tariff_id">
                            <option value="">-- Ninguna --</option>
                            <?php foreach ($tariffs as $t): ?>
                                <option value="<?= $t['id'] ?>"><?= htmlspecialchars($t['name']) ?></option>
                            <?php endforeach; ?>
                        </select>
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

<?php require_once 'includes/footer.php'; ?>
