<?php
// backend/restore_from_csv.php
require_once 'includes/auth.php';
require_once 'db.php';
require_once 'includes/helpers.php';
require_once 'includes/init_settings.php';

requireLogin();
if (!isAdmin()) {
    die("Acceso denegado.");
}

$pdo = getDB();
initSystemSettings($pdo);

$message = '';
$error = '';

// Handle Reset Database (Truncate or Partial)
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['reset_db'])) {
    $confirmation = trim($_POST['confirmation'] ?? '');
    $cleanMode = $_POST['clean_mode'] ?? 'partial';
    $keepDate = $_POST['keep_date'] ?? '';

    if ($confirmation === 'ELIMINAR') {
        try {
            if ($cleanMode === 'partial' && !empty($keepDate)) {
                // Keep records ON or AFTER this date. Delete everything BEFORE.
                // entry_time is stored as BIGINT (milliseconds)
                $cutoffTs = strtotime($keepDate . " 00:00:00") * 1000;
                
                $stmt = $pdo->prepare("DELETE FROM parking_records WHERE entry_time < ?");
                $stmt->execute([$cutoffTs]);
                $deleted = $stmt->rowCount();
                $message = "Limpieza parcial completada. Se eliminaron $deleted registros anteriores al " . date('d/m/Y', strtotime($keepDate)) . ".";
            } else {
                // Full Reset
                $pdo->exec("TRUNCATE TABLE parking_records");
                $message = "Base de datos de registros vaciada completamente.";
            }
        } catch (Exception $e) {
            $error = "Error en la limpieza: " . $e->getMessage();
        }
    } else {
        $error = "Confirmación incorrecta. Debe escribir 'ELIMINAR'.";
    }
}

// Helper: Parse YYYY-MM-DD HH:MM
function parseImportDate($dateStr) {
    if (empty($dateStr)) return null;
    // Try Y-m-d H:i first (template format)
    $d = DateTime::createFromFormat('Y-m-d H:i', $dateStr);
    if (!$d) {
        // Fallback to d/m/Y H:i
        $d = DateTime::createFromFormat('d/m/Y H:i', $dateStr);
    }
    if (!$d) {
         // Fallback to d/m/y H:i
         $d = DateTime::createFromFormat('d/m/y H:i', $dateStr);
    }
    return $d ? $d->getTimestamp() * 1000 : null;
}

// Load Maps for ID Lookup
$entryTypesMap = [];
$stmt = $pdo->query("SELECT name, id FROM entry_types");
while ($row = $stmt->fetch()) {
    $entryTypesMap[strtoupper($row['name'])] = $row['id'];
}

$tariffTypesMap = [];
$stmt = $pdo->query("SELECT name, id FROM tariff_types");
while ($row = $stmt->fetch()) {
    $tariffTypesMap[strtoupper($row['name'])] = $row['id'];
}

$pensionMap = []; // Folio -> ID
$stmt = $pdo->query("SELECT folio, id FROM pension_subscribers WHERE folio IS NOT NULL");
while ($row = $stmt->fetch()) {
    $pensionMap[$row['folio']] = $row['id'];
}

$usersMap = []; // Name -> ID
$stmt = $pdo->query("SELECT name, id FROM users");
while ($row = $stmt->fetch()) {
    $usersMap[strtoupper($row['name'])] = $row['id'];
}

