# Hoja de ruta 0.6 → 1.0

Escrita el 8 de octubre de 2026 a partir de la petición de llevar el juego hacia una calidad «AAA»:
- ritmo más pausado;
- mapa interactivo;
- misiones diarias y semanales;
- logros y colección más interactivos;
- más vistosidad;
- mecánicas que no sean solo hacer clic;
- cofres y ruleta;
- equipamiento y mejoras;
- varios personajes y más variedad.

La versión web y la traducción al inglés quedan para después. Cada fase se publica en su propia PR, con pruebas, simulación del bot y builds reexportadas.

## Orden y motivo

| Fase | Versión | Contenido | Por qué en este orden |
|---|---|---|---|
| A | 0.6 | **Ritmo y combate activo**: transición entre cámaras, parada, punto débil, pausas de impacto | Todo lo demás se apoya en un combate con decisiones propias |
| B | 0.7 | **Mapa y fortuna**: mapa de caminos por tramo, cofres, Rueda del eclipse y eventos nuevos | Da agencia entre combates y es donde aparece el botín |
| C | 0.8 | **Arsenal**: equipamiento permanente con rarezas, mejora y desguace; maestrías de Destello y Parada | Necesita los cofres de la fase B como fuente |
| D | 0.9 | **Portadores**: tres personajes con pasiva y técnica propias | Cambia el estilo de juego sobre las piezas anteriores |
| E | 0.10 | **Retos**: misiones diarias y semanales, logros con recompensa, colección interactiva y estadísticas | Recompensa todo lo anterior y da motivos para volver |
| F | 0.11 | **Variedad y vistosidad**: afijos de élite, reliquias nuevas, duelos, fragua, barra de jefe y ambiente por bioma | Completa lo que quedaba corto de la petición: variedad y más vistosidad |
| G | 0.12 | **Web e inglés**: build para itch.io comprobada y traducción completa | Se aplazaron hasta tener el contenido cerrado |

Las mejoras visuales van dentro de cada fase, no en una aparte.

## Fase A · Ritmo y combate activo (0.6) — implementada el 8 de octubre de 2026

Lo que se ha implementado difiere de la propuesta en un punto: la Parada tiene dos niveles. El apartado «Resultado» explica el motivo.

**Ritmo**
- Entre cámaras hay una transición de 1,1 s (antes 0,35 s). El portador avanza, aparece el rótulo de la cámara y el siguiente enemigo entra caminando.
- Los críticos manuales, las victorias, las paradas y los puntos débiles congelan la imagen unas centésimas.
- Los jefes caen a cámara lenta.
- Con «Reducir movimiento» no hay pausas de impacto.

**Parada · R o clic derecho**
- Abre una guardia de 0,45 s.
- Si un golpe normal llega dentro de la guardia, no hace daño. El enemigo queda aturdido 1,5 s y el portador contraataca con el triple de su daño por clic.
- Los ataques cargados se reducen a la mitad, pero no se cancelan: interrumpirlos sigue siendo trabajo de Destello.
- Una guardia fallida deja la parada 1,6 s en recarga, así que pulsar sin parar no compensa.
- La barra de aviso del enemigo marca la zona de parada.

**Punto débil** (como se propuso)
- Cada 6–10 s de combate se ilumina un punto del enemigo durante 2,6 s.
- Hacer clic justo encima produce un crítico seguro ×1,5 y adelanta 1,5 s la recarga de Destello.
- Espacio no lo alcanza: premia apuntar.

**Logros nuevos**
- Guardia perfecta: 25 paradas.
- Ojo certero: 50 puntos débiles.

### Resultado de la fase A

**Parada en dos niveles**

La propuesta original anulaba cualquier golpe parado. En el bot, eso rompía el equilibrio:
- a 3 intentos por segundo, el bot pasaba de quedarse en la cámara 30 a llegar a la 40–48;
- a 5, llegaba a la 60;
- traía tres veces más ascuas por expedición, así que el árbol de legado se llenaba demasiado rápido.

