<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}
require_once __DIR__ . '/auth.php';
$currentUser = getCurrentUser();
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Parking Control Admin</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css">
    <style>
        .navbar-brand { font-weight: bold; }
        .card-header { font-weight: 600; }
    </style>
</head>
<body class="bg-light">
    <nav class="navbar navbar-expand-lg navbar-dark bg-primary mb-4">
        <div class="container">
            <a class="navbar-brand" href="index.php"><i class="bi bi-car-front-fill me-2"></i>Parking Control</a>
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav me-auto">
                    <li class="nav-item">
                        <a class="nav-link <?= basename($_SERVER['PHP_SELF']) == 'index.php' ? 'active' : '' ?>" href="index.php">
                            <i class="bi bi-speedometer2 me-1"></i> Resumen
                        </a>
                    </li>
                    
                    <li class="nav-item dropdown">
                        <a class="nav-link dropdown-toggle <?= in_array(basename($_SERVER['PHP_SELF']), ['records.php', 'pensions.php']) ? 'active' : '' ?>" href="#" role="button" data-bs-toggle="dropdown">
                            <i class="bi bi-p-square me-1"></i> Operación
                        </a>
                        <ul class="dropdown-menu">
                            <li><a class="dropdown-item" href="records.php">Registros Estacionamiento</a></li>
                            <li><a class="dropdown-item" href="pensions.php">Clientes Pensiones</a></li>
                        </ul>
                    </li>

                    <li class="nav-item dropdown">
                        <a class="nav-link dropdown-toggle <?= in_array(basename($_SERVER['PHP_SELF']), ['reports.php', 'expenses.php', 'payments.php']) ? 'active' : '' ?>" href="#" role="button" data-bs-toggle="dropdown">
                            <i class="bi bi-cash-coin me-1"></i> Finanzas
                        </a>
                        <ul class="dropdown-menu">
                            <li><a class="dropdown-item" href="reports.php">Reportes Financieros</a></li>
                            <li><a class="dropdown-item" href="expenses.php">Gastos Operativos</a></li>
                            <li><a class="dropdown-item" href="expense_categories.php">Categorías de Gastos</a></li>
                            <li><hr class="dropdown-divider"></li>
                            <li><a class="dropdown-item" href="payments.php">Pagos de Pensiones</a></li>
                        </ul>
                    </li>

                    <?php if (isAdmin()): ?>
                    <li class="nav-item dropdown">
                        <a class="nav-link dropdown-toggle <?= in_array(basename($_SERVER['PHP_SELF']), ['admin.php', 'settings.php']) ? 'active' : '' ?>" href="#" role="button" data-bs-toggle="dropdown">
                            <i class="bi bi-gear me-1"></i> Sistema
                        </a>
                        <ul class="dropdown-menu">
                            <li><a class="dropdown-item" href="admin.php">Usuarios y Tarifas</a></li>
                            <li><a class="dropdown-item" href="settings.php">Configuración General</a></li>
                        </ul>
                    </li>
                    <?php endif; ?>
                </ul>
                <div class="d-flex align-items-center text-white">
                    <span class="me-3"><i class="bi bi-person-circle me-1"></i> <?= htmlspecialchars($currentUser['name']) ?></span>
                    <a href="logout.php" class="btn btn-sm btn-outline-light">Salir</a>
                </div>
            </div>
        </div>
    </nav>
    <div class="container">
