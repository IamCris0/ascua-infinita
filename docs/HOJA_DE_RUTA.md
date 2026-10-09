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

## Fase C · Arsenal (0.8)

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

## Fase D · Portadores (0.9)

Tres personajes con estadísticas, pasiva y técnica propias, que se desbloquean con logros. Al principio son variaciones de color del portador actual, con prompts preparados para su arte definitivo.

| Portador | Pasiva | Técnica | Cómo se desbloquea |
|---|---|---|---|
| Portador (actual) | Equilibrado | Destello | Disponible desde el principio |
| Centinela | Parada más amplia y contraataque mayor | Muro de brasas | Guardia perfecta |
| Invocadora | Luceros más fuertes y clics más débiles | Llamada del enjambre | Vencer a la Campanera |

## Fase E · Retos (0.10)

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
