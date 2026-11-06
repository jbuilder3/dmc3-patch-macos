# Herramientas y referencias

## FFmpeg 8.0.1

- Fuente oficial: https://ffmpeg.org/releases/ffmpeg-8.0.1.tar.xz
- SHA-256 del archivo descargado: `05ee0b03119b45c0bdb4df654b96802e909e0a752f72e4fe3794f487229e5a41`
- Licencia de esta compilación: LGPL 2.1 o posterior. No incluye componentes GPL ni nonfree.
- Fuente completa incluida en el archivo original `tools/downloads/ffmpeg-8.0.1.tar.xz`.
- La configuración está en `tools/build-ffmpeg.sh`. El script genera los registros en `.build`.
- Los ejecutables se compilan localmente para Apple Silicon. No se instala Homebrew ni paquetes globales.
- Objetivo de despliegue de los ejecutables: macOS 13.0 en Apple Silicon.
- FFmpeg y FFprobe comparten seis bibliotecas dinámicas locales en `tools/bin/lib`, también incluidas dentro de la app. No buscan bibliotecas en instalaciones globales.
- Se enlaza con las bibliotecas de sistema de Apple, incluyendo VideoToolbox. La compilación compacta usa `--enable-small`; conserva los decodificadores, codificadores y filtros del parche.
- Las bibliotecas LGPL se pueden sustituir por versiones compatibles con la misma ABI. Se conservan la fuente completa y `tools/build-ffmpeg.sh` para reconstruirlas. La firma ad hoc se aplica de nuevo después de reemplazarlas.

## Referencias consultadas, sin incorporar código

- ValveSoftware/Proton, reporte 4059: https://github.com/ValveSoftware/Proton/issues/4059
- KylePDavis, script de recodificación de la edición WMV: https://gist.github.com/KylePDavis/6816e226ce98552fdf51a77e7404784a
- MacGameFix, limitaciones WebM/VP9 de CrossOver 26.3: https://github.com/MathiasKowoll/MacGameFix
- winevideo, alternativa que modifica una copia de CrossOver y la botella: https://github.com/Jfishin/winevideo

La app implementa su propio proceso local. La edición para GitHub convierte los videos que el usuario ya tiene instalados.