El punto débil apenas influye: sin la Parada, el bot casi no cambia.

Versión final:

| Situación | Efecto |
|---|---|
| Guardia alzada hasta 0,25 s antes del golpe (zona brillante): **parada perfecta** | El golpe no hace daño, el enemigo queda aturdido 0,8 s y el portador contraataca con el doble de su daño por clic |
| Guardia alzada antes (zona azul, 0,5 s): **bloqueo** | Llega la mitad del daño, sin aturdir ni contraatacar |
| Jefes | Una parada perfecta los aturde, pero llega la mitad del golpe |
| Ataques cargados | Pierden la mitad (perfecta) o un cuarto (bloqueo); interrumpirlos sigue siendo cosa de Destello |
| Guardia sin golpe | 1,6 s de recarga |

La barra de aviso del enemigo muestra la zona azul y su extremo brillante. El botón **PARADA** y la barra avisan con «¡PARA! [R]» en el momento justo.

**Equilibrio**

Bot con 12 expediciones seguidas y legado. Una persona que hace más intentos por segundo también para mejor: el bot acierta un 18% de los golpes por cada intento por segundo, hasta un 85%. Cámaras alcanzadas en las expediciones 9–12:

| Intentos/s | 0.5 (antes) | 0.6 |
|---|---|---|
| 0 | 19, 19, 26, 20 | 20, 20, 20, 20 |
| 1 | 30, 30, 30, 30 | 30, 30, 30, 30 |
| 3 | 30, 30, 30, 30 | 30, 40, 40, 40 |
| 5 | 30, 34, 40, 40 | 50, 50, 50, 50 |

Jugar de forma activa ya supera el muro de la cámara 30, y el juego pasivo queda como estaba. Las expediciones duran algo más por la transición entre cámaras.

**Otros cambios**
- Sonidos nuevos sintetizados para la guardia, la parada, el punto débil y el paso entre cámaras.
- Logros 13 y 14: Guardia perfecta (25 paradas perfectas) y Ojo certero (50 puntos débiles).
- «Cómo jugar», los controles, los botones y el LEEME de Windows explican la Parada y el punto débil.
- El guardado conserva la guardia, el punto débil y sus contadores. Las partidas anteriores cargan con valores neutros.

## Fase B · Mapa y fortuna (0.7) — implementada el 9 de octubre de 2026

Capturas: [mapa](map.png), [cofre](chest.png) y [Rueda](wheel.png).

**Mapa de caminos**
- Tras cada hito (cada 5 cámaras), después de la reliquia, se abre un mapa con tres caminos para las 5 cámaras siguientes. Sustituye a la elección actual de descanso, élite o evento.
- Los caminos convergen en la cámara del hito o del jefe.
- Cada nodo es una cámara:
  - combate;
  - élite;
  - evento (santuario, mercader, altar o ruleta);
  - cofre;
  - descanso.
- Los nodos sin combate se resuelven y avanzan una cámara.
- El HUD sustituye los puntos de la barra de cámaras por los iconos del camino elegido.

**Cofres**
- Se abren con animación.
- Pueden dar oro, vida, una reliquia o materiales y equipo (cuando exista la fase C).
- La calidad del cofre (madera, hierro, eclipse) depende del nodo y de la profundidad.

**Rueda del eclipse**
- Evento de apuesta con oro de la expedición: giras la rueda y la recompensa depende del sector.
- Todo es moneda del juego. Sin dinero real, sin anuncios.

### Resultado de la fase B

**Un cambio sobre la propuesta**

En la propuesta, las cámaras de descanso, cofre o evento no tenían combate. En la versión final, **todas las cámaras mantienen su combate** y el nodo decide lo que ocurre antes:
- élite: el rival es élite;
- descanso: curación al llegar y rival nunca élite;
- cofre o evento: una pantalla previa.

