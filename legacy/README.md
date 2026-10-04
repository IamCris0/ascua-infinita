# Recursos de la versión 0.1.0

Sprites SVG de 32 × 32 px, sonidos WAV y herramientas de la primera versión. Ya no los usa el juego: la versión 0.2.0 dibuja a los personajes con el arte de Gemini (`assets/art/`) y usa el audio de `assets/audio/sfx` y `assets/audio/music`. Se conservan como referencia; Godot ignora esta carpeta (`.gdignore`).

- `sprites/`: portador, gelatina, lucero, centinela y jefe en SVG.
- `audio/`: hit, critical, coin, relic, fall y pulse.
- `tools/create_assets.gd`: generador de esos SVG y WAV (y del icono `assets/icon.svg`, que sigue en uso).
- `tools/build_gemini_atlas.gd`: primer intento de atlas de Gemini, sustituido por `tools/sprites/build_art.py`.
- `respaldo_v0.1.0_textos.tgz`: copia de los scripts, pruebas, documentos y capturas tal como estaban antes de la actualización a 0.2.0 (incluye los cambios que aún no estaban en git).
