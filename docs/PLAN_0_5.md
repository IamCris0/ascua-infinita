# Eclipse, logros y registro — 0.5

Implementado el 8 de octubre de 2026, siguiente paso de la hoja de ruta tras el árbol y las entradas de jefe. Da metas después de superar la cámara 30 y una memoria de lo jugado. Los valores son puntos de partida y se pueden ajustar.

## Modos Eclipse

Se desbloquean uno a uno: superar un ciclo (vencer al jefe de una cámara múltiplo de 30) en el nivel más alto desbloqueado abre el siguiente, hasta el 5. El nivel se elige en la hoguera con el botón **ECLIPSE**, que solo aparece tras desbloquear el primero. No cambia durante la expedición. Las reglas se acumulan:

| Nivel | Regla añadida |
|---|---|
| 1 | Los élites aparecen el doble de a menudo (24% en lugar de 12%) |
| 2 | Los enemigos golpean un 15% más fuerte |
| 3 | Destello recarga un 20% más lento |
| 4 | Los jefes tienen un 25% más de vida |
| 5 | Descansos y santuarios curan la mitad |

- **Recompensa:** +20% de ascuas por nivel al volver a la hoguera. Las ascuas que se ganan durante el viaje no cambian; el bonus se suma al guardarlas.
- **Dónde se ve:**
  - El resumen indica el bonus.
  - Retirarse y abandonar ya muestran la cifra con el bonus.
  - El HUD añade «ECLIPSE N» junto a la cámara.
  - El título muestra el nivel desbloqueado.
- Los textos de descanso y santuario reflejan la curación real.

## Logros

Doce, permanentes y visibles desde el principio (el objetivo se lee aunque no se haya conseguido). Al conseguir uno aparece un aviso en la esquina del escenario y una línea en la crónica.

| Logro | Condición |
|---|---|
| Primera brasa | Vencer a un enemigo |
| Rey depuesto · Silencio roto · Forja apagada | Derrotar a cada jefe |
| Mano rápida | Interrumpir 10 cargas con Destello |
| Rompecorazas | Romper 5 corazas del Forjador |
| Cazador de ascuas | Atrapar 25 ascuas errantes |
| Afinidad | Completar una sinergia |
| Juramentado | Comprar un juramento |
| Los luceros bastan | Derrotar a un jefe sin atacar con clic durante ese combate |
| Más allá del eclipse | Superar la cámara 30 en Eclipse 1 o superior |
| Memoria del eclipse | Completar la colección |

Las partidas anteriores reciben al cargar lo que sus contadores demuestran (primera victoria, ascuas atrapadas, juramentos comprados, sinergias y colección). Las derrotas de jefes anteriores no se pueden deducir y se consiguen al volver a vencerlos.

## Registro de expediciones

Las 8 últimas expediciones, la más reciente primero:
- cámara alcanzada;
- enemigos y jefes;
- duración;
- nivel Eclipse;
- juramento;
- ascuas guardadas.

Se consulta en la Colección (pestañas **Logros** y **Registro**).

## Guardado

Campos nuevos con valores neutros para partidas anteriores: nivel elegido y desbloqueado, contadores de interrupciones y corazas, logros, registro y clics del combate actual (para «Los luceros bastan»). Se rechazan logros desconocidos y registros mal formados. Los niveles Eclipse se recortan a lo existente.

## Validación

`tests/test_eclipse.gd` (33 comprobaciones): desbloqueo por ciclos y tope, elección solo en la hoguera, cada regla, frecuencia de élites, bonus y registro, cada logro y su aviso único, guardado, migración y datos inválidos. La colección comprueba las pestañas nuevas. 15 suites aprobadas; capturas de hoguera, logros, registro y HUD revisadas.

## Pendiente

- Equilibrar Eclipse con jugadores: hoy muy pocas expediciones superan la cámara 30, así que estos modos son contenido de final de partida.
- Posibles recompensas por logro (por ejemplo, un aspecto o una línea del guardián) si se quieren más incentivos.
