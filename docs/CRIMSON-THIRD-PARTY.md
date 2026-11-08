# Crimson: procedencia y componentes

- Crimson 0.5a, Berthrage y C-Team: https://www.nexusmods.com/devilmaycryhdcollection/mods/272
- Fuente de la versión: https://github.com/berthrage/DMC3-Crimson/tree/V0.5a
- Licencias de Crimson, DDMK y bibliotecas en `docs/Crimson-LICENSE.txt`.
- El usuario selecciona un ZIP o RAR de Crimson 0.5a. El instalador lee el archivo local con libarchive de macOS y verifica los archivos preparados con el manifiesto de DMC3 Patch antes de escribir en el juego. [Release oficial de Crimson](https://github.com/berthrage/DMC3-Crimson/releases/tag/V0.5a).
- Compatibilidad Steam 2026: https://github.com/ProjectXsent/ddmk/releases/tag/patch-files
- El instalador usa xdelta3decode 3.2.2 con los deltas de compatibilidad en `mods/crimson/compat`. Se compila para Apple Silicon y macOS 13 a partir del [código de xdelta3](https://github.com/jmacd/xdelta/releases/tag/v3.2.2), incluido en `tools/downloads`. [Licencia Apache 2.0](Xdelta-LICENSE.txt). Para reconstruir el decodificador, usá el objetivo xdelta3decode de CMake con CMAKE_OSX_DEPLOYMENT_TARGET=13.0.
- La guía en español y la sección de instalación son parte de DMC3 Patch; no se tradujeron ni recompilaron los menús internos de Crimson.

