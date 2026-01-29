<?php
// backend/tools.php
require_once 'includes/auth.php';
require_once 'includes/header.php';

requireLogin();
if (!isAdmin()) {
    die("Acceso denegado.");
}
?>

<div class="container mt-4">
    <div class="d-flex justify-content-between align-items-center mb-4">
        <h2><i class="bi bi-tools"></i> Herramientas de Mantenimiento</h2>
        <a href="settings.php" class="btn btn-outline-secondary">
            <i class="bi bi-arrow-left"></i> Volver a Configuración
        </a>
    </div>

    <div class="row g-4">
        <!-- Restaurar desde CSV -->
        <div class="col-md-6 col-lg-4">
            <div class="card h-100 shadow-sm border-primary">
                <div class="card-body text-center">
                    <div class="display-4 text-primary mb-3">
                        <i class="bi bi-file-earmark-spreadsheet"></i>
                    </div>
                    <h5 class="card-title">Restaurar desde CSV</h5>
                    <p class="card-text text-muted">
                        Recupera fechas de salida perdidas usando el archivo original "Formato_Registro_Estacionamiento_y_Pension.csv".
                    </p>
                    <a href="restore_from_csv.php" class="btn btn-primary w-100 stretched-link">
                        Restaurar Datos
                    </a>
                </div>
            </div>
        </div>

        <!-- Restauración Manual Rápida -->
        <div class="col-md-6 col-lg-4">
            <div class="card h-100 shadow-sm border-info">
                <div class="card-body text-center">
                    <div class="display-4 text-info mb-3">
                        <i class="bi bi-clock-history"></i>
                    </div>
                    <h5 class="card-title">Restauración Manual</h5>
                    <p class="card-text text-muted">
                        Herramienta rápida para asignar salidas manualmente a los vehículos que quedaron "En Sitio" por error.
                    </p>
                    <a href="undo_fix.php" class="btn btn-info text-white w-100 stretched-link">
                        Corregir Manualmente
                    </a>
                </div>
            </div>
        </div>

        <!-- Corregir Fechas Futuras -->
        <div class="col-md-6 col-lg-4">
            <div class="card h-100 shadow-sm border-warning">
                <div class="card-body text-center">
                    <div class="display-4 text-warning mb-3">
                        <i class="bi bi-calendar-x"></i>
                    </div>
                    <h5 class="card-title">Corregir Fechas 2050</h5>
                    <p class="card-text text-muted">
                        Detecta y elimina fechas de salida imposibles (ej. año 2050) que inflan las estadísticas.
                    </p>
                    <a href="fix_dates.php" class="btn btn-warning text-dark w-100 stretched-link">
                        Escanear Fechas
                    </a>
                </div>
            </div>
        </div>

        <!-- Eliminar Duplicados -->
        <div class="col-md-6 col-lg-4">
            <div class="card h-100 shadow-sm border-danger">
                <div class="card-body text-center">
                    <div class="display-4 text-danger mb-3">
                        <i class="bi bi-files"></i>
                    </div>
                    <h5 class="card-title">Eliminar Duplicados</h5>
                    <p class="card-text text-muted">
                        Busca y elimina registros idénticos duplicados en la base de datos para limpiar el historial.
                    </p>
                    <a href="fix_duplicates.php" class="btn btn-danger w-100 stretched-link">
                        Buscar Duplicados
                    </a>
                </div>
            </div>
        </div>

        <!-- Respaldo SQL -->
        <div class="col-md-6 col-lg-4">
            <div class="card h-100 shadow-sm border-secondary">
                <div class="card-body text-center">
                    <div class="display-4 text-secondary mb-3">
                        <i class="bi bi-database-down"></i>
                    </div>
                    <h5 class="card-title">Respaldo SQL</h5>
                    <p class="card-text text-muted">
                        Descarga una copia completa de la base de datos actual para seguridad.
                    </p>
                    <a href="backup.php" class="btn btn-secondary w-100 stretched-link">
                        Descargar Backup
                    </a>
                </div>
            </div>
        </div>
    </div>
</div>