Así no cambian la escala de enemigos, los roles fijos (Guardián en la 6, Acólito en la 8) ni las ascuas por victoria. Los roles aparecen bajo cada columna del mapa porque esperan en cualquier camino.

**Caminos**

Cada camino tiene un carácter y garantiza lo que lo define. Ningún nodo se repite más de lo permitido: una Rueda, dos élites, dos cofres, dos descansos y un evento de cada tipo.

| Camino | Contenido habitual | Siempre incluye |
|---|---|---|
| Sendero de las brasas | Combates, descansos, santuario, mercader | Un descanso |
| Senda del desafío | Élites, cofres, altar | Un élite y un cofre |
| Camino del azar | Rueda, mercader, altar, santuario | La Rueda |

**Cofres**
- Madera, hierro o eclipse: 60%, 30% y 10% antes de la cámara 20; 45%, 45% y 10% desde la 20.
- Dan una, dos o tres recompensas, todas distintas: oro (4, 6 o 9 victorias), ascuas (1, 2 o 4), un 35% de vida, un lucero, un nivel de forja o una reliquia a elegir.
- El de madera nunca trae reliquia y el del eclipse siempre.
- Se abren con tres golpes al cerrojo y las recompensas salen una a una.

**Rueda del eclipse**
- La apuesta equivale a 2,5 victorias de la cámara.
- Tiene diez sectores iguales: Nada ×3, Oro ×2 ×2, Oro ×3, Vida, Reliquia, Cofre de hierro y Ascuas. La pantalla muestra los diez, así que lo que se ve es la probabilidad real.
- El resultado se decide al pagar; la animación solo lo muestra, y recargar la partida no permite volver a tirar.

**Equilibrio**

Bot con 12 expediciones; cámaras alcanzadas en las expediciones 9–12. El bot elige siempre el mismo camino, acepta santuarios y mercaderes, y rechaza altares y la Rueda.

| Intentos/s | 0.6 (ruta de descanso) | Sendero | Desafío | Azar |
|---|---|---|---|---|
| 0 | 20, 20, 20, 20 | 20, 30, 20, 30 | 19, 20, 29, 27 | 20, 20, 20, 24 |
| 1 | 30, 30, 30, 30 | 30, 30, 30, 30 | 30, 30, 30, 30 | 30, 30, 30, 30 |
| 3 | 30, 40, 40, 40 | 40, 40, 40, 40 | 37, 40, 44, 46 | 40, 40, 39, 40 |
| 5 | 50, 50, 50, 50 | 50, 50, 53, 50 | 40, 50, 50, 47 | 50, 41, 50, 50 |

- El mapa apenas mueve la profundidad.
- El Desafío trae entre un 15% y un 20% más de ascuas a igual profundidad (élites y cofres), a cambio de más riesgo: con 5 intentos/s llega algo menos lejos.

**Otros cambios**
- Ocho sonidos sintetizados: cerrojo, apertura, apertura rara, recompensa, clic de la rueda, premio, nada y mapa.
- Iconos del mapa y cofres en pixel art generados por `tools/sprites/make_loot_art.py`.
- Logros 15 y 16: Cazatesoros (15 cofres) y La rueda sonríe (Oro ×3).
- Las partidas con una ruta pendiente de la versión anterior la convierten en mapa al cargar.

## Fase C · Arsenal (0.8) — implementada el 9 de octubre de 2026

Capturas: [equipo](arsenal.png) y [maestrías](masteries.png).

**Equipamiento**
- Tres ranuras: arma, talismán y amuleto.
- Rarezas: común, rara, épica y legendaria.
- Las piezas tienen estadísticas y a veces un rasgo especial.
- Caen de cofres y jefes y se conservan entre expediciones.
- Se equipan en la hoguera.

**Mejora y desguace**
- Desguazar una pieza da esquirlas.
- Las esquirlas suben de nivel las piezas.

