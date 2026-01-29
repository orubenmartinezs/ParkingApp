# Diccionario de Datos - Sistema de Estacionamiento

Este documento describe la estructura de la base de datos utilizada en el sistema de control de estacionamiento (Backend MySQL y App Local SQLite).

## Notas Generales

*   **Motor de Base de Datos**: MySQL (Backend) / SQLite (App Móvil).
*   **Juego de Caracteres**: `utf8mb4_unicode_ci`.
*   **Manejo de Fechas**: Las fechas y horas operativas (`entry_time`, `exit_time`, `payment_date`) se almacenan como `BIGINT` representando **milisegundos** desde la época Unix (Epoch), para garantizar compatibilidad total con Dart/Flutter.
    *   *Nota*: Las columnas de auditoría `created_at` y `updated_at` usan el tipo `TIMESTAMP` nativo de MySQL.
*   **Zona Horaria**: La lógica del backend fuerza `America/Mexico_City`.
*   **Sincronización**:
    *   La columna `is_synced` en la App indica si un registro ha sido enviado al servidor (`1` = Sí, `0` = No/Pendiente).
    *   La App utiliza una estrategia de "Poda" (Pruning) para eliminar localmente registros que el servidor ya no reporta (ej. datos antiguos).

---

## Estructura de Tablas

### 1. `users` (Usuarios)
Usuarios con acceso al sistema (Administradores y Operadores).

| Columna | Tipo (MySQL) | Descripción |
| :--- | :--- | :--- |
| `id` | `VARCHAR(36)` | **PK**. UUID único del usuario. |
| `name` | `VARCHAR(255)` | Nombre completo. |
| `role` | `VARCHAR(50)` | Rol: `ADMIN` o `STAFF`. |
| `pin` | `VARCHAR(20)` | PIN de acceso numérico. |
| `is_active` | `TINYINT(1)` | `1` = Activo, `0` = Inactivo (Baja lógica). |
| `created_at` | `TIMESTAMP` | Fecha de creación del registro. |
| `updated_at` | `TIMESTAMP` | Última actualización del registro. |

### 2. `entry_types` (Tipos de Ingreso)
Catálogo de modalidades de entrada (ej. "Normal", "Pensión Nocturna").

| Columna | Tipo (MySQL) | Descripción |
| :--- | :--- | :--- |
| `id` | `VARCHAR(36)` | **PK**. UUID. |
| `name` | `VARCHAR(255)` | Nombre descriptivo (ej. "Por Hora"). |
| `is_active` | `TINYINT(1)` | Estado del tipo de ingreso. |
| `default_tariff_id`| `VARCHAR(36)` | **FK**. ID de tarifa por defecto (opcional). |
| `created_at` | `TIMESTAMP` | Auditoría. |
| `updated_at` | `TIMESTAMP` | Auditoría. |

### 3. `tariff_types` (Tipos de Tarifa)
Reglas de cobro aplicables.

| Columna | Tipo (MySQL) | Descripción |
| :--- | :--- | :--- |
| `id` | `VARCHAR(36)` | **PK**. UUID. |
| `name` | `VARCHAR(255)` | Nombre (ej. "Tarifa Estándar"). |
| `is_active` | `TINYINT(1)` | Estado. |
| `created_at` | `TIMESTAMP` | Auditoría. |
| `updated_at` | `TIMESTAMP` | Auditoría. |

### 4. `pension_subscribers` (Suscriptores de Pensión)
Clientes con contratos de pensión mensual.

| Columna | Tipo (MySQL) | Descripción |
| :--- | :--- | :--- |
| `id` | `VARCHAR(36)` | **PK**. UUID. |
| `folio` | `INT` | Número de folio secuencial para control administrativo. |
| `plate` | `VARCHAR(20)` | Placa del vehículo (o identificador principal). |
| `entry_type_id` | `VARCHAR(36)` | **FK**. Relación con `entry_types`. <br>⚠️ **Diferencia Local**: En SQLite, la App usa una columna `entry_type` (TEXT) con el *nombre*. El `database_helper.dart` mapea `entry_type_id` -> `entry_type` (Nombre) al sincronizar. |
| `monthly_fee` | `DECIMAL(10,2)`| Costo mensual acordado. |
| `name` | `VARCHAR(255)` | Nombre del cliente. |
| `notes` | `TEXT` | Observaciones. |
| `entry_date` | `BIGINT` | Fecha de inicio de contrato (ms). |
| `paid_until` | `BIGINT` | Fecha hasta la cual está pagado (ms). |
| `is_active` | `TINYINT(1)` | `1` = Activo, `0` = Cancelado/Baja. |
| `created_at` | `TIMESTAMP` | Auditoría. |
| `updated_at` | `TIMESTAMP` | Auditoría. |

