# Material recibido de Gemini

Once imágenes entregadas por el usuario el 2 de octubre de 2026, generadas en Gemini según su indicación. Se conservan sin retoques; este directorio está excluido de la importación de Godot mediante `.gdignore`. Las versiones que usa el juego están en `assets/art/` y `assets/gemini/`.

| Archivo | Uso en la versión 0.2.0 |
|---|---|
| 01_referencia_interfaz.png | Botón de piedra (el texto se sustituye por piedra lisa), retrato del guardián de la hoguera, iconos de bastón, llave y faroles, cristal de ascua. Su paleta y las correas de hierro inspiran los paneles. |
| 02_portador.png | Referencia. El juego usa `assets/gemini/hero.png`, una edición con ImageGen de OpenAI para preparar la transparencia, a partir de esta hoja. |
| 03_gelatina.png | Gelatina: reposo, salto, embestida, daño y estallido. Se eliminan las líneas de la cuadrícula. |
| 04_lucero.png | Lucero enemigo y, recoloreado en verde menta, los luceros compañeros. |
| 05_centinela.png | Centinela: reposo, avance, golpe con maza, daño y derrumbe. |
| 06_rey_sin_brasa.png | Jefe: reposo, avance, lanzamiento de bola de fuego, daño y disolución hasta la corona. |
| 07_jardin_cenizas.png | Fondo del primer ambiente (copia en `assets/gemini/backgrounds/garden.png`). |
| 08_criptas_eco.png | Fondo del segundo ambiente. |
| 09_forja_eclipse.png | Fondo del tercer ambiente. |
| 10_reliquias.png | Los siete iconos de reliquia, sin rótulos ni marcos. |
| 11_efectos.png | Tajo, estallido crítico, chispa mágica y brasas. |

## Transparencia

Las hojas son PNG RGB sin canal alfa y llevan el tablero gris dibujado. `tools/sprites/keyout.py` lo elimina con un relleno desde los bordes que se detiene en el contorno oscuro de cada personaje, de modo que las armaduras grises no se borran. Los huecos interiores del tablero se reconocen porque contienen los dos tonos de la cuadrícula.