if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['csv_file'])) {
    if ($_FILES['csv_file']['error'] === UPLOAD_ERR_OK) {
        $tmpName = $_FILES['csv_file']['tmp_name'];
        $insertedCount = 0;
        $rowNum = 0;
        
        if (($handle = fopen($tmpName, "r")) !== FALSE) {
            // Detect delimiter
            $firstLine = fgets($handle);
            $delimiter = (substr_count($firstLine, ';') > substr_count($firstLine, ',')) ? ';' : ',';
            rewind($handle);

            // Read header to detect format (optional, currently assuming template format)
            // Template: Placa, Descripcion, Tipo de Cliente, Tarifa, Entrada, Salida, Costo, Recibido Por, Entregado Por, Notas, Folio Pension
            fgetcsv($handle, 1000, $delimiter); // Skip header
            
            while (($data = fgetcsv($handle, 1000, $delimiter)) !== FALSE) {
                $rowNum++;
                // Index mapping based on template
                $plate = trim($data[0] ?? '');
                $description = trim($data[1] ?? '');
                $clientTypeName = trim($data[2] ?? '');
                $tariffName = trim($data[3] ?? '');
                $entryStr = trim($data[4] ?? '');
                $exitStr = trim($data[5] ?? '');
                $cost = floatval(str_replace(['$', ','], '', $data[6] ?? '0'));
                $receivedBy = trim($data[7] ?? '');
                $deliveredBy = trim($data[8] ?? '');
                $notes = trim($data[9] ?? '');
                $pensionFolio = trim($data[10] ?? '');
                
                if (empty($plate) || empty($entryStr)) continue;
                
                $entryTs = parseImportDate($entryStr);
                $exitTs = parseImportDate($exitStr);
                
                if (!$entryTs) continue;
                
                // Lookup IDs
                $entryTypeId = $entryTypesMap[strtoupper($clientTypeName)] ?? null;
                $tariffTypeId = $tariffTypesMap[strtoupper($tariffName)] ?? null;
                $pensionId = !empty($pensionFolio) ? ($pensionMap[$pensionFolio] ?? null) : null;
                
                $entryUserId = $usersMap[strtoupper($receivedBy)] ?? null;
                $exitUserId = $usersMap[strtoupper($deliveredBy)] ?? null;
                
                // UUID generation
                $id = sprintf('%04x%04x-%04x-%04x-%04x-%04x%04x%04x',
                    mt_rand(0, 0xffff), mt_rand(0, 0xffff),
                    mt_rand(0, 0xffff),
                    mt_rand(0, 0x0fff) | 0x4000,
                    mt_rand(0, 0x3fff) | 0x8000,
                    mt_rand(0, 0xffff), mt_rand(0, 0xffff), mt_rand(0, 0xffff)
                );
                
                try {
                    $sql = "INSERT INTO parking_records 
                        (id, plate, description, client_type, entry_type_id, entry_time, exit_time, cost, tariff, tariff_type_id, notes, pension_subscriber_id, entry_user_id, exit_user_id, is_synced)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)";
                    
                    $stmt = $pdo->prepare($sql);
                    $stmt->execute([
                        $id,
                        $plate,
                        $description,
                        $clientTypeName, // Store Name as well
                        $entryTypeId,
                        $entryTs,
                        $exitTs,
                        $cost,
                        $tariffName, // Store Name as well
                        $tariffTypeId,
                        $notes,
                        $pensionId,
                        $entryUserId,
                        $exitUserId
                    ]);
                    $insertedCount++;
                } catch (Exception $e) {
                    // Log error or continue
                    // $error .= "Error en fila $rowNum: " . $e->getMessage() . "<br>";
                }
            }
            fclose($handle);
            $message = "Importación completada. Se importaron $insertedCount registros nuevos.";
        }
    } else {
        $error = "Error al subir el archivo.";
    }
}


require_once 'includes/header.php';
?>

