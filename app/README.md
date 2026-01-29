# Parking App (Flutter)

Aplicación móvil desarrollada en Flutter para la gestión operativa de estacionamientos. Diseñada para ser utilizada en tabletas Android, permitiendo el control de ingresos, salidas, pensiones y finanzas con capacidades offline.

## Características

*   **Offline-First**: Uso de base de datos local **SQLite** como fuente de verdad inmediata. Sincronización en segundo plano cuando hay red.
*   **Impresión Térmica**: Integración con impresoras Bluetooth (ESC/POS) para tickets de entrada y comprobantes de pago.
*   **UI Adaptativa**: Diseño responsivo optimizado para pantallas de tabletas (layouts anchos, diálogos grandes).
*   **Gestión de Pensiones**: Módulo completo para administrar suscriptores, ver estados de cuenta y registrar pagos mensuales.

## Arquitectura

*   **Gestión de Estado**: `Provider`.
*   **Persistencia Local**: `sqflite`.
*   **Conectividad**: `http` para comunicación con API REST (PHP).
*   **Patrón de Diseño**: Service-Repository (parcialmente implementado en `DatabaseHelper` y `SyncService`).

## Configuración del Entorno

1.  Asegúrate de tener instalado el [Flutter SDK](https://docs.flutter.dev/get-started/install).
2.  Instalar dependencias del proyecto:
    ```bash
    flutter pub get
    ```

## Compilación y Despliegue

### Generar APK
Para generar el instalador para Android (optimizando tamaño por arquitectura):

```bash
flutter build apk --split-per-abi
```

Esto generará los archivos APK en `build/app/outputs/flutter-apk/`. Usualmente se utiliza `app-armeabi-v7a-release.apk` o `app-arm64-v8a-release.apk` dependiendo de la tableta.

### Instalación Manual (ADB)
Si tienes el dispositivo conectado por USB y depuración activada:

```bash
adb install -r build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk
```

## Estructura de Directorios Clave

*   `lib/models/`: Modelos de datos (POJOs) con métodos `toMap`/`fromMap` para SQLite y JSON.
*   `lib/screens/`: Pantallas de la aplicación (Home, Pensiones, Admin, Finanzas).
*   `lib/widgets/`: Componentes UI reutilizables.
*   `lib/database/`: Lógica de base de datos local (`DatabaseHelper`).
*   `lib/services/`: Lógica de negocio y comunicación externa (`SyncService`, `PrinterService`).

## Notas Importantes
*   **Sincronización**: La App prioriza los cambios locales no sincronizados (`is_synced = 0`). Al recibir datos del servidor, solo sobrescribe registros que no tengan cambios pendientes locales para evitar conflictos de edición.
*   **Permisos**: Requiere permisos de Bluetooth (para impresora) e Internet (para sincronización) en `AndroidManifest.xml`.
