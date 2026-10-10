# Versión web — 8 de octubre de 2026 (reexportada el 10 de octubre como 0.12.0-dev)

Paquete: builds/AscuaInfinita-Web-0.12.0-dev.zip (36.779.868 bytes), con `index.html` en la raíz.
SHA256: 1c1bde763270ec6bef395f0d817d9345220b16d1b32b22833b6c436ac2b37304

Exportación de un solo hilo (plantilla oficial `web_nothreads_release` de Godot 4.7.2, renderizador Compatibility sobre WebGL 2). No necesita cabeceras COOP/COEP ni la opción «SharedArrayBuffer» de itch.io.

## Reproducir

```powershell
powershell -ExecutionPolicy Bypass -File tools/export_web.ps1
```

Usa el archivo de plantillas ya descargado por `export_windows.ps1` (o lo descarga y verifica su SHA256), extrae solo la plantilla web, exporta a `builds/web/` y crea el ZIP. El nombre toma la versión de `project.godot`.

Para probarla en local hace falta un servidor (los navegadores no cargan WebAssembly desde `file://`):

```powershell
python -m http.server 8060 --directory builds/web
```

y abrir http://localhost:8060.

## Publicar en itch.io

1. Crea el proyecto en itch.io con **Kind of project: HTML**.
2. Sube `AscuaInfinita-Web-<versión>.zip` y marca **This file will be played in the browser**.
3. Configura las dimensiones del visor en **1280 × 800** y activa **Mobile friendly: no** y **Fullscreen button**.
4. No hace falta activar SharedArrayBuffer.

La subida la hace el propietario de la cuenta. También se puede usar `butler` de itch.io con su clave de API, que no debe guardarse en el repositorio.

## Diferencias con la versión de escritorio

- **Guardado:** la partida se guarda en el almacenamiento del navegador (IndexedDB, `/userfs/godot/app_userdata/Ascua Infinita/`) para ese dominio. Borrar los datos del sitio la elimina, y no se comparte con la versión de Windows.
- **Botones de salir:** el título y la pausa no muestran Salir ni Guardar y salir; el guardado es automático.
- **Sonido:** los navegadores activan el sonido tras la primera interacción.
- **Idioma:** en Automático sigue el idioma del navegador: español si es español, inglés en otro caso. Se cambia en Opciones → Idioma.

## Validación realizada

0.12.0-dev, en el navegador integrado a 1280 × 800:
- Título con v0.12.0-dev en español (idioma del navegador), sin errores en la consola y sin botón Salir.
- Opciones → Idioma → English cambia todo el juego sin recargar.
- Expedición y combate en inglés: HUD, enemigo, forja, Destello y Parada.
- El guardado aparece en IndexedDB como JSON válido (versión 3, idioma «auto», retos del día).
- Tras recargar la página, el título sale en inglés: el idioma elegido se conserva.

0.5.0-dev: arranque y guardado comprobados; la partida en movimiento no se pudo ver porque el panel estaba oculto.
