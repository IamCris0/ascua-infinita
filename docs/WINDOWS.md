# Versión Windows — 5 de octubre de 2026 (reexportada el 3 de noviembre como 0.13.0-dev)

Paquete: builds/AscuaInfinita-Windows-0.13.0-dev.zip (64.673.774 bytes).
SHA256: 7abe812b15f1f8e713d767259ffe9e5f8241d2ddc8d5208fc35a887e317d1a40

Extraer el ZIP completo y abrir AscuaInfinita.exe; AscuaInfinita.pck debe permanecer a su lado. Incluye LEEME y avisos de Godot, sus componentes y la fuente Jersey 10. El nombre del paquete toma la versión de project.godot. Versión web: WEB.md.

## Reproducir

Ejecutar tools/export_windows.ps1 con Godot 4.7.2 instalado o indicar -EnginePath. Descarga la plantilla oficial únicamente si falta, verifica su SHA256 y extrae la plantilla Windows x64 en .godot/export-templates. Importa y exporta con export_presets.cfg y crea el ZIP. No instala plantillas globales.

Referencias: [exportación de proyectos](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html) y [publicación oficial 4.7.2](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable).

## Validación realizada

- ZIP extraído en una carpeta independiente del proyecto, sin archivos de editor.
- Ejecutable release real: editor=false. Once hojas de personaje (incluye compañero y mercader), tres fondos, iconos del mapa, cofres y equipo, 40 sonidos, seis pistas, ambos manifiestos JSON y la traducción al inglés disponibles.
- Primer proceso escribe una partida de prueba; un segundo proceso recupera cámara 20, oro, canalización, resonancia, descubrimientos y sinergia.
- Arranque normal sin argumentos de verificación: código de salida 0, sin errores.
- Renderizado OpenGL con RTX 4050 revisado en windows-preview.png.
- Suite de interfaz: 34 comprobaciones aprobadas tras añadir el verificador.

Los modos --verify-build y --verify-build-reload usan build-check.json, nunca ascua_save.json. En esta revisión APPDATA apuntó a .godot/portable-qa para aislar completamente las partidas reales.
