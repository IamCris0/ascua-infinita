# Ascua 2.0 — Visión

Escrita el 3 de noviembre de 2026, después de la 0.12. El autor nota el juego «frío» y «a medias» y pide una reestructuración completa. Este documento fija la dirección; cada fase se publica en su propia PR, jugable de principio a fin, como en la hoja de ruta anterior.

## Diagnóstico

- **Parece una hoja de cálculo.** En combate, cerca del 60 % de la pantalla son paneles con cifras. El escenario es una ventana central y el portador mide unos 90 px.
- **El color contradice el nombre.** El juego se llama *Ascua*, pero la interfaz es gris pizarra y azul, y casi nada brilla.
- **Todo fuera del combate es un menú.** Mapa, cofres, Rueda, eventos, hoguera, Arsenal y retos usan la misma caja de piedra con texto y botones.
- **No hay historia.** No se sabe por qué se lucha ni hacia dónde se va, y no hay final.
- **Muchos sistemas finos.** Tres monedas, legado, juramentos, maestrías, Arsenal, portadores, reliquias, sinergias, Eclipse, retos, logros y colección. Cada fase añadió uno y ninguno tiene profundidad.
- **Debajo sigue el clicker.** Parada y punto débil se añadieron encima de «clic + comprar +3,5 de daño».

## Idea central: la llama

El mundo está a oscuras y el portador lleva la última ascua. **Su luz es su vida.**

- Con la vida llena, la llama ilumina buena parte de la cámara. Al perder vida, la luz se encoge y la oscuridad se cierra.
- Cada victoria **alimenta la llama**: una corriente de brasas va del enemigo caído al portador (la curación por victoria ya existía, ahora se ve).
- **Destello** ilumina toda la cámara durante un instante.
- Antorchas, el eclipse, los luceros, las ascuas errantes y los proyectiles emiten luz propia. Los élites brillan con el color de su afijo.

Esto une nombre, aspecto y mecánica, y es la firma visual del juego.

## Pilares

1. **Cálido.** Paleta de brasas, hierro y ceniza. Luz que se mueve. Nada de gris azulado.
2. **El escenario es el protagonista.** Combate a pantalla completa, personajes grandes y cámara viva. El HUD es mínimo y está cerca de lo que describe.
3. **Cada decisión se ve.** Las mejoras cambian cómo luchas y se notan en el personaje, no solo en una cifra.
4. **Un mundo, no menús.** Los sistemas los llevan personajes y lugares; los eventos ocurren en el escenario.
5. **Una historia con final.** Tres actos con un objetivo, personajes con voz, créditos y después los niveles Eclipse.
6. **Menos y más profundo.** Se fusiona o se quita lo que no aporta.

## Qué se conserva

- Las reglas de combate (`run_state.gd`): Parada, punto débil, Destello, jefes, élites y afijos, reliquias y sinergias.
- El arte de Gemini e ImageGen, los sonidos y la música, la traducción al inglés.
- Las pruebas, el bot de equilibrio y las builds de Windows y web.
- Las partidas guardadas: cada fase migra el guardado anterior.

## Fases

| Fase | Versión | Contenido |
|---|---|---|
| A | 0.13 | **La llama**: luz y oscuridad, la vida es la llama, combate a pantalla completa, HUD mínimo, paleta cálida |
| B | 0.14 | **Combate con intención**: ataques anunciados propios de cada enemigo; mejoras como elección de 1 entre 3 en lugar de la forja numérica |
| C | 0.15 | **El campamento**: la hoguera pasa a ser una escena viva con personajes que llevan cada sistema y que se reaviva al progresar; eventos dentro del escenario |
| D | 0.16 | **La historia**: tres actos y tres faros, introducción, diálogos con retrato, jefes con voz, final y créditos |
| E | 0.17 | **Menos y mejor**: una moneda por expedición y una permanente; juramentos y maestrías en el árbol de cada portador; retos, logros y colección en la Crónica |
| F | 0.18 → 1.0 | **Pulido**: música y sonido, transiciones, accesibilidad, rendimiento y versión web |

Cada fase se juega antes de pasar a la siguiente. Lo que salga de esas partidas puede cambiar el orden.

## Fase A · La llama (0.13) — implementada el 3 de noviembre de 2026