**Maestrías**
- Mejoras permanentes de Destello y Parada, por ejemplo una ventana de parada más amplia o un Destello que encadena.

### Resultado de la fase C

**Equipamiento**
- Nueve piezas, tres por ranura:

| Ranura | Pieza | Efecto (base común) |
|---|---|---|
| Arma | Espada de ceniza · Hoja del cometa · Lanza rúnica | +5% clic · +1,5% crítico · +8% Destello |
| Talismán | Farol de luceros · Reloj de arena negra · Campanilla de plata | +5% luceros · −2,5% recarga de Destello · +2,5% velocidad de luceros |
| Amuleto | Amuleto de musgo · Moneda partida · Escama de forja | +4% vida · +5% oro · −2% daño recibido |

- Rareza ×1 / ×1,35 / ×1,8 / ×2,4. Cada nivel suma un 8% del valor base; el nivel máximo es 4, 6, 8 o 10 según la rareza.
- Las épicas tienen un 40% de probabilidad de traer **rasgo** y las legendarias siempre lo traen. Hay seis:
  - Sed de brasas: los críticos curan.
  - Ojo de halcón: más puntos débiles.
  - Pulso sereno: parada perfecta más larga.
  - Espinas de obsidiana: el bloqueo devuelve daño.
  - Buena estrella: cofres mejores.
  - Imán de ascuas: más ascuas errantes.
- **Origen**:
  - Todos los jefes dejan una pieza y esquirlas.
  - Los élites tienen un 15% de probabilidad, sin legendarias.
  - Los cofres pueden traer una pieza (más probable y mejor cuanto mejor es el cofre) o esquirlas.
- Arsenal de 24 piezas. Lleno, lo nuevo se funde en esquirlas.
- **Cambio sobre la propuesta**: las piezas se equipan en cualquier momento (pausa u hoguera), no solo entre expediciones.

**Mejora, desguace y maestrías**
- Mejorar cuesta (nivel + 1) × 2, 3, 5 u 8 esquirlas según la rareza. Desguazar devuelve 2, 5, 12 o 30 esquirlas más la mitad de lo invertido. Las piezas equipadas no se pueden desguazar.
- Seis maestrías:
  - Destello ardiente (+8% de daño por nivel);
  - Recarga veloz (−4%);
  - Guardia amplia (+0,04 s de parada perfecta);
  - Contraataque (+0,5×);
  - Guardia firme (el bloqueo detiene un 5% más);
  - Ojo afilado (+0,25 s y +0,2× al punto débil).
- Cada nivel de maestría cuesta su precio base (9 a 15 esquirlas) multiplicado por el nivel que alcanza.

**Equilibrio**

El bot equipa lo mejor, desguaza el resto y gasta las esquirlas en lo más barato. Con una sola semilla, el Arsenal parecía llevar a la cámara 60 desde la sexta expedición. Con tres semillas resultó ser un caso de suerte, así que la comparación usa medias. Cámara media de las expediciones 9–12, tres semillas:

| Intentos/s | Sin Arsenal | Primera versión | Versión final |
|---|---|---|---|
| 0 | 20,9 | 22,2 | 21,8 |
| 1 | 32,6 | 38,3 | 32,4 |
| 3 | 41,9 | 46,9 | 47,8 |
| 5 | 50,6 | 55,8 | 58,2 |

- El Arsenal añade unas cinco cámaras al juego activo.
- La versión final suaviza el crecimiento:
  - una legendaria a nivel 10 multiplica su base por 4,3 en lugar de 6,4;
  - las maestrías cuestan un 50% más;
  - los jefes dan menos esquirlas.

  Así queda margen para los personajes de la fase D.
- Las diferencias entre versiones con jugador activo están dentro del ruido de tres semillas.
- `tools/simulate.gd` acepta ahora `--seed=N` y `--no-arsenal`.

