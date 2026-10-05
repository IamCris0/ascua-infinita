# Caminos del Eclipse — enfoque equilibrado

Dirección acordada: los compañeros sostienen el combate; los clics aceleran el avance, y las decisiones y habilidades ayudan a superar amenazas. No exigir pulsaciones rápidas durante toda la partida. Fecha: 4 de octubre de 2026.

## Primer bloque implementado: 0.3.0-dev

- Un lucero al comenzar cada expedición y 4 de daño base por lucero. Las partidas antiguas conservan sus compañeros; el inicial aparece al renacer.
- Ataques manuales con intervalo mínimo de 0,3 segundos. Mantener Espacio permite repetirlos sin castigar la mano. Pausa, menús y decisiones bloquean el ataque.
- Los golpes de compañeros también detienen la regeneración por inactividad de las Criptas.
- Después de cada quinta victoria: elegir reliquia y después ruta. Ambas decisiones detienen el combate y sus temporizadores.
- Sendero tranquilo: hasta 20% de curación y siguiente enemigo normal. Desafío élite: siguiente enemigo con las propiedades élite existentes (×2,2 vida, ×1,3 daño, ×2,5 oro y una ascua extra).
- Ruta de evento: anuncia el encuentro antes de entrar. Santuario (hasta 45% de curación), mercader (un lucero al 80% del precio actual, redondeado hacia abajo) o altar (paga 25% de vida máxima, sin morir, por +20% aditivo al daño durante el viaje).
- Los eventos pueden rechazarse gratis. Cada elección se consume una sola vez. Se puede guardar y volver al título para decidir después.
- Guardados versión 3; lectura de las versiones 1 y 2. Se conservan ruta, evento y pactos. No abrir estos nuevos guardados en la versión 0.2.

Se reutilizan los iconos y el retrato del guardián para probar las reglas. No se presentan como arte final del mercader.

## Siguientes entregas

| Entrega | Trabajo | Criterio para darla por terminada |
|---|---|---|
| Ritmo | Probar sesiones humanas de 10–15 minutos y comparar las tres rutas | Descanso útil sin ser obligatorio, élite con recompensa suficiente, eventos comprensibles y sin bloqueos |
| Enemigos · implementado | Guardián con escudo y Acólito con ataque canalizado; arte provisional | Avisos, contador, interrupción, guardado y combate automático verificados; pendiente valoración humana |
| Jefe de Criptas | Campanera Vacía, con patrones propios | Al menos dos decisiones de combate diferentes al Rey, sin exigir clics rápidos |
| Reliquias | Cuatro sinergias de clics, compañeros, habilidad y defensa | Cada una cambia una decisión; ninguna combinación impide progresar o produce daño ilimitado |
| Colección | Registro persistente de descubrimientos | Muestra únicamente lo encontrado y sobrevive a renacer y migrar un guardado |
| Distribución | Exportación Windows con atlas.json incluido | Arranca fuera del editor, encuentra todos los assets y guarda/carga desde una instalación limpia |

Los números del primer bloque son parámetros iniciales sujetos a pruebas. La versión completa 0.3 todavía no está terminada.

## Assets a pedir, en orden

1. **Mercader de Cenizas**: una imagen de aprobación junto a la referencia del portador. Después, retrato transparente y cuatro fotogramas de reposo. Sirve para el evento ya implementado.
2. **Santuario y altar**: cada objeto aislado, apagado y activo. Sin fondo de escenario, interfaz, letras ni iluminación que invada al personaje.
3. **Guardián del Umbral y Acólito del Eco**: diseñar la silueta primero. Pedir bloqueo/ruptura y canalización/interrupción solo tras cerrar las mecánicas.
4. **Campanera Vacía**: concepto primero; animaciones y efectos después de probar sus patrones.
5. **Cuatro reliquias y efectos**: concretar sus objetos una vez elegidas las sinergias. No encargar iconos genéricos sin función definida.

Para cada lote: adjuntar referencias existentes, aprobar un fotograma, pedir cada animación por separado, pies alineados y celdas iguales. PNG con alfa real; si no se consigue, fondo plano de un color que no use el objeto. Nunca tablero dibujado, etiquetas ni cuadrícula. Comprobar la primera animación en Godot antes de producir todas.

## Evaluación de equilibrio

`tools/simulate.gd -- --sample` compara cinco semillas a 0, 1, 3 y 5 intentos de clic por segundo. El bot compra mejoras, recoge ascuas, usa Destello y elige siempre la ruta segura: cero clics **no significa ausencia de decisiones**. La simulación orienta; no demuestra diversión ni sustituye a jugadores.

Para probar manualmente: una expedición dejando trabajar a los luceros y usando habilidades; otra manteniendo Espacio; otra alternando rutas y rechazando tratos. Comprobar cuánto tarda el primer jefe, por qué termina el viaje y si cada compra se nota.

## Pulido de combate — 4 de octubre de 2026

- Ataque del portador: seis poses a 20 fps; preparación de 0,15 s, contacto y recuperación dentro de la cadencia existente de 0,3 s. Desplazamiento hacia el objetivo y sombra ligada a los pies.
- Daño, destello del enemigo, número y sonido se activan en el mismo contacto. Estela verde coherente con la espada.
- Proyectiles de compañeros y carga del Rey salen antes del daño. Interrumpir la carga retira su proyectil.
- Destello activa sus efectos antes de resolver una muerte, conservando el objetivo correcto.
- Pausar o elegir recompensas congela personajes y efectos. Guardar a mitad de un ataque conserva el tiempo pendiente; morir o cambiar de objetivo lo cancela.
- Pruebas: progresión (71), assets (1011), rutas (36), interfaz (34), sincronización (17). Prueba gráfica de 70 segundos, 10070 fotogramas, sin errores; mejor cámara 27.

Se conserva el arte generado existente. Este bloque ajusta su reproducción y la respuesta del combate; la valoración de fluidez final sigue requiriendo una partida humana.

## Enemigos con habilidades — 4 de octubre de 2026

- Guardián del Umbral en cámaras terminadas en 6: cuatro segmentos de escudo. Los tres primeros impactos hacen un 65% de daño; el cuarto rompe el escudo y hace daño completo. Los luceros también consumen segmentos. Destello rompe el escudo antes de aplicar todo su daño. No regenera el escudo durante ese encuentro.
- Acólito del Eco en cámaras terminadas en 8: tras preparar su ataque durante 4,8 s, canaliza durante 3 s. Destello interrumpe y aturde 2 s. Si completa el Eco, hace 1,6 veces su daño normal.
- Variantes provisionales del centinela y lucero, con color, escudo segmentado, sello y avisos propios. Los nuevos diseños definitivos continúan pendientes.
- El guardado conserva escudo y canalización. Las partidas anteriores sin el campo de escudo cargan con cero segmentos, para no añadir defensa a un combate ya empezado.
- 20 pruebas específicas de habilidades aprobadas. Comparación de cinco semillas: sin clics, cámara 10 antes y después (2,27 frente a 2,30 minutos de media); a 1/3/5 intentos por segundo no aparece un bloqueo de progreso. Estos resultados corresponden a un bot que compra mejoras y usa Destello; no sustituyen pruebas humanas.

Pendientes del plan: Campanera Vacía, cuatro sinergias de reliquias, colección persistente, assets definitivos de enemigos/eventos y exportación Windows.
