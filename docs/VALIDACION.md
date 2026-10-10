# Validación del proyecto

## Web e inglés (0.12) — 10 de octubre de 2026

- `tools/run_tests.ps1 -Soak`: 22 suites sin fallos y partida gráfica de 70 s.
- `test_i18n.gd` es nueva (20 comprobaciones) y no deja ningún texto sin traducir. Recorre en inglés:
  - título, pausa, opciones y guía;
  - todas las pestañas de la colección y el Arsenal;
  - combates de élite y jefe;
  - reliquia, mapa, cofre, Rueda y los cinco eventos;
  - retirada, resumen, portadores y hoguera.
- HUD más cargado: 888 px de alto en español y en inglés.
- Versión web 0.12.0-dev probada en el navegador integrado:
  - arranque en español;
  - cambio a inglés desde Opciones;
  - expedición y combate en inglés, sin errores en la consola;
  - guardado en IndexedDB con el campo de idioma;
  - el inglés se conserva al recargar.
- Build de Windows 0.12.0-dev verificada (`--verify-build` y `--verify-build-reload`). La comprobación del paquete ahora exige `locale/en.json` y que «CÁMARA 7» se traduzca.
- Rendimiento frente a `main` en un combate fijo de 15 s, dos rondas: 97–100 fps en `main`, 107–124 en español y 101–112 en inglés. La traducción no lo rebaja.

## Variedad y vistosidad (0.11) — 10 de octubre de 2026

- `tools/run_tests.ps1 -Soak`: 21 suites sin fallos y partida gráfica de 70 s.
- `test_variety.gd` es nueva (40 comprobaciones):
  - cada reliquia y sinergia nueva;
  - los cinco afijos (quemadura evitada con parada, muerte por quemadura, espinas);
  - duelo con dos afijos y su pieza;
  - fragua errante;
  - guardado, validación y partidas anteriores.
- `test_collection.gd`: la colección tiene 36 entradas.
- Capturas `elite.png` y `boss.png` revisadas: la barra del jefe no se pisa con su carga y la placa del élite cabe con dos afijos.
- Equilibrio frente a la 0.10, con tres semillas, en HOJA_DE_RUTA.md.

## Retos (0.10) — 9 de octubre de 2026

- `tools/run_tests.ps1 -Soak`: 20 suites sin fallos y partida gráfica de 70 s.
- `test_retos.gd` es nueva (50 comprobaciones):
  - fechas y semanas de lunes a domingo;
  - retos iguales para cualquier partida el mismo día, distintos entre días, y su renovación;
  - progreso por cada tipo de jugada;
  - tope, reclamación única y premios;
  - Constancia y Semana de brasas;
  - recompensas de logros y categorías;
  - los doce logros nuevos y su deducción en partidas anteriores;
  - bestiario y tiempo de combate;
  - guardado y rechazo de retos inválidos;
  - partidas anteriores con la recompensa de sus logros pendiente.
- `test_collection.gd` adaptada a las ocho pestañas.
- `test_ui.gd` (73 comprobaciones): el aviso de recompensas en la pausa y la reclamación de un reto desde su ficha.
- Capturas `retos.png`, `logros.png` y `bestiary.png` revisadas.

## Portadores (0.9) — 9 de octubre de 2026

- `tools/run_tests.ps1 -Soak`: 19 suites sin fallos. La partida gráfica de 70 s llega a la cámara 29 sin errores.
- `test_bearers.gd` es nueva (30 comprobaciones):
  - desbloqueo y su aviso;
  - elección solo en la hoguera y solo de portadores desbloqueados;
  - cada estadística frente al Portador;
  - Muro de brasas: absorbe, se rompe y caduca;
  - el enjambre y su duración;
  - Golpe de fortuna;
  - Destello sigue interrumpiendo a los jefes con todos;
  - guardado, portador sin logro, portador desconocido y partidas anteriores.
- `test_ui.gd` (69 comprobaciones): la hoguera abre los portadores, la ficha elige y recolorea la figura, y el HUD lo nombra.
- Captura `bearers.png` revisada. La hoguera con el botón Portador cabe sin desplazar.
- Equilibrio por portador en HOJA_DE_RUTA.md.

## Arsenal (0.8) — 9 de octubre de 2026

