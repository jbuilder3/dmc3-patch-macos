# Créditos de DMC3 Patch

Los autores originales conservan el crédito de sus componentes. Esta app es una integración local para macOS. Devil May Cry pertenece a Capcom.

El emblema de la edición local compone las imágenes de Rebellion y Yamato de la rueda de armas de DMC3 Crimson 0.5a. Devil May Cry y los diseños de las armas pertenecen a Capcom. [DMC3 Crimson](https://github.com/berthrage/DMC3-Crimson/tree/V0.5a).

## Crimson y componentes del mod

### DMC3 Crimson 0.5a

Berthrage y C-Team. Mod original. Equipo acreditado: Berthrage, Siyan, Darkness, deepdarkkapustka, Charlie, The Hitchhiker, RaccMoon, Lenam Lorbington, AirDragon, ZippoIG y Vainiuss1.

Fuente: [DMC3 Crimson 0.5a](https://www.nexusmods.com/devilmaycryhdcollection/mods/272?tab=description).

### Texturas restauradas de PS2

Spritzkrieg. Restauración de texturas utilizada por Crimson, según los créditos de sus autores.

Fuente: [Texturas restauradas de PS2](https://www.nexusmods.com/devilmaycryhdcollection/mods/272?tab=description).

### DDMK

serpentiem. Base de funciones y modificaciones incorporadas por Crimson. Licencia zlib del paquete.

Fuente: [DDMK](https://github.com/serpentiem/ddmk).

### Compatibilidad de ejecutables

ProjectXsent / colaboradores de DDMK. Archivos de compatibilidad hdc_patches_2026. La adaptación local usa crimson_api.dll para conservar la API compartida de Steam.

Fuente: [Compatibilidad de ejecutables](https://github.com/ProjectXsent/ddmk/releases/tag/patch-files).

### DMCHDFix

Lyall. Ajustes de resolución y relación de aspecto. Se conserva su licencia MIT.

Fuente: [DMCHDFix](https://github.com/Lyall/DMCHDFix).

### Ultimate ASI Loader

ThirteenAG y colaboradores. Cargador d3d11.dll incluido con Crimson para cargar DMCHDFix.asi.

Fuente: [Ultimate ASI Loader](https://github.com/ThirteenAG/Ultimate-ASI-Loader).

### Bibliotecas del paquete

Autores y colaboradores acreditados en LICENSE.txt. SDL, GLM / G-Truc Creation, Effekseer Project, Dear ImGui / Omar Cornut, libzip / Dieter Baron y Thomas Klausner, RapidJSON / Tencent y Milo Yip, stb / Sean Barrett, zlib / Jean-loup Gailly y Mark Adler; también SDL_mixer, mpg123 y Json.NET / James Newton-King. Los avisos originales del paquete se conservan completos.

Fuente: [Bibliotecas del paquete](https://github.com/berthrage/DMC3-Crimson/tree/V0.5a).

## Herramientas de la app

### FFmpeg y FFprobe 8.0.1

Equipo y colaboradores de FFmpeg. Conversión y análisis de cinemáticas. Compilación local bajo LGPL 2.1 o posterior; fuentes y configuración conservadas en el proyecto.

Fuente: [FFmpeg y FFprobe 8.0.1](https://ffmpeg.org/).

### xdelta3 3.2.2

Josh MacDonald y colaboradores. Herramienta de preparación de los archivos compatibles. Apache 2.0. Se usa al preparar el paquete; no se necesita para jugar.

Fuente: [xdelta3 3.2.2](https://github.com/jmacd/xdelta).

### App e integración para Mac

Desarrollo local de este proyecto. Interfaz nativa en Swift y AppKit, motor de instalación y restauración, conversión compatible y guía en español. AppKit, CryptoKit y VideoToolbox son tecnologías de Apple.

Fuente: [App e integración para Mac](https://developer.apple.com/documentation/appkit).

## Referencias consultadas

### MacGameFix

Mathias Kowoll. Referencia para investigar los problemas WebM en CrossOver.

Fuente: [MacGameFix](https://github.com/MathiasKowoll/MacGameFix).

### winevideo

Jfishin. Referencia para analizar alternativas de reproducción de video.

Fuente: [winevideo](https://github.com/Jfishin/winevideo).

### Reportes y conversión de cinemáticas

Comunidad de Valve / Proton y Kyle P. Davis. Reporte Proton 4059 y script de recodificación de KylePDavis como referencias del diagnóstico. El motor de esta app se desarrolló localmente.

Fuente: [Reportes y conversión de cinemáticas](https://github.com/ValveSoftware/Proton/issues/4059).

## Fuentes y avisos completos

- Código de Crimson: [versión V0.5a](https://github.com/berthrage/DMC3-Crimson/tree/V0.5a).
- Script de KylePDavis: [recodificación WMV](https://gist.github.com/KylePDavis/6816e226ce98552fdf51a77e7404784a).
- Licencias originales del mod: `docs/Crimson-LICENSE.txt`, también incluidas en `Resources/licenses`.
- FFmpeg: `docs/COPYING.LGPLv2.1` y `docs/THIRD-PARTY.md`.
- Procedencia del mod y herramientas: `docs/CRIMSON-THIRD-PARTY.md`.

## Carga local y CrossOver

CrossOver es de CodeWeavers y se instala por separado. Esta app no lee ni modifica sus botellas. El perfil local adapta metadatos PE de los ejecutables compatibles y de DMCHDFix, con un símbolo de carga local; su código y las licencias originales se conservan. El inyector original de Crimson se instala con el nombre dmcload.dll. El proxy Ultimate ASI Loader del paquete anterior ya no se utiliza.

Se consultó la [implementación del cargador de Wine](https://github.com/wine-mirror/wine/blob/master/dlls/ntdll/loader.c) como referencia de carga de dependencias; no se incorporó código de Wine.

## Adaptación de ejecutables renombrados

DMC3 Patch adapta los cargadores originales de Crimson (Berthrage y C-Team) y DMCHDFix (Lyall) para reconocer la imagen compatible sin depender de su nombre. Se conservan las licencias y los autores originales. El código de adaptación y su enlace COFF se desarrollaron en este proyecto. Las pruebas de código x64 usan Unicorn 2.1.4, instalado en el entorno de desarrollo desde PyPI; no se distribuye ni se requiere para jugar.
