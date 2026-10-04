# Validación de la versión 0.2.0

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