<div class="container mt-4">
    <div class="d-flex justify-content-between align-items-center mb-4">
        <h2><i class="bi bi-database-fill-gear"></i> Centro de Importación y Datos</h2>
        <a href="tools.php" class="btn btn-outline-secondary">
            <i class="bi bi-arrow-left"></i> Volver a Herramientas
        </a>
    </div>

    <?php if ($message): ?>
        <div class="alert alert-success"><?= htmlspecialchars($message) ?></div>
    <?php endif; ?>
    <?php if ($error): ?>
        <div class="alert alert-danger"><?= htmlspecialchars($error) ?></div>
    <?php endif; ?>

    <!-- 1. Download Template -->
    <div class="card shadow mb-4">
        <div class="card-header bg-light">
            <h5 class="mb-0">1. Descargar Plantilla</h5>
        </div>
        <div class="card-body">
            <p>Descarga la plantilla CSV actualizada con las columnas correctas (incluyendo Folio de Pensión y nombres de Tarifas).</p>
            <a href="download_template.php" class="btn btn-primary">
                <i class="bi bi-download"></i> Descargar Plantilla CSV
            </a>
        </div>
    </div>

    <!-- 2. Import Data -->
    <div class="card shadow mb-4">
        <div class="card-header bg-light">
            <h5 class="mb-0">2. Importar Registros</h5>
        </div>
        <div class="card-body">
            <p>Sube el archivo CSV completado. El sistema vinculará automáticamente:</p>
            <ul>
                <li><strong>Tipo de Cliente</strong> con la base de datos (Ej: '<?= htmlspecialchars($exType1) ?>', '<?= htmlspecialchars($exType2) ?>').</li>
                <li><strong>Tarifa</strong> con la base de datos (Ej: '<?= htmlspecialchars($exTariff) ?>').</li>
                <li><strong>Usuarios</strong> (Recibido/Entregado) con los usuarios del sistema.</li>
                <li><strong>Folio Pensión</strong> con el suscriptor correspondiente.</li>
            </ul>
            <form method="POST" enctype="multipart/form-data">
                <div class="input-group mb-3">
                    <input type="file" class="form-control" name="csv_file" accept=".csv" required>
                    <button class="btn btn-success" type="submit">
                        <i class="bi bi-upload"></i> Importar Datos
                    </button>
                </div>
            </form>
        </div>
    </div>

    <!-- 3. Danger Zone: Reset -->
    <div class="card shadow border-danger">
        <div class="card-header bg-danger text-white">
            <h5 class="mb-0"><i class="bi bi-exclamation-triangle"></i> Zona de Peligro: Limpieza de Datos</h5>
        </div>
        <div class="card-body">
            <p class="text-danger">
                <strong>ADVERTENCIA:</strong> Esta acción eliminará registros de la base de datos de forma permanente.
            </p>
            <form method="POST" onsubmit="return confirm('¿ESTÁS SEGURO? ESTA ACCIÓN NO SE PUEDE DESHACER.');">
                
                <div class="mb-3">
                    <label class="form-label fw-bold">Opciones de Limpieza:</label>
                    <div class="form-check">
                        <input class="form-check-input" type="radio" name="clean_mode" id="mode_partial" value="partial" checked onchange="toggleDateInput()">
                        <label class="form-check-label" for="mode_partial">
                            Eliminar antiguos (Conservar recientes)
                        </label>
                    </div>
                    <div class="form-check mb-2">
                        <input class="form-check-input" type="radio" name="clean_mode" id="mode_full" value="full" onchange="toggleDateInput()">
                        <label class="form-check-label" for="mode_full">
                            Eliminar TODO (Vaciar base de datos)
                        </label>
                    </div>
                </div>

                <div class="mb-3" id="date_input_container">
                    <label class="form-label">Conservar registros a partir del día:</label>
                    <input type="date" name="keep_date" class="form-control" value="<?= date('Y-m-d', strtotime('-1 day')) ?>">
                    <div class="form-text">Se eliminarán todos los registros ANTERIORES a esta fecha (00:00 hrs).</div>
                </div>

                <div class="mb-3">
                    <label class="form-label">Escribe <strong>ELIMINAR</strong> para confirmar:</label>
                    <input type="text" name="confirmation" class="form-control" required placeholder="ELIMINAR">
                </div>
                
                <button type="submit" name="reset_db" class="btn btn-danger w-100">
                    <i class="bi bi-trash"></i> Ejecutar Limpieza
                </button>
            </form>
        </div>
    </div>
</div>

<script>
function toggleDateInput() {
    const isPartial = document.getElementById('mode_partial').checked;
    const dateContainer = document.getElementById('date_input_container');
    if (isPartial) {
        dateContainer.style.display = 'block';
    } else {
        dateContainer.style.display = 'none';
    }
}
</script>