- `tools/run_tests.ps1 -Soak`: 18 suites sin fallos; partida gráfica de 70 s hasta la cámara 30 sin errores.
- Nueva `test_arsenal.gd` (54 comprobaciones):
  - rarezas y rasgos;
  - cada estadística equipada;
  - una pieza por ranura;
  - vida al quitar un amuleto;
  - mejoras con tope, desguace y arsenal lleno;
  - maestrías;
  - rasgos en combate;
  - botín de jefes y cofres;
  - guardado y rechazo de arsenales inválidos;
  - partidas anteriores.
- `test_ui.gd` (65 comprobaciones): Arsenal desde la pausa; equipar, mejorar, quitar y desguazar con los botones; pestaña de maestrías.
- `test_progression.gd`: la prueba de élites ya no depende de que el rival anterior fuera élite.
- Capturas `arsenal.png` y `masteries.png` revisadas.
- La hoguera con el botón Arsenal cabe sin desplazar.
- Equilibrio con tres semillas en HOJA_DE_RUTA.md.

## Mapa, cofres y Rueda (0.7) — 9 de octubre de 2026

- `tools/run_tests.ps1 -Soak`: 17 suites sin fallos. La partida gráfica de 70 s llega a la cámara 26 eligiendo caminos, cofres y la Rueda, sin errores.
- `test_map.gd` es nueva (41 comprobaciones):
  - caminos: carácter, límites y nodos válidos;
  - descanso, élite y cofre en su cámara, con el combate congelado mientras tanto;
  - tablas de botín;
  - Rueda: pago exacto de cada sector, cobertura de los diez y rechazo sin oro;
  - guardado, conversión de rutas antiguas y rechazo de mapas inválidos;
  - logros.
- `test_journey.gd` adaptada al mapa.
- `test_ui.gd` (56 comprobaciones):
  - botones de camino;
  - mapa desde la barra de cámaras y Esc;
  - cofre con teclado;
  - la Rueda se detiene en el sector que eligieron las reglas.
- Capturas revisadas: `map.png`, `chest.png` y `wheel.png`.
- Equilibrio por camino en HOJA_DE_RUTA.md.

## Combate activo (0.6) — 8 de octubre de 2026

- `tools/run_tests.ps1 -Soak`: 16 suites, cero fallos. Partida gráfica de 70 s sin errores (9.086 fotogramas, 33 bajas).
- Nueva `test_active_combat.gd` (49 comprobaciones):
  - transición entre cámaras;
  - parada perfecta, bloqueo, guardia fallida y recarga;
  - cargas y jefes;
  - punto débil: aparición, alcance solo con clic apuntado, crítico, recarga de Destello y desaparición;
  - guardado y partidas anteriores;
  - logros;
  - clics del escenario y animación de avance.
- `test_ui.gd` (45): botón y tecla de Parada, clic en el punto débil y pausas de impacto (se activan, se recuperan solas y no existen con *Reducir movimiento*).
- Captura `preview.png` revisada con el punto débil encendido y el aviso de parada.
- Equilibrio con el bot antes y después: tablas en HOJA_DE_RUTA.md.

## Eclipse, logros y registro — 8 de octubre de 2026

- `tools/run_tests.ps1 -Balance`: 15 suites, cero fallos. Nueva `test_eclipse.gd` (33 comprobaciones) y dos comprobaciones de la colección para las pestañas Logros y Registro. La muestra de equilibrio no cambia: el nivel por defecto es Eclipse 0.
- Capturas revisadas a 1280 × 800: botón Eclipse en la hoguera sin desplazar las acciones, pestañas Logros y Registro, HUD con el nivel junto a la cámara y aviso de logro. Detalles en PLAN_0_5.md.

## Entradas cinemáticas de jefe — 8 de octubre de 2026

- `tools/run_tests.ps1 -Balance`: 14 suites, cero fallos. Nueva `test_boss_intro.gd` (19 comprobaciones): entrada completa en el primer encuentro de cada jefe y breve después, combate congelado, salto único, pausa, guardado, franjas, acercamiento que mantiene al jefe en pantalla, *Reducir movimiento* y regreso al encuadre.
- Captura `intro.png` revisada: la ficha tiene banda propia y retira cualquier rótulo previo. Partida gráfica de 70 s (10.063 fotogramas, primeros encuentros con Rey y Campanera) sin errores.

## Constelación del Legado (0.4) — 7 de octubre de 2026

