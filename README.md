# Sistema de Gestión de Parking

Sistema integral para la administración y control de estacionamientos y pensiones vehiculares. Este proyecto consta de una aplicación móvil robusta para la operación diaria y un backend centralizado para la sincronización y persistencia de datos.

## Estructura del Proyecto

El repositorio está organizado en dos componentes principales:

*   **`/app`**: Código fuente de la aplicación móvil desarrollada en **Flutter**. Diseñada para funcionar en tabletas Android con capacidades *offline-first*.
*   **`/backend`**: API RESTful desarrollada en **PHP** nativo y base de datos **MySQL**. Gestiona la sincronización de datos, autenticación y lógica de negocio centralizada.

## Características Principales

*   **Sincronización Bidireccional**: La app descarga configuraciones y suscriptores del servidor, y sube registros de movimientos (ingresos/salidas) y cortes de caja.
*   **Funcionamiento Offline**: La operación crítica (ingreso/salida de vehículos) no requiere internet continuo. Los datos se sincronizan cuando hay conexión.
*   **Gestión de Pensiones**: Control detallado de suscriptores, pagos mensuales y estados de cuenta.
*   **Interfaz Optimizada**: Diseño adaptado para tabletas, enfocado en la rapidez de captura y claridad visual.

## Requisitos Previos

*   **Git**: Para control de versiones.
*   **Flutter SDK**: Versión estable reciente (para compilar la app).
*   **Servidor Web**: Apache/Nginx con soporte para PHP 7.4+ y MySQL/MariaDB (para el backend).

## Instalación Rápida

1.  **Clonar el repositorio**:
    ```bash
    git clone <url-del-repositorio>
    cd Parking
    ```

2.  **Configurar Backend**:
    *   Navegar a la carpeta `backend/`.
    *   Seguir las instrucciones en [backend/README.md](backend/README.md) para importar la base de datos y configurar credenciales.

3.  **Compilar App**:
    *   Navegar a la carpeta `app/`.
    *   Seguir las instrucciones en [app/README.md](app/README.md) para instalar dependencias y generar el APK.

## Documentación Adicional

*   [Diccionario de Datos](backend/DATA_DICTIONARY.md): Detalles sobre el esquema de base de datos y mapeo de tipos.