**Otros cambios**
- Iconos de las piezas y de las esquirlas dibujados por `make_loot_art.py`.
- Pestaña **Arsenal** en la Colección (nueve entradas) y el botín en el resumen de cada expedición.
- Logros 17 y 18: Leyenda forjada (una legendaria) y Mano de herrero (una pieza al nivel máximo).

## Fase D · Portadores (0.9) — implementada el 9 de octubre de 2026

Captura: [portadores](bearers.png).

Tres personajes con estadísticas, pasiva y técnica propias, que se desbloquean con logros. Al principio son variaciones de color del portador actual, con prompts preparados para su arte definitivo.

| Portador | Pasiva | Técnica | Cómo se desbloquea |
|---|---|---|---|
| Portador (actual) | Equilibrado | Destello | Disponible desde el principio |
| Centinela | Parada más amplia y contraataque mayor | Muro de brasas | Guardia perfecta |
| Invocadora | Luceros más fuertes y clics más débiles | Llamada del enjambre | Vencer a la Campanera |

### Resultado de la fase D

**Personajes**

Cuatro portadores en lugar de tres, para dar más variedad. Ninguno sustituye a Destello: todos lo conservan contra los jefes (interrumpir, romper escudos y corazas) y le añaden un efecto.

| Portador | Pasiva | Destello añade | Se desbloquea |
|---|---|---|---|
| El Portador | Destello recarga un 15% más rápido y golpea un 15% más | — | Desde el principio |
| La Centinela | +10% de vida, parada perfecta 0,1 s más larga, clics −15% | Muro de brasas: absorbe un 25% de su vida durante 6 s | Guardia perfecta (25 paradas) |
| La Invocadora | Un lucero más al empezar, luceros +30%, clics −20% | Tres luceros más durante 8 s | Silencio roto (vencer a la Campanera) |
| El Errante | +10% de oro, ascuas errantes más a menudo, −10% de vida | Un tercio de una victoria en oro | Cazatesoros (15 cofres) |

- **Cuándo se elige**: en la hoguera, entre expediciones, como el juramento.
- **Ficha de cada portador**: figura, pasiva, técnica y, mientras está bloqueado, el progreso hacia su logro (por ejemplo, 12/25 paradas).
- **Desbloqueo**: al conseguir el logro, un aviso lo anuncia.
- **Interfaz**: el HUD muestra el nombre del portador y la pantalla de título lo dibuja con sus colores. El registro de expediciones guarda quién llevó cada una.
- **Arte provisional**: los nuevos portadores son el caballero recoloreado con el shader del actor. Los prompts para su arte definitivo están en `assets/art/imagegen/README.md`.

**Equilibrio**

Bot con 12 expediciones por portador, desbloqueado desde la primera (`--bearer=id`). Cámara media de las expediciones 9–12, tres semillas.

| Versión | Portador | Intentos/s | 0 | 1 | 3 | 5 |
|---|---|---|---|---|---|---|
| Primera | Portador | | 23,9 | 34,2 | 50,0 | 52,6 |
| Primera | Centinela | | **36,0** | **59,0** | **66,1** | 60,0 |
| Primera | Invocadora | | 27,5 | 35,5 | 43,2 | 50,4 |
| Primera | Errante | | 28,9 | 36,9 | 49,6 | 58,8 |
| Final | Portador | | 22,4 | 36,7 | 42,4 | 57,8 |
| Final | Centinela | | 24,2 | 34,2 | 52,5 | 59,2 |
| Final | Invocadora | | 29,8 | 36,1 | 44,2 | 58,1 |
| Final | Errante | | 27,7 | 36,7 | 45,2 | 58,3 |