- `tools/run_tests.ps1 -Balance`: 12 suites, cero fallos. Nueva `test_legacy_tree.gd` con 41 comprobaciones: estructura, requisitos que solo bloquean la compra, niveles conservados sin requisito, topes, un juramento activo elegido solo en la hoguera, efectos de cada nodo y juramento, Último aliento único por expedición y guardado, migración de partidas 0.3 y juramentos imposibles.
- Refactor de `main.gd` (1.511 → 1.414 líneas) sin cambios de comportamiento: suites y capturas de hoguera, título, opciones y pacto revisadas antes de tocar el árbol.
- Hoguera nueva revisada a 1280 × 800: los tres botones de acción quedan visibles sin desplazar. Equilibrio con cuatro estrategias del bot en PLAN_0_4.md.
- **Corregido: el pie de la pantalla de combate se salía por abajo** al avanzar la expedición. La crónica, la lista de sinergias y las descripciones de dos líneas hacían que el HUD pidiera hasta 1.035 px de alto en una vista de 900. Ahora la crónica y las sinergias ocupan el espacio libre y recortan lo que no cabe (la crónica conserva siempre tres entradas), las mejoras de la forja tienen descripciones de una línea y el HUD pide 888 px con cualquier contenido. Prueba de regresión en `test_ui.gd`, comprobada fallando sin la corrección.

## Cierre de la 0.3 — 7 de octubre de 2026

- `tools/run_tests.ps1 -Balance`: **11 suites**, cero fallos. Nuevas: 22 comprobaciones del Forjador (coraza, ruptura, Colada, Destello, sinergia, pausa, guardado, migración y copia de guardados ilegibles) y de la regla del Eco en progresión y Campanera. Assets sube a 1.177 comprobaciones con la hoja de la Campanera.
- Capturas en la interfaz real (Compatibility, RTX 4050): `campanera-1.png`, `campanera-3.png` y `forjador.png`. Los 24 recortes de la Campanera se revisaron alineados por su punto de apoyo.
- Equilibrio con el bot (12 expediciones, 0/1/3/5 intentos por segundo) antes y después de cada cambio; resultados en PLAN_0_3.md.
- Arte de la tarde: assets sube a **1.724 comprobaciones** (regiones, retrato e ilustraciones de eventos). Las 96 poses nuevas se revisaron recortadas y alineadas por su punto de apoyo; ninguna arrastra píxeles de otra. Capturas en la interfaz real del Guardián (`enemy-6.png`), el Acólito (`enemy-8.png`), el Forjador (`forjador.png`) y los tres eventos. Partida gráfica de 70 s: 10.073 fotogramas, mejor cámara 26, sin errores; combate gráfico contra el Forjador con coraza rota y Coladas, sin errores.

## Renovación de personajes — 4 de octubre de 2026

- Cinco hojas PNG nuevas con transparencia real, integradas mediante regiones y puntos de apoyo. Conservados los assets anteriores. Filtrado nearest en los actores.
- **1.011 comprobaciones de assets y animación**, cero fallos: alfa, límites de regiones, regiones compuestas, secuencias y ataques encolados sin reiniciar el golpe. **33 comprobaciones de interfaz**, cero fallos.
- Importación y capturas del combate, jefe, título y visor de animaciones con renderizador Compatibility/NVIDIA RTX 4050. Se corrigieron fragmentos de capas y llamas que invadían celdas vecinas mediante regiones de dibujo. El visor permite examinar cada secuencia, pausarla y ralentizarla.
- Partida gráfica automática de 70 segundos: 10.075 fotogramas, mejor cámara 20, una expedición finalizada y 38 bajas; sin errores del motor. Ajustes finales posteriores limitados a regiones de dibujo, verificados en el visor y con las pruebas de assets.
- No se modificó el equilibrio ni la partida real. Este lote reemplaza personajes; fondos, interfaz, reliquias, efectos y compañero mantienen los recursos anteriores.

## Primer bloque 0.3.0-dev — 4 de octubre de 2026

- **71 comprobaciones de progresión, 33 de interfaz y 36 de rutas/eventos**, cero fallos. Incluyen mantener Espacio, pausa, compra del mercader, imposibilidad de pagar dos veces, altar no letal, curación limitada, compañero inicial, guardado en una decisión y migración de versión 2.
- Importación en Godot 4.7.2 completada sin errores. Rutas, mercader y guía revisados a 1100 × 700. La captura de rutas final también cerró sin avisos de audio; se permite que el hilo de audio libere sus recursos antes de cerrar la captura.
- Prueba gráfica de 70 segundos a velocidad ×3: 10.073 fotogramas, mejor cámara 25, una expedición terminada y 28 bajas. Sin errores ni avisos. El bot elige rutas y resuelve los eventos.
- Veinte primeras expediciones simuladas (cinco semillas por ritmo), con compras, Destello y ruta segura:

