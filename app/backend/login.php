<?php
require_once 'includes/auth.php';
require_once 'db.php';

if (isLoggedIn()) {
    header('Location: index.php');
    exit;
}

$error = '';
$pdo = getDB();

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $userId = $_POST['user_id'] ?? '';
    $pin = $_POST['pin'] ?? '';

    if ($userId && $pin) {
        $stmt = $pdo->prepare("SELECT * FROM users WHERE id = ? AND is_active = 1");
        $stmt->execute([$userId]);
        $user = $stmt->fetch();

        if ($user && $user['pin'] === $pin) {
            $_SESSION['user_id'] = $user['id'];
            $_SESSION['user'] = $user;
            header('Location: index.php');
            exit;
        } else {
            $error = 'PIN incorrecto';
        }
    } else {
        $error = 'Por favor seleccione usuario e ingrese PIN';
    }
}

// Fetch active users for dropdown
$stmt = $pdo->query("SELECT id, name, role FROM users WHERE is_active = 1 ORDER BY name");
$users = $stmt->fetchAll();
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Login - Parking Control</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <style>
        body {
            height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
            background-color: #f8f9fa;
        }
        .login-card {
            width: 100%;
            max-width: 400px;
        }
    </style>
</head>
<body>
    <div class="card login-card shadow-sm">
        <div class="card-body p-4">
            <h4 class="card-title text-center mb-4">Parking Control</h4>
            
            <?php if ($error): ?>
                <div class="alert alert-danger"><?= htmlspecialchars($error) ?></div>
            <?php endif; ?>

            <form method="POST">
                <div class="mb-3">
                    <label for="user_id" class="form-label">Usuario</label>
                    <select class="form-select form-select-lg" name="user_id" id="user_id" required>
                        <option value="">Seleccione Usuario</option>
                        <?php foreach ($users as $user): ?>
                            <option value="<?= $user['id'] ?>">
                                <?= htmlspecialchars($user['name']) ?> (<?= $user['role'] ?>)
                            </option>
                        <?php endforeach; ?>
                    </select>
                </div>

                <div class="mb-4">
                    <label for="pin" class="form-label">PIN</label>
                    <input type="password" class="form-control form-control-lg" name="pin" id="pin" maxlength="4" required placeholder="****" style="text-align: center; letter-spacing: 5px;">
                </div>

                <button type="submit" class="btn btn-primary w-100 btn-lg">Ingresar</button>
            </form>
        </div>
    </div>
</body>
</html>
