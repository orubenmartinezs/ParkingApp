<?php
// fix_financial_data.php
require_once 'db.php';

header('Content-Type: text/plain; charset=utf-8');

$pdo = getDB();

echo "Iniciando Corrección de Datos Financieros...\n";
echo "----------------------------------------\n";

try {
    $pdo->beginTransaction();

    // 1. Backfill amount_paid from cost for completed records
    // Logic: If exit_time exists (completed), and cost > 0, and (amount_paid is NULL or 0)
    // We assume they paid the full cost in the past.
    
    echo "1. Analizando registros históricos completados sin 'amount_paid'...\n";

    // Count records to be updated
    $sqlCount = "SELECT COUNT(*) FROM parking_records 
                 WHERE exit_time IS NOT NULL 
                 AND cost > 0 
                 AND (amount_paid IS NULL OR amount_paid = 0)";
    
    $count = $pdo->query($sqlCount)->fetchColumn();
    
    if ($count > 0) {
        echo "   -> Encontrados $count registros para corregir.\n";
        
        $sqlUpdate = "UPDATE parking_records 
                      SET amount_paid = cost, 
                          payment_status = 'PAID' 
                      WHERE exit_time IS NOT NULL 
                      AND cost > 0 
                      AND (amount_paid IS NULL OR amount_paid = 0)";
        
        $stmt = $pdo->prepare($sqlUpdate);
        $stmt->execute();
        
        echo "   -> Actualizados $count registros. amount_paid = cost, payment_status = 'PAID'.\n";
    } else {
        echo "   -> No se encontraron registros pendientes de corrección.\n";
    }

    // 2. Fix pending records (no exit_time)
    // If they have no exit time, they shouldn't have cost usually, but if they prepay?
    // Let's leave them alone for now, unless cost > 0 and amount_paid = 0.

    // 3. Fix payment_status for records with amount_paid >= cost
    echo "\n2. Verificando consistencia de 'payment_status'...\n";
    
    $sqlFixStatus = "UPDATE parking_records 
                     SET payment_status = 'PAID' 
                     WHERE amount_paid >= cost 
                     AND cost > 0 
                     AND payment_status != 'PAID'";
    
    $stmtStatus = $pdo->prepare($sqlFixStatus);
    $stmtStatus->execute();
    $fixedStatus = $stmtStatus->rowCount();
    
    if ($fixedStatus > 0) {
        echo "   -> Corregido estatus a 'PAID' en $fixedStatus registros.\n";
    } else {
        echo "   -> Estatus de pagos consistente.\n";
    }

    $pdo->commit();
    echo "\n----------------------------------------\n";
    echo "Corrección completada con éxito.\n";

} catch (Exception $e) {
    $pdo->rollBack();
    echo "\nERROR: " . $e->getMessage() . "\n";
}
