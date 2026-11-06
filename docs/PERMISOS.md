# Permisos y alcance

La app usa la carpeta del juego elegida en Resumen, los recursos de su paquete y su carpeta de datos en ~/Library/Application Support/DMC3 Patch. No busca botellas de CrossOver, no lee ni modifica sus registros y no ejecuta Wine, Steam o el juego.

- **Carpeta del juego:** videos, ejecutables compatibles, bibliotecas y recursos del mod. Las partidas de SavesDir se leen para crear un respaldo y no se sobrescriben.
- **Paquete de la app:** herramientas, fuentes, documentación y licencias. La edición local incluye Crimson comprimido. Se leen sin modificar el paquete.
- **Application Support/DMC3 Patch:** preferencias, selección, preparaciones, informes y respaldos. Las instalaciones se separan por carpeta.

El perfil actual carga el mod desde archivos locales. No necesita cambios de DLL en `user.reg`. Actualizar una instalación anterior conserva los metadatos de su versión previa como respaldo y no accede al entorno anterior.

La app no requiere administrador, accesibilidad, automatización de otras apps, cámara, micrófono, grabación de pantalla ni acceso completo al disco. Si macOS pide acceso a un disco extraíble o a la carpeta elegida, corresponde a la ubicación seleccionada. FFmpeg no incluye protocolos de red. Al pulsar Instalar en Crimson, la edición pública descarga el paquete oficial de GitHub y lo prepara en su carpeta temporal. Las búsquedas en Documentos personales y los enlaces de SavesDir hacia otras ubicaciones no se utilizan.

Esta versión no usa App Sandbox: las validaciones de rutas no son un aislamiento por carpeta impuesto por el sistema. La carta de bienvenida guarda su estado en la misma carpeta de datos de la app.

Fuente de Apple: [acceso a archivos en macOS](https://support.apple.com/en-ca/guide/security/secddd1d86a6/web).