### 5. `pension_payments` (Pagos de Pensión)
Historial de pagos realizados por los suscriptores.

| Columna | Tipo (MySQL) | Descripción |
| :--- | :--- | :--- |
| `id` | `VARCHAR(36)` | **PK**. UUID. |
| `subscriber_id` | `VARCHAR(36)` | **FK**. Relación con `pension_subscribers`. |
| `amount` | `DECIMAL(10,2)`| Monto pagado. |
| `payment_date` | `BIGINT` | Fecha real del pago (ms). |
| `coverage_start_date`| `BIGINT` | Inicio del periodo cubierto. |
| `coverage_end_date` | `BIGINT` | Fin del periodo cubierto. |
| `notes` | `TEXT` | Notas adicionales. |
| `is_synced` | `TINYINT(1)` | Estado de sincronización. |
| `created_at` | `TIMESTAMP` | Auditoría. |
| `updated_at` | `TIMESTAMP` | Auditoría. |

### 6. `parking_records` (Registros de Estacionamiento)
Tabla central de operación (Entradas y Salidas de vehículos).

| Columna | Tipo (MySQL) | Descripción |
| :--- | :--- | :--- |
| `id` | `VARCHAR(36)` | **PK**. UUID. |
| `folio` | `INT` | Folio impreso en el ticket. |
| `plate` | `VARCHAR(20)` | Placa del vehículo. |
| `description` | `TEXT` | Descripción visual (ej. "Sedan Rojo"). |
| `entry_type_id` | `VARCHAR(36)` | **FK**. Tipo de ingreso seleccionado. |
| `entry_user_id` | `VARCHAR(36)` | ID del usuario que registró la entrada. |
| `entry_time` | `BIGINT` | Fecha/Hora de entrada (ms). |
| `exit_time` | `BIGINT` | Fecha/Hora de salida (ms). `NULL` si sigue dentro. |
| `cost` | `DECIMAL(10,2)`| Costo calculado/cobrado. |
| `amount_paid` | `DECIMAL(10,2)`| Monto efectivamente pagado. |
| `payment_status` | `VARCHAR(20)` | Estado: `PENDING`, `PAID`, etc. |
| `tariff_type_id` | `VARCHAR(36)` | **FK**. Tarifa aplicada. |
| `exit_user_id` | `VARCHAR(36)` | ID del usuario que registró la salida. |
| `pension_subscriber_id`| `VARCHAR(36)`| **FK**. Si es pensión, vincula al suscriptor. |
| `notes` | `TEXT` | Observaciones. |
| `is_synced` | `TINYINT(1)` | Estado de sincronización. |
| `created_at` | `TIMESTAMP` | Auditoría. |
| `updated_at` | `TIMESTAMP` | Auditoría. |

### 7. `expenses` (Gastos)
Registro de gastos operativos (Caja chica, insumos, etc.).

| Columna | Tipo (MySQL) | Descripción |
| :--- | :--- | :--- |
| `id` | `VARCHAR(36)` | **PK**. UUID. |
| `description` | `TEXT` | Descripción del gasto. |
| `amount` | `DECIMAL(10,2)`| Monto. |
| `category` | `VARCHAR(50)` | Nombre de la categoría (ej. "Limpieza"). |
| `expense_date` | `BIGINT` | Fecha del gasto (ms). |
| `user_id` | `VARCHAR(36)` | Usuario que registró el gasto. |
| `is_synced` | `TINYINT(1)` | Estado de sincronización. |

### 8. `expense_categories` (Categorías de Gastos)
Catálogo para tipificar gastos.

| Columna | Tipo (MySQL) | Descripción |
| :--- | :--- | :--- |
| `id` | `VARCHAR(36)` | **PK**. UUID. |
| `name` | `VARCHAR(255)` | Nombre de la categoría. |
| `description` | `TEXT` | Descripción opcional. |
| `is_active` | `TINYINT(1)` | Estado. |

### 9. `settings` (Configuración)
Configuraciones globales del sistema (Key-Value).

| Columna | Tipo (MySQL) | Descripción |
| :--- | :--- | :--- |
| `setting_key` | `VARCHAR(50)` | **PK**. Clave de configuración (ej. `company_name`). |
| `setting_value` | `TEXT` | Valor de la configuración. |

### 10. `sequences` (Secuencias)
Control de folios consecutivos (especialmente útil si no se usa AUTO_INCREMENT directo en IDs).

| Columna | Tipo (MySQL) | Descripción |
| :--- | :--- | :--- |
| `name` | `VARCHAR(50)` | **PK**. Nombre de la secuencia (ej. `parking_folio`). |
| `current_val` | `INT` | Último valor utilizado. |