**Ajustes de la primera versión a la final**
- **Muro de brasas**: detenía por completo el siguiente golpe, también las cargas de los jefes, así que la Centinela llegaba a la 59 sin apenas jugar. Ahora absorbe un 25% de su vida y dura 6 s.
- **Centinela**: su vida extra baja del 25% al 10%.
- **Errante**: su oro extra baja del 25% al 10%, y Golpe de fortuna, de media victoria a un tercio.
- **Invocadora**: su penalización a los clics se reduce del 30% al 20%.
- **Portador**: recibe un 15% más de daño de Destello.

**Lectura de los resultados**
- A 1 y a 5 intentos/s, los cuatro quedan a menos de tres cámaras entre sí.
- A 3 intentos/s, el ruido de tres semillas es grande: el propio Portador pasó de 50 a 42 tras mejorarlo.
- Sin jugar, la Invocadora y el Errante rinden más, como corresponde a su estilo.

## Fase E · Retos (0.10) — implementada el 9 de octubre de 2026

Capturas: [retos](retos.png), [logros](logros.png) y [bestiario](bestiary.png).

**Misiones**
- Tres diarias y dos semanales, generadas a partir de la fecha. Por ejemplo, «Para 10 golpes» o «Vence a 2 jefes».
- Recompensan con ascuas, llaves de cofre o esquirlas.

**Logros con recompensa**
- Unos 30 logros por categorías.
- La recompensa se reclama al conseguirlos.

**Colección interactiva**
- Retratos animados y fichas con historia.
- Recompensa al completar cada categoría.
- Página de estadísticas.

### Resultado de la fase E

**Retos**
- Tres diarios y dos semanales, elegidos con la fecha como semilla: son los mismos para cualquier partida ese día o semana. La semana va de lunes a domingo.
- Nueve tipos, cada uno con un objetivo diario y otro semanal:

| Reto | Diario | Semanal |
|---|---|---|
| Vencer enemigos | 60 | 400 |
| Vencer élites | 4 | 20 |
| Derrotar jefes | 2 | 10 |
| Paradas perfectas | 8 | 40 |
| Puntos débiles | 10 | 50 |
| Abrir cofres | 3 | 15 |
| Interrumpir cargas | 4 | 20 |
| Atrapar ascuas | 3 | 15 |
| Llegar a la cámara N en una expedición | 20 | 40 |

- Cada reto diario da 12 ascuas y 4 esquirlas; cada semanal, 50 ascuas y 15 esquirlas.
- Al completarse, un aviso lo anuncia. La recompensa se reclama a mano y se pierde si el reto se renueva antes.

**Logros**
- Pasan de 18 a 30, en cinco grupos: Combate, Jefes, Viaje, Botín y Legado.
- Doce son nuevos:
  - Exterminador y Leyenda de ceniza (500 y 2.000 victorias);
  - Intocable (un jefe sin recibir daño);
  - Más allá y Sin fondo (cámaras 50 y 60);
  - Noche perpetua (Eclipse 5);
  - Bolsa llena (100.000 de oro en una expedición);
  - Jugador empedernido (10 giros);
  - Maestro (una maestría al máximo);
  - Muchas manos (todos los portadores);
  - Constancia (10 retos diarios);
  - Semana de brasas (un reto semanal).
- Cada logro tiene una recompensa reclamable, de 5 a 60 ascuas o esquirlas. Los logros conseguidos antes de esta versión la tienen pendiente.

**Colección**
- Fichas en dos columnas:
  - enemigos con su retrato animado (silueta mientras no se conocen) y cuántas veces los has vencido;
  - reliquias, sinergias y piezas con su icono.
- Completar una categoría da 25 ascuas y 8 esquirlas.
- Nuevas pestañas: **Registro** (con el portador de cada expedición) y **Estadísticas** (18 cifras, entre ellas el tiempo de combate).
- La colección se abre también desde la pantalla de título. El título, la pausa y la hoguera muestran cuántas recompensas esperan.

**Equilibrio**
- Los retos premian el tiempo de juego, no la profundidad, así que el bot no los mide.
- Para un jugador diario, suman unas 36 ascuas al día más 100 a la semana. Es menos de lo que deja una expedición que pase de la cámara 30, así que completan la progresión sin sustituirla.
- Los logros dan unas 700 ascuas y 150 esquirlas en total, una sola vez.

