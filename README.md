# DMC3 Patch para macOS

**Parche de cinemáticas para Devil May Cry 3 de la HD Collection en Steam con CrossOver.**

DMC3 Patch está pensado para quienes juegan en una Mac con Apple Silicon y ven una pantalla negra durante las cinemáticas de DMC3. Es un proyecto comunitario de código abierto, desarrollado con ayuda de inteligencia artificial. Funciona en macOS 13 o posterior y requiere una copia instalada del juego.

## Qué incluye

- Convierte las cinemáticas de DMC3 a H.264/AAC con FFmpeg. La conversión se hace en tu Mac a partir de los archivos del juego.
- Guarda los originales y permite analizar, instalar o remover el parche.
- Reconoce instalaciones compatibles aunque el ejecutable de DMC3 tenga un nombre personalizado.
- Incluye una guía de bienvenida en español e inglés y muestra las rutas de tus datos y respaldos.

También podés instalar Crimson 0.5a de forma opcional. [Guía de instalación de Crimson](#instalar-el-mod-crimson).

## Cómo usarlo

1. Descargá `DMC3-Patch-0.10.7-arm64.zip` desde [Releases](https://github.com/jbuilder3/dmc3-patch-macos/releases/tag/v0.10.7). Descomprimilo y abrí **DMC3 Patch.app**. La app tiene firma ad hoc y macOS puede pedir autorización para abrirla. [Guía de Apple para abrir apps en la Mac](https://support.apple.com/es-mx/102445).
2. En Steam, dentro de CrossOver, buscá **Devil May Cry HD Collection** y usá **Administrar → Ver archivos locales** para ubicar el juego. Cerrá DMC3 y el launcher antes de instalar el parche.
3. En DMC3 Patch, abrí **Resumen → Elegir carpeta del juego** y seleccioná la carpeta que contiene el ejecutable de DMC3 y `data/dmc3`.
4. Pulsá **Analizar** para comprobar el estado del juego. Si corresponde, pulsá **Instalar** y esperá a que termine la conversión.
5. Volvé a abrir el juego desde Steam en CrossOver.

Para recuperar los videos originales, cerrá el juego y usá **Resumen → Remover**. En **Cómo usar → Datos y respaldos** podés ver las rutas exactas y abrir en Finder la carpeta `~/Library/Application Support/DMC3 Patch`. Conservá los respaldos mientras quieras poder restaurar el juego.

## Instalar el mod Crimson

1. Descargá el paquete completo de **Crimson 0.5a** y guardalo como ZIP o RAR. En Nexus Mods se llama **ZIP PACK - v0.5a Build**. En GitHub se llama **Crimson-0.5a-pack.rar**. [Nexus Mods](https://www.nexusmods.com/devilmaycryhdcollection/mods/272?tab=files) · [Crimson 0.5a en GitHub](https://github.com/berthrage/DMC3-Crimson/releases/tag/V0.5a).
2. En DMC3 Patch, usá **Resumen → Elegir carpeta del juego** y seleccioná la carpeta que contiene el ejecutable de DMC3 y `data/dmc3`. Cerrá el juego y el launcher. Esperá a que Steam muestre **Jugar**.
3. Abrí **Crimson → Elegir ZIP o RAR de Crimson** y seleccioná el archivo comprimido, incluso si está en un disco externo. Cuando aparezca **Archivo listo**, pulsá **Analizar**.
4. Pulsá **Instalar** y esperá a que la app muestre **Crimson instalado**. Después abrí el juego desde Steam en CrossOver.

Si **Instalar** está desactivado, revisá el resultado de **Analizar**. Si aparece **Crimson sin registro de instalación**, elegí una copia limpia del juego. Para retirar el mod, cerrá la colección y pulsá **Crimson → Quitar**. La app restaura los archivos respaldados durante la instalación.

También encontrás estos pasos dentro de la app en **Cómo usar → Instalar Crimson**.

## Compilar el código

En una Mac con Apple Silicon, instalá las Command Line Tools de Xcode y Python 3. Desde la raíz del repositorio, ejecutá `./build.sh --public`.

La app se guarda en `.build/DMC3 Patch.app`. El código de DMC3 Patch está bajo licencia MIT. FFmpeg y los demás componentes conservan sus licencias. El archivo con el código fuente de FFmpeg está en `tools/downloads` y podés reconstruirlo con `tools/build-ffmpeg.sh`. [Licencia MIT](LICENSE) · [Avisos de terceros](docs/THIRD-PARTY.md).

## Agradecimientos

- A **Mathias Kowoll** por MacGameFix y a **Jfishin** por winevideo. Sus proyectos fueron referencias para investigar los problemas de reproducción en CrossOver. [MacGameFix](https://github.com/MathiasKowoll/MacGameFix) · [winevideo](https://github.com/Jfishin/winevideo)
- A **Kyle P. Davis** y a quienes documentaron los fallos de cinemáticas en Proton. Su trabajo ayudó a orientar la investigación sobre la conversión de los videos. [Script de recodificación](https://gist.github.com/KylePDavis/6816e226ce98552fdf51a77e7404784a) · [Reporte en Proton](https://github.com/ValveSoftware/Proton/issues/4059)
- Al **equipo de FFmpeg** por las herramientas que convierten y verifican los videos. [FFmpeg](https://ffmpeg.org/)
- A **Berthrage y C-Team** por Crimson, y a **serpentiem** por DDMK. [DMC3 Crimson](https://github.com/berthrage/DMC3-Crimson) · [DDMK](https://github.com/serpentiem/ddmk)

Devil May Cry pertenece a Capcom. [Créditos completos](docs/CREDITOS.md).
