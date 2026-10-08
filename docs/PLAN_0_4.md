# Constelación del Legado — plan de la 0.4

Propuesta del 7 de octubre de 2026, aprobada el mismo día (un juramento activo; Tormenta contenida en la rama Brasa) e implementada. Los cambios que pidió la simulación están en «Resultado». Continúa el enfoque equilibrado de la 0.3: la hoguera deja de ser una lista de seis mejoras lineales y pasa a ser un árbol con tres ramas y un **juramento** activo por expedición. Nada de lo ya comprado se pierde.

## Objetivos

1. **Identidad por expedición.** Antes de renacer eliges hacia dónde crece tu brasa (clics, luceros o supervivencia) y qué juramento llevas.
2. **Metas a medio plazo.** Con 55–60 ascuas por expedición (bot en el muro de la cámara 30), algo nuevo cada una a tres expediciones.
3. **Superar con el tiempo el muro de la cámara 30** sin bajar su dificultad: ahora 12 expediciones seguidas del bot se quedan en la 30.

## Estructura

Coste del nivel siguiente = base + paso × nivel actual, como hoy.

| Rama | Nodo | Efecto por nivel | Niveles | Coste | Requisito para comprar |
|---|---|---|---|---|---|
| Común | Fortuna heredada | +10% de oro | 15 | 8 + 6n | — |
| Común | Chispa temprana | +30 de oro al empezar | 10 | 6 + 6n | — |
| **Filo** | Brasa interior | +2 al clic y +8% a todo el daño | 20 | 5 + 5n | — |
| Filo | *Ojo templado* | +2% de probabilidad crítica | 5 | 12 + 8n | Brasa interior 3 |
| Filo | *Cadena larga* | +5 al tope de la cadena (20 → 35; hasta +52% al clic) | 3 | 20 + 15n | Brasa interior 3 |
| Filo | **Juramento: Golpe de eco** | Cada 10.º golpe de una cadena hace ×3 | 1 | 120 | Ojo templado 1 y Cadena larga 1 |
| **Luceros** | Pacto estelar | +1 de daño por lucero | 20 | 5 + 5n | — |
| Luceros | *Lucero heredado* | +1 lucero al empezar | 2 | 40 + 40n | Pacto estelar 3 |
| Luceros | *Órbita veloz* | Los luceros atacan un 4% más rápido | 5 | 15 + 10n | Pacto estelar 3 |
| Luceros | **Juramento: Enjambre** | +1 lucero al empezar y ataques un 20% más rápidos; clics −15% | 1 | 120 | Lucero heredado 1 y Órbita veloz 1 |
| **Brasa** | Corazón eterno | +20 de vida máxima | 20 | 5 + 5n | — |
| Brasa | Tormenta contenida | Destello recarga un 6% más rápido | 10 | 10 + 8n | Corazón eterno 3 |
| Brasa | *Piel de ceniza* | −3% de daño recibido | 5 | 12 + 8n | Corazón eterno 3 |
| Brasa | **Juramento: Último aliento** | Una vez por expedición, un golpe mortal te deja con 1 de vida y recarga Destello | 1 | 150 | Tormenta contenida 1 y Piel de ceniza 1 |

En cursiva, nodos nuevos; los demás son las seis mejoras actuales, con sus mismos efectos y precios.

**Reglas**

- Los requisitos solo bloquean la compra: ningún nivel comprado se pierde ni se desactiva.
- Puedes poseer los tres juramentos, pero solo **uno está activo**. Se elige gratis en la hoguera antes de renacer y no cambia durante la expedición. Es la decisión de identidad.
- Los topes nuevos (20, 15 y 10) superan cualquier nivel alcanzado hoy. Si una partida ya supera un tope, conserva sus niveles sin reembolso, como ya ocurre con Tormenta contenida.

## Migración del guardado

