# Recursos

| Carpeta | Contenido | Origen |
|---|---|---|
| `art/characters/` | Atlas del portador, gelatina, lucero, centinela, Rey sin Brasa y lucero compañero (verde menta) | Hojas de Gemini preparadas con `tools/sprites/build_art.py` |
| `art/relics/` | Siete iconos de reliquia | `10_reliquias.png` |
| `art/fx/` | Tajo, crítico, magia y brasas (3–4 fotogramas cada uno) | `11_efectos.png` |
| `art/ui/` | Botón de piedra (9 cortes), retrato del guardián, bastón, llave, faroles y cristal de ascua | `01_referencia_interfaz.png` |
| `art/atlas.json` | Regiones, punto de apoyo de cada fotograma, animaciones y escala | Generado |
| `gemini/backgrounds/` | Jardín de las Cenizas, Criptas del Eco, Forja del Eclipse (1024 × 800) | Gemini, sin retoques |
| `gemini/hero.png` | Hoja del portador con transparencia (1697 × 927) | Referencia de Gemini, editada con ImageGen de OpenAI para preparar la transparencia |
| `source/gemini/` | Originales con el tablero gris incrustado; excluidos de la importación | Gemini |
| `audio/sfx/` | 27 efectos WAV, 44,1 kHz mono | `tools/audio/synth.py` |
| `audio/music/` | menú, jardín, criptas, forja, jefe y hoguera, en bucle (Ogg Vorbis) | `tools/audio/synth.py` |
| `fonts/` | Jersey 10 | The Soft Type Project, OFL 1.1 |
| `shaders/actor.gdshader` | Variación de tono por ambiente, saturación y destello de golpe | Propio |
| `icon.svg` | Brasa del juego | Propio |

## Animaciones

Cada personaje tiene `idle`, `walk`, `attack`, `hurt` y `death`. Los fotogramas se recortan al contenido y guardan el punto donde apoyan los pies, de modo que todas las animaciones quedan alineadas sobre el suelo. Los enemigos se giran hacia la izquierda al preparar el atlas.

| Personaje | Reposo | Avance | Ataque | Daño | Muerte |
|---|---|---|---|---|---|
| Portador | 8 | 8 | 7 | 3 | 2 |
| Gelatina | 8 | 5 | 5 | 2 | 4 |
| Lucero | 4 | 4 | 8 | 2 | 3 |
| Centinela | 4 | 4 | 4 | 3 | 2 |
| Rey sin Brasa | 4 | 4 | 5 | 3 | 3 |

## Sonido

Todo el audio se sintetiza con osciladores, cuerdas Karplus-Strong, campanas FM, ruido filtrado y reverberación. Los bucles de música pliegan la cola de reverberación sobre su inicio para que no se note el corte, y se normalizan a −17 dB RMS.