| Intentos de clic por segundo | Cámaras alcanzadas | Duración media |
|---|---|---|
| 0 | 10, 10, 10, 10, 10 | 2,27 min |
| 1 | 19, 18, 20, 18, 20 | 3,20 min |
| 3 | 20, 20, 20, 23, 20 | 2,55 min |
| 5 | 20, 27, 20, 20, 23 | 2,44 min |

Son intentos: la regla limita los ataques aceptados a uno cada 0,3 s. Cero clics sigue incluyendo habilidades y compras; no representa un juego totalmente desatendido. Es una muestra pequeña, no una garantía de equilibrio definitivo. Faltan sesiones humanas y validar las rutas de riesgo en profundidad. No se ha exportado un ejecutable independiente.

## Historial 0.2.0

## Revisión del 4 de octubre de 2026 (Windows)

Godot 4.7.2, Compatibility, OpenGL 3.3 sobre NVIDIA GeForce RTX 4050 Laptop GPU. Se conservaron los cambios de la versión 0.2.0 y los originales de Gemini.

- Importación del editor completada, salida 0, sin errores.
- **70 comprobaciones de reglas**, **26 de interfaz**, **928 de assets** y **6 de audio**: 1.030 comprobaciones, cero fallos. Las pruebas de assets comprueban transparencia real, regiones, animaciones, fuentes y transiciones entre enemigos.
- Nuevas regresiones: tope de Tormenta contenida, conservación de temporizadores del combate, ascua generada sin enfriamiento negativo, guardados antiguos y datos inválidos, movimiento reducido en escenario y título, cambios de música consecutivos y liberación de audio al cerrar.
- Partida automática con gráficos durante **70 segundos a velocidad ×3**: 10.069 fotogramas, mejor cámara 33, una expedición terminada y 51 bajas. Salida 0, sin errores ni avisos del motor.
- Capturas revisadas: combate a **1280 × 800**; título, jefe, pacto y hoguera a **1100 × 700**. Sin controles recortados; colores de los personajes corregidos. Capturas actualizadas en esta carpeta.
- Las pruebas usan archivos de prueba o `--qa`; no modifican la partida del jugador. Las ejecuciones headless restringidas mostraron un aviso del almacén de certificados de Windows, ajeno al proyecto; la importación y la prueba gráfica fuera de esa restricción finalizaron sin él.

Correcciones: el shader ya no multiplica dos veces el color de la textura; los enemigos nuevos no heredan el desplazamiento del anterior; el aura élite queda centrada; se respeta la reducción de movimiento ambiental; los fundidos y la atenuación de música no se pisan; el guardado conserva la fase del combate y Tormenta contenida no consume ascuas después del nivel 10.

No se verificó un ejecutable exportado ni sesiones de juego de varias horas. Al configurar una exportación hay que incluir `assets/art/atlas.json` en el filtro de archivos adicionales.

## Registro previo de la versión recibida

La documentación recibida registraba estas comprobaciones del 2 de octubre de 2026 con Godot 4.7.2 (Linux, renderizador Compatibility sobre OpenGL por software):

- **44 comprobaciones de reglas** (`tests/test_progression.gd`): llegada del enemigo, límite de clics, pausa, compras individuales y en lote, luceros, reliquias, jefe, carga e interrupción de la Brasa, golpe cargado, cambio de ambiente, regeneración de las Criptas, élites, ascuas errantes, derrota, legado, renacimiento, Destello, guardado, respaldo, ingresos offline y conversión de partidas 0.1.0.
- **23 comprobaciones de interfaz** (`tests/test_ui.gd`): escenario, forja y modo máximo, pausa y opciones, pacto de reliquias, Destello, ascuas, retirada, resumen, hoguera, renacer, menú principal y volumen de música.
- **Prueba de resistencia** (`tests/soak.gd`): un jugador automático juega la escena real con gráficos durante 70 s a velocidad ×3, atraviesa los tres ambientes y dos jefes sin errores ni avisos.
- Capturas revisadas a 1440 × 900, 1920 × 1080 y 1100 × 700 (tamaño mínimo): título, combate en los tres ambientes, jefe cargando, pacto, pausa, opciones, guía, resumen y hoguera.

Estas pruebas no sustituyen sesiones largas con jugadores ni verifican una versión exportada.