- El legado pasa de 6 a 14 entradas. Las partidas anteriores se completan con ceros mediante la migración que ya existe. Campos nuevos: juramento activo (ninguno por defecto) y si Último aliento ya se usó en la expedición.
- Tu partida actual (legado 3, 2, 3, 2, 4, 2) lo conserva todo. Para subir Tormenta contenida primero hay que llevar Corazón eterno a 3 (15 ascuas); el nivel 2 que ya tienes sigue activo.
- Como en la 0.3, las builds anteriores no leerán estos guardados: hay que reexportar la versión portátil, y un guardado ilegible se copia aparte en vez de perderse.

## Interfaz de la hoguera

- Arriba, ascuas disponibles, guardián, colección y fila común.
- Debajo, tres columnas (Filo, Luceros y Brasa): raíz, dos nodos y juramento, unidos por líneas que se iluminan al cumplir el requisito.
- Los nodos bloqueados aparecen atenuados con su requisito; el juramento tiene un botón *Activar* y una marca de activo.
- Al pasar el cursor: efecto acumulado actual y del nivel siguiente. *Enter* sigue siendo renacer; las compras pasan a ser con el ratón.
- Debe caber a 1100 × 700 sin recortes, como el resto de menús.

## Refactor previo

`main.gd` tiene unas 1.500 líneas con toda la interfaz. Antes del árbol:

1. Extraer las piezas reutilizables (etiquetas, botones, tarjetas, ranuras de icono, paneles de piedra) a `scripts/ui_factory.gd`.
2. Construir la hoguera en su propio archivo (`scripts/legacy_tree.gd`).

El comportamiento debe quedar idéntico, validado con las suites y las capturas existentes.

## Equilibrio

- El bot de `tools/simulate.gd` comprará el nodo disponible más barato y activará el juramento de la rama donde más haya invertido.
- Medición de 12 expediciones a 0/1/3/5 intentos por segundo, antes y después.
- Criterios:
  - La primera expedición no cambia (el árbol empieza con lo ya comprado).
  - A 3 intentos por segundo, al menos un tercio de las expediciones 9–12 supera la cámara 30.
  - Ningún juramento domina en todas las cadencias.

## Después del árbol: entradas cinemáticas de jefe

Con el arte existente: franjas negras, zoom al jefe, ficha con nombre y título, y una pausa breve del combate. Se puede saltar con clic o Esc, respeta *Reducir movimiento* y es completa la primera vez que descubres a cada jefe y breve las siguientes.

## Entregas

| Entrega | Trabajo | Criterio para darla por terminada |
|---|---|---|
| Refactor | `ui_factory.gd` y hoguera separada | Suites y capturas sin cambios |
| Árbol | Datos, requisitos, topes, juramentos y migración | Pruebas de compra, requisitos, topes, efectos, guardado y migración |
| Interfaz | Hoguera con tres ramas | Comprar, activar juramento y renacer a 1100 × 700 sin recortes |
| Equilibrio | Bot y simulación | Criterios de la sección anterior |
| Cinemáticas de jefe | Entradas de Rey, Campanera y Forjador | Saltables, sin bloquear el combate, con *Reducir movimiento* |

## Decisiones abiertas

1. ¿Un solo juramento activo (recomendado) o los tres a la vez?
2. ¿Tormenta contenida dentro de la rama Brasa (con requisito) o en la fila común sin requisito?
3. ¿Te convencen los nombres y los efectos de los juramentos?

## Resultado — 7 de octubre de 2026

Implementados el refactor (`ui_factory.gd`, `legacy_tree.gd`), los 14 nodos con requisitos, topes y juramentos, la migración y la nueva hoguera. 41 comprobaciones nuevas (`tests/test_legacy_tree.gd`); las 12 suites aprobadas.

**Cambios respecto a la propuesta, por la simulación**

