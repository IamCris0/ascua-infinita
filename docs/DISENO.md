# Dirección del proyecto

## Identidad

La dirección actual es **equilibrada**: compañeros para sostener el combate y participación manual para acelerarlo y reaccionar. El primer bloque 0.3 permite mantener Espacio, añade un compañero inicial y rutas y eventos cada cinco victorias. Véase [el plan de 0.3](PLAN_0_3.md); los números y decisiones de 0.2 que siguen son el punto de partida histórico.

**Ascua Infinita** sitúa al jugador en las ruinas de un mundo consumido por un eclipse. La última brasa vive en una armadura diminuta. La sensación principal es convertir una acción sencilla, un clic, en una expedición que desarrolla una identidad mediante reliquias y después deja una herencia permanente.

## Tres escalas de progreso

1. **Segundos:** atacar, encadenar golpes, atrapar ascuas errantes y guardar el Destello para interrumpir al Rey.
2. **Minutos:** comprar daño, automatización, defensa y críticos; elegir una reliquia cada cinco cámaras; superar al jefe de cada diez.
3. **Expediciones:** conservar ascuas, mejorar seis atributos permanentes y regresar con una base más fuerte.

La retirada voluntaria conserva las mismas ascuas que la derrota.

## Decisiones de la versión 0.2.0

- **El jefe pide atención.** Cada tercer golpe del Rey es una Brasa cargada durante tres segundos con un aviso grande. Guardar el Destello para ese momento es la decisión táctica principal del combate.
- **Ritmo entre enemigos.** Cada enemigo tarda 0,35 s en llegar y el jefe 1,6 s, con su nombre en pantalla. Da tiempo a ver la muerte del anterior y marca el avance.
- **Atención intermitente.** Las ascuas errantes aparecen cada 35–70 s y duran 8 s; premian mirar la pantalla sin castigar a quien juega en segundo plano.
- **Ambientes con identidad mecánica.** Las Criptas castigan dejar de golpear; la Forja intercambia riesgo por oro.
- **Equilibrio.** Con el bot de `tools/simulate.gd`, una primera expedición a 3 clics por segundo llega a la cámara 20 en unos dos minutos de simulación; tras doce expediciones, a la 33–40. El Rey de la Forja (cámara 30) actúa como primer muro.

## Dirección visual

Pixel art de Gemini a resolución alta, filtrado lineal al escalar. Paleta de pizarra, hierro y cobre de la referencia de interfaz, con acentos verde menta (la brasa del portador), violeta rúnico y ámbar. Paneles de piedra con correas remachadas dibujados en código para que escalen sin deformarse. Tipografía Jersey 10 para títulos y cifras; la fuente integrada de Godot para textos largos.

## Siguientes ampliaciones propuestas

- Rutas con decisiones entre combate, descanso y evento.
- Un jefe distinto por ambiente.
- Sinergias entre reliquias (por ejemplo, críticos que alimentan a los luceros).
- Logros y estadísticas por expedición.
- Exportación de Windows y pruebas largas de equilibrio con jugadores.