**Luz**
- Capa de oscuridad por sombreador sobre el escenario, con hasta 24 luces. Funciona en el renderizador Compatibility y en la web.
- El radio de la llama del portador va de la vida llena a casi nada, sin dejar nunca la pantalla a ciegas.
- Luces de cada bioma, de los luceros y los proyectiles, de los impactos, del punto débil, de las ascuas, de las auras de élite y de las cargas de jefe.
- Destello ilumina toda la cámara. Al vencer, las brasas vuelan del enemigo al portador.
- *Reducir movimiento* quita el parpadeo de las luces.

**Pantalla completa**
- El escenario ocupa toda la ventana: los personajes se ven unas 1,6 veces más grandes.
- HUD sobre el escenario:
  - arriba, cámara, bioma, progreso, oro, ascuas y menú;
  - abajo a la izquierda, el portador con su vitalidad y sus reliquias, y las estadísticas al pasar el ratón;
  - abajo en el centro, Destello y Parada;
  - abajo a la derecha, la forja compacta: icono, nivel y precio, con la descripción al pasar el ratón.
- La crónica pasa a ser un registro breve que se desvanece.
- «Volver a la hoguera» pasa al menú de pausa.

**Paleta**
- Los paneles, los botones y el texto pasan de pizarra azul a hierro y ceniza cálidos, con acentos de brasa. Afecta a todos los menús.

**Hecho cuando**
- Todas las suites pasan y el HUD cabe en 1440 × 900 y en 1100 × 700 en los dos idiomas.
- El rendimiento no baja frente a la 0.12.
- Las capturas de combate, élite, jefe y vida baja están revisadas.

### Resultado

**Luz**
- `assets/shaders/darkness.gdshader` multiplica la oscuridad sobre el fondo y los personajes, con hasta 24 luces. Partículas, números, la llama y los luceros se dibujan encima, así que brillan.
- La llama flota junto al hombro del portador. Su alcance va de 130 px de escenario, casi sin vida, a 440 con la vida llena.
- Al perder vida, la luz ambiente también baja (hasta la mitad), sin dejar nunca la pantalla a ciegas.
- Luces de la cámara:
  - las del bioma;
  - el enemigo, siempre visible;
  - las auras de élite y las cargas de jefe;
  - los luceros, los proyectiles, las ascuas errantes, el punto débil y la guardia;
  - los impactos, que encienden un destello breve.
- Al vencer, entre 6 y 18 brasas vuelan del cuerpo a la llama, que se aviva. Al recibir un golpe, la llama se agita.
- Destello ilumina toda la cámara. Al empezar una expedición, la llama se enciende desde cero.
- La pantalla de título usa la misma luz.

**Pantalla completa**
- El escenario ocupa la ventana y los personajes se ven unas 1,6 veces más grandes que en la 0.12. Bordes ahumados arriba y abajo para que el HUD se lea.
- HUD sobre el escenario:
  - arriba, la cámara, el bioma (su regla al pasar el ratón), el progreso, el oro, las ascuas y el menú;
  - a la izquierda, el portador con su vida y sus reliquias, y sus cifras al pasar el ratón; debajo, las tres últimas líneas de la crónica, que se desvanecen;
  - a la derecha, la forja en columna: icono, nivel y precio, con el nombre y el efecto al pasar el ratón;
  - abajo, Destello y Parada.
- Rótulos, avisos, ascuas errantes y la carga del jefe evitan las zonas del HUD. Durante la entrada de un jefe, el HUD se aparta.
- «Volver a la hoguera» y el récord pasan al menú de pausa, que ahora tiene dos columnas.

**Paleta**
- Los grises azulados de paneles, botones, mapa, cofres y textos pasan a hierro y ceniza cálidos. Se conservan los acentos de color: violeta rúnico, verde de alma y el acero de los acorazados.

**Traducción**
- Las listas de botín con comas («Filo de ascua +1, Lanza rúnica (épica)…») podían partirse por el sitio equivocado.
- Ahora el traductor prueba otra plantilla cuando una deja trozos sin traducir. Hay una muestra fija en `test_i18n.gd`.

**Rendimiento**
- En el mismo combate fijo de 15 s, `main` y esta rama van a 144 fps, el tope del monitor.
- La GPU tarda 0,33 ms por fotograma en `main` y 0,37 ms con la luz. La CPU de render baja de 1,84 a 1,21 ms porque el HUD tiene menos controles.

## Lo que necesito del autor

- **Fase C:** retratos y sprites de los personajes del campamento (herrera, cartógrafa, archivero). Prepararé los prompts como con los portadores.
- **Fase D:** ilustraciones de la introducción y del final, si se quieren con arte propio.
- **Fase F:** decidir la música. Puede seguir sintetizada o venir de otra fuente.