| Cambio | Motivo |
|---|---|
| Brasa interior pasa a la fila común; los nodos de Filo la siguen exigiendo a nivel 3 | Sube un 8% *todo* el daño. Dentro de Filo, esa rama ganaba en todas las cadencias y las otras nunca la compraban. Una raíz propia de Filo («Pulso firme», +3 al clic) se probó y se descartó: dejaba Filo por debajo de todo. |
| Órbita veloz: 5% por nivel (antes 4%) | Luceros no superaba nunca la cámara 30. |
| Enjambre: ataques un 25% más rápidos y clics −10% (antes 20% y −15%) | Ídem. |
| Piel de ceniza: −4% por nivel (antes −3%) | Brasa no era la mejor en ninguna cadencia. |
| Último aliento: deja un 30% de vida y desata la furia 12 s (antes 1 de vida) | Ídem; convierte sobrevivir en remontada. Recargarlo tras cada jefe se probó sin efecto apreciable y se descartó. |

**Equilibrio** (cinco semillas, 12 expediciones; expediciones 9–12 que superan la cámara 30 y cámara media). «Barato» compra siempre lo más barato; las demás estrategias compran su rama y la fila común y ahorran para su juramento.

| Estrategia | 0 intentos/s | 1 intento/s | 3 intentos/s | 5 intentos/s |
|---|---|---|---|---|
| Barato | 0/20 · 19,7 | 0/20 · 29,6 | 2/20 · 30,9 | 10/20 · 34,2 |
| Filo | 0/20 · 17,3 | 0/20 · 27,8 | 5/20 · 31,6 | 8/20 · 34,0 |
| Luceros | 0/20 · **19,8** | 0/20 · 29,4 | 1/20 · 30,4 | 4/20 · 31,3 |
| Brasa | 0/20 · 17,4 | 0/20 · **29,8** | **9/20 · 32,7** | **11/20 · 34,0** |

- Ningún juramento domina en todas las cadencias: Luceros es el mejor sin clics y Brasa desde un intento por segundo. Filo queda en medio.
- El criterio de que un tercio de las expediciones 9–12 supere la cámara 30 a 3 intentos por segundo solo lo cumple Brasa (45%). Sin árbol ninguna estrategia lo cumplía.
- El muro de la cámara 30 sigue siendo el principal asunto de equilibrio. Sin coraza o sin Colada el resultado apenas cambia: lo deciden la vida y el daño base del jefe. Queda para las sesiones con jugadores.
- El bot no juega como una persona: no prioriza Destello, no elige rutas y compra siguiendo reglas fijas. Estos números orientan, no sustituyen pruebas reales.

**Tu partida** (legado 3, 2, 3, 2, 4, 2) conserva todo. Con Brasa interior 3 ya tiene abiertos Ojo templado y Cadena larga; para subir Tormenta contenida necesita Corazón eterno 3 (15 ascuas).

## Entradas cinemáticas de jefe — 8 de octubre de 2026

Implementadas con el arte existente ([captura](intro.png)):

- **Primer encuentro con cada jefe** (Rey, Campanera y Forjador): entrada de 3,2 s.
  - Franjas de cine que se deslizan.
  - El jefe entra caminando durante 1,6 s.
  - La cámara se acerca un 16% manteniéndolo en su sitio.
  - Una ficha con título, nombre y un consejo para vencerlo; por ejemplo: «Su coraza fundida dura tres segundos. Rómpela antes de que se vierta».
- **Encuentros siguientes:** entrada breve de 1,6 s con franjas y el rótulo de siempre.
- **Durante la entrada nadie ataca:** clics, luceros, Destello y enemigo esperan. Las recargas siguen corriendo, como en la entrada anterior.
- **Saltar:** *Esc* o *Enter* dejan solo 0,3 s. *Esc* fuera de una entrada sigue abriendo la pausa. La pausa congela la entrada y no se puede saltar estando en pausa.
- ***Reducir movimiento*:** franjas fijas y sin acercamiento.
- **Guardado:** la entrada sobrevive al guardado (el tope de su tiempo pasa a 3,2 s). El primer encuentro se decide con la colección: un jefe ya descubierto entra en versión breve.

Validación: 19 comprobaciones nuevas (`tests/test_boss_intro.gd`) y una de interfaz (Esc salta en vez de pausar). Las 14 suites aprobadas. Partida gráfica de 70 s sin errores.