## Fase F · Variedad y vistosidad (0.11) — implementada el 10 de octubre de 2026

Capturas: [élite con dos afijos](elite.png) y [barra de jefe](boss.png).

**Afijos de élite**

Todos los élites llevan un afijo; los rivales de duelo, dos.

| Afijo | Efecto | Cómo se contrarresta |
|---|---|---|
| Ardiente | Sus golpes queman un 60% extra durante 3 s | Una parada perfecta no recibe el golpe ni la quemadura |
| Acorazada | −40% de daño hasta media vida | Guardar Destello para la segunda mitad |
| Veloz | Ataca un 35% más rápido | Parar o bloquear más a menudo |
| Vampírica | Se cura un 10% de su vida al golpearte | Parar sus golpes |
| Espinosa | Cada golpe manual te devuelve un 8% de su golpe | Dejar el daño a los luceros y a Destello |

- El élite brilla con el color de su afijo y su placa lo nombra («ÉLITE ARDIENTE Y ESPINOSA»).
- Con dos afijos, sus pistas aparecen por turnos.
- La quemadura se ve en el portador y las espinas, en números verdes.

**Reliquias nuevas**
- Cinco, dibujadas a 28 px para acercarse al detalle de las de Gemini:

| Reliquia | Efecto |
|---|---|
| Cuerno de guerra | +30% de daño contra élites y jefes |
| Escudo de escarcha | La parada perfecta aturde 0,6 s más y el bloqueo detiene un 15% más |
| Lágrima de fénix | Recupera un 0,5% de la vida máxima por segundo |
| Lente de cazador | Puntos débiles un 40% más frecuentes y 1 s más largos |
| Bolsa sin fondo | Una recompensa más por cofre |

- Tres sinergias nuevas:
  - **Cazador implacable** (cuerno y lente): acertar el punto débil de un élite o un jefe adelanta 3 s Destello.
  - **Hielo y llama** (escarcha y lágrima): cada parada perfecta cura un 5%.
  - **Fortuna sin fondo** (bolsa y moneda): no hay cofres de madera.
- La colección pasa a 36 entradas.

**Mapa**
- **Duelo**, en la Senda del desafío: un élite con dos afijos que, al caer, deja una pieza del Arsenal de calidad de jefe.
- **Fragua errante**, en el Sendero y el Azar: sube dos niveles de una mejora de forja (elegida al llegar) por el precio de uno.

**Vistosidad**
- **Barra de jefe** ancha y segmentada en lo alto del escenario. La carga del jefe y los avisos se apartan para no taparla.
- **Ambiente por bioma**:
  - Jardín: ceniza que sube.
  - Criptas: motas violetas lentas y bancos de niebla a ras de suelo.
  - Forja: chispas rápidas que titilan.
- **Golpes y contadores**:
  - Los críticos aparecen grandes y se asientan.
  - El oro del HUD sube contando.
  - Las ventanas se abren con un pequeño impulso.

  Nada de esto se aplica con *Reducir movimiento*.

**Equilibrio**

Cámara media de las expediciones 9–12, tres semillas:

| Intentos/s | 0.10 | 0.11 |
|---|---|---|
| 0 | 22,4 | 22,8 |
| 1 | 36,7 | 38,7 |
| 3 | 42,4 | 49,1 |
| 5 | 57,8 | 55,4 |

Los élites son más duros y las reliquias nuevas y la fragua lo compensan; las diferencias están dentro del ruido. El bot acepta la fragua.

## Fase G · Web e inglés (0.12)

Pendiente:
- Reexportar la versión web con todo lo nuevo y comprobarla en el navegador.
- Traducir al inglés unos 600 textos, con selector de idioma y pruebas de cobertura.
