# Assets originales

Autoría del proyecto Ascua Infinita. No se descargaron sprites, sonidos o fuentes de terceros.

| Archivo | Contenido |
|---|---|
| `sprites/hero.svg` | Portador con capa naranja, casco, espada y núcleo verde |
| `sprites/slime.svg` | Gelatina de hollín verde menta |
| `sprites/wisp.svg` | Lucero extraviado violeta |
| `sprites/sentinel.svg` | Centinela de piedra con núcleo incandescente |
| `sprites/boss.svg` | Rey sin Brasa, corona dorada y manto escarlata |
| `icon.svg` | Brasa del juego |
| `audio/hit.wav` | Golpe breve |
| `audio/critical.wav` | Golpe crítico |
| `audio/coin.wav` | Recompensa o compra |
| `audio/relic.wav` | Reliquia y mejora permanente |
| `audio/fall.wav` | Fin de expedición |
| `audio/pulse.wav` | Pulso ambiental grave |

Cada hoja mide 512 × 32 píxeles, con 16 celdas horizontales de 32 × 32:

| Fotogramas | Animación |
|---|---|
| 0–3 | Reposo |
| 4–7 | Movimiento |
| 8–11 | Ataque |
| 12–13 | Impacto |
| 14–15 | Disolución |

Fuente editable: `tools/create_assets.gd`. Paleta compartida de trece colores, rectángulos de un píxel y transparencias. El escenario se dibuja en `scripts/arena.gd`, con cambios de paleta por ambiente.

El juego usa la fuente incorporada de Godot; no incluye archivos tipográficos del sistema operativo. Los sonidos son ondas sintetizadas a 22.050 Hz, mono, PCM de 16 bits.
