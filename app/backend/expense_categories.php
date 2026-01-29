<?php
require_once 'includes/auth.php';
require_once 'db.php';
require_once 'includes/helpers.php';

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

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $action = $_POST['action'] ?? '';
    
    try {
        if ($action === 'create') {
            $id = gen_uuid();
            $name = trim($_POST['name']);
            $description = trim($_POST['description']);
            
            if (empty($name)) {
                throw new Exception("El nombre es obligatorio.");
            }

            $stmt = $pdo->prepare("INSERT INTO expense_categories (id, name, description, is_active, is_synced) VALUES (?, ?, ?, 1, 1)");
            $stmt->execute([$id, $name, $description]);
            $message = "Categoría agregada correctamente.";

        } elseif ($action === 'update') {
            $id = $_POST['id'];
            $name = trim($_POST['name']);
            $description = trim($_POST['description']);
            $is_active = isset($_POST['is_active']) ? 1 : 0;
            
            if (empty($name)) {
                throw new Exception("El nombre es obligatorio.");
            }

            $stmt = $pdo->prepare("UPDATE expense_categories SET name = ?, description = ?, is_active = ?, is_synced = 1 WHERE id = ?");
            $stmt->execute([$name, $description, $is_active, $id]);
            $message = "Categoría actualizada.";

        } elseif ($action === 'delete') {
            $id = $_POST['id'];
            $stmt = $pdo->prepare("DELETE FROM expense_categories WHERE id = ?");
            $stmt->execute([$id]);
            $message = "Categoría eliminada.";
        }
    } catch (Exception $e) {
        $error = "Error: " . $e->getMessage();
    }
}

$categories = $pdo->query("SELECT * FROM expense_categories ORDER BY name ASC")->fetchAll(PDO::FETCH_ASSOC);

include 'includes/header.php';
?>

<div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
    <h1 class="h2">Categorías de Gastos</h1>
    <div class="btn-toolbar mb-2 mb-md-0">
        <button type="button" class="btn btn-sm btn-primary" data-bs-toggle="modal" data-bs-target="#createModal">
            <i class="bi bi-plus-lg"></i> Nueva Categoría
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

<div class="table-responsive">
    <table class="table table-striped table-hover">
        <thead>
            <tr>
                <th>Nombre</th>
                <th>Descripción</th>
                <th>Estado</th>
                <th>Acciones</th>
            </tr>
        </thead>
        <tbody>
            <?php foreach ($categories as $cat): ?>
                <tr>
                    <td><?= htmlspecialchars($cat['name']) ?></td>
                    <td><?= htmlspecialchars($cat['description']) ?></td>
                    <td>
                        <?php if ($cat['is_active']): ?>
                            <span class="badge bg-success">Activo</span>
                        <?php else: ?>
                            <span class="badge bg-secondary">Inactivo</span>
                        <?php endif; ?>
                    </td>
                    <td>
                        <button class="btn btn-sm btn-outline-primary" 
                                onclick="editCategory(<?= htmlspecialchars(json_encode($cat)) ?>)">
                            <i class="bi bi-pencil"></i>
                        </button>
                        <button class="btn btn-sm btn-outline-danger" 
                                onclick="deleteCategory('<?= $cat['id'] ?>', '<?= htmlspecialchars($cat['name']) ?>')">
                            <i class="bi bi-trash"></i>
                        </button>
                    </td>
                </tr>
            <?php endforeach; ?>
            <?php if (empty($categories)): ?>
                <tr><td colspan="4" class="text-center text-muted">No hay categorías registradas.</td></tr>
            <?php endif; ?>
        </tbody>
    </table>
</div>

<!-- Create Modal -->
<div class="modal fade" id="createModal" tabindex="-1">
    <div class="modal-dialog">
        <form method="POST" class="modal-content">
            <input type="hidden" name="action" value="create">
            <div class="modal-header">
                <h5 class="modal-title">Nueva Categoría</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <div class="mb-3">
                    <label class="form-label">Nombre</label>
                    <input type="text" name="name" class="form-control" required>
                </div>
                <div class="mb-3">
                    <label class="form-label">Descripción</label>
                    <textarea name="description" class="form-control" rows="3"></textarea>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
                <button type="submit" class="btn btn-primary">Guardar</button>
            </div>
        </form>
    </div>
</div>

<!-- Edit Modal -->
<div class="modal fade" id="editModal" tabindex="-1">
    <div class="modal-dialog">
        <form method="POST" class="modal-content">
            <input type="hidden" name="action" value="update">
            <input type="hidden" name="id" id="edit_id">
            <div class="modal-header">
                <h5 class="modal-title">Editar Categoría</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <div class="mb-3">
                    <label class="form-label">Nombre</label>
                    <input type="text" name="name" id="edit_name" class="form-control" required>
                </div>
                <div class="mb-3">
                    <label class="form-label">Descripción</label>
                    <textarea name="description" id="edit_description" class="form-control" rows="3"></textarea>
                </div>
                <div class="form-check form-switch">
                    <input class="form-check-input" type="checkbox" name="is_active" id="edit_is_active">
                    <label class="form-check-label" for="edit_is_active">Activo</label>
                </div>
            </div>
            <div class="modal-footer">
                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancelar</button>
                <button type="submit" class="btn btn-primary">Actualizar</button>
            </div>
        </form>
    </div>
</div>

<!-- Delete Form -->
<form id="deleteForm" method="POST" style="display:none;">
    <input type="hidden" name="action" value="delete">
    <input type="hidden" name="id" id="delete_id">
</form>

<script>
function editCategory(cat) {
    document.getElementById('edit_id').value = cat.id;
    document.getElementById('edit_name').value = cat.name;
    document.getElementById('edit_description').value = cat.description;
    document.getElementById('edit_is_active').checked = cat.is_active == 1;
    
    new bootstrap.Modal(document.getElementById('editModal')).show();
}

function deleteCategory(id, name) {
    if (confirm('¿Estás seguro de eliminar la categoría "' + name + '"?')) {
        document.getElementById('delete_id').value = id;
        document.getElementById('deleteForm').submit();
    }
}
</script>

<?php include 'includes/footer.php'; ?>
