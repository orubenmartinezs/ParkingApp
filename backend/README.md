# Backend - Parking API

Este directorio contiene la lógica del lado del servidor, encargada de centralizar la información, autenticar usuarios y sincronizar datos con las aplicaciones móviles.

## Tecnología

*   **Lenguaje**: PHP (Nativo, sin frameworks pesados para maximizar compatibilidad y facilidad de despliegue).
*   **Base de Datos**: MySQL / MariaDB.
*   **Formato de Intercambio**: JSON.

## Estructura de Archivos

*   `api/`: Endpoints públicos consumidos por la app.
    *   `pull.php`: Endpoint principal para descarga de datos (catálogos, suscriptores, configuración).
    *   `push.php`: Endpoint para subida de transacciones (ingresos, salidas, movimientos de caja).
    *   `login.php`: Autenticación de usuarios (JWT o Token simple).
    *   `suggestions.php`: Autocompletado inteligente para la app.
*   `config.php` (No incluido en repo): Variables de entorno y configuración global.
*   `db.php` (No incluido en repo): Conexión a base de datos PDO.
*   `DATA_DICTIONARY.md`: Documentación detallada del esquema de la base de datos.

## Configuración e Instalación

### 1. Base de Datos
1.  Crear una base de datos en MySQL (ej. `parking_db`).
2.  Importar el esquema inicial (solicitar el script SQL más reciente al administrador del proyecto, ya que contiene la estructura de tablas como `users`, `pension_subscribers`, `tariffs`, etc.).

### 2. Credenciales (Archivos Ignorados)
Este proyecto no incluye las credenciales de base de datos en el repositorio por seguridad. Debes crear manualmente los siguientes archivos en la raíz de `backend/`:

**`config.php`**:
```php
<?php
// Definición de constantes globales
define('DB_HOST', 'localhost');
define('DB_NAME', 'nombre_base_datos');
define('DB_USER', 'usuario_db');
define('DB_PASS', 'password_db');
define('TIMEZONE', 'America/Mexico_City');
?>
```

**`db.php`**:
```php
<?php
require_once 'config.php';

try {
    $dsn = "mysql:host=" . DB_HOST . ";dbname=" . DB_NAME . ";charset=utf8mb4";
    $pdo = new PDO($dsn, DB_USER, DB_PASS, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        PDO::ATTR_EMULATE_PREPARES => false,
    ]);
} catch (PDOException $e) {
    // Manejo de error de conexión (en producción no mostrar detalles)
    die("Error de conexión a la base de datos");
}
?>
```

## Despliegue

El despliegue en producción se realiza típicamente vía **FTP** o **SFTP**.
*   Subir todo el contenido de la carpeta `backend/` al directorio público del servidor (ej. `public_html/api` o subdominio).
*   Asegurar que `config.php` y `db.php` tengan los permisos correctos (644) y no sean accesibles vía navegador si es posible (o moverlos fuera del root público e incluir la ruta correcta).

## Notas de Desarrollo
*   **Fechas**: El sistema opera explícitamente en la zona horaria `America/Mexico_City`.
*   **Sincronización**: `pull.php` está diseñado para devolver registros desde "ayer a medianoche" para asegurar continuidad en caso de diferencias horarias.
