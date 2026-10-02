# Ascua Infinita

**Un clic enciende la llama. Cada caída la hace eterna.**

Roguelike clicker para Godot 4, en español, con pixel art original, compañeros automáticos y progresión permanente. Primera versión jugable **0.1.0**.

![Partida de Ascua Infinita](docs/preview.png)

## Jugar

En Windows, abre **Jugar.cmd**. El lanzador encuentra Godot en `PATH`, en `GODOT_BIN` o en la carpeta Descargas del usuario. Requiere una instalación de Godot 4; no es un ejecutable independiente.

También puedes importar `project.godot` en Godot y pulsar **F5**. Probado con **Godot 4.7.2**, renderizador Compatibility (OpenGL). No necesita complementos ni paquetes externos. La ventana inicial es de 1280 × 800.

| Control | Acción |
|---|---|
| Clic sobre el escenario / Espacio | Atacar |
| E | Destello: 8 veces el daño del clic, más un aporte de los luceros |
| 1 / 2 / 3 | Comprar filo / lucero / armadura |
| Esc | Pausar o continuar |
| Volver a la hoguera | Terminar la expedición y conservar las ascuas |

## La expedición

- **Ataca y mejora:** el oro compra daño por clic, luceros automáticos y armadura que también cura.
- **Construye una combinación:** cada cinco enemigos superados aparecen tres reliquias aleatorias, sin opciones repetidas. Siete reliquias acumulables modifican clics, críticos, automatización, vida, curación, oro o recarga.
- **Derrota al jefe:** cada diez cámaras aparece el Rey sin Brasa. Sus recompensas son mayores y superar al jefe recupera vida.
- **Explora tres ambientes:** Jardín de las Cenizas, Criptas del Eco y Forja del Eclipse alternan a medida que desciendes. La salud de los enemigos aumenta con la profundidad.
- **Renace:** al morir o retirarte conservas todas las ascuas obtenidas. Compra tres tipos de mejoras permanentes y empieza otro viaje. El oro, la armadura, el filo, los luceros y las reliquias se reinician.
- **Regresa cuando quieras:** cada lucero consigue 2 de oro por minuto de ausencia, hasta cuatro horas. No recibes daño ni avanzas cámaras mientras el juego está cerrado.

Las cadenas de clics añaden hasta un 30% de daño. Los críticos duplican el golpe. Los enemigos anuncian su próximo ataque con una barra y una cuenta regresiva; la pausa congela el combate. No hace falta pulsar a velocidades extremas: los luceros sostienen el daño automático.

## Guardado

Guardado automático cada ocho segundos, al comprar, elegir reliquia, descansar y cerrar. Se conserva también una copia de respaldo para recuperar un archivo corrupto. Los datos se almacenan en `user://ascua_save.json`, normalmente `%APPDATA%\Godot\app_userdata\Ascua Infinita\` en Windows, fuera del repositorio. Se conserva el estado de la expedición, las ofertas pendientes, el legado y las preferencias de sonido y movimiento.

## Arte y sonido originales

Cinco hojas de sprites SVG de **16 fotogramas** cada una: portador, gelatina, lucero, centinela y jefe. Incluyen reposo, movimiento, ataque, impacto y disolución. Los dibujos se definen píxel por píxel y se rasterizan con filtrado nearest. Escenario, partículas, antorchas, órbitas y efectos de golpe están dibujados dentro de Godot. Seis sonidos WAV sintetizados acompañan golpes, críticos, recompensas, reliquias, derrota y ambiente.

Los assets no provienen de packs de terceros. El generador fuente reproducible está en `tools/create_assets.gd`; se incluyen los archivos generados para abrir el proyecto directamente. Consulta [el inventario](assets/README.md).

## Estructura

```text
scenes/main.tscn          Escena de entrada
scripts/run_state.gd     Combate, economía, legado y guardado
scripts/main.gd          Interfaz, controles, audio y ventanas
scripts/arena.gd         Escenario pixelado y animaciones
assets/                  Sprites SVG, icono y efectos WAV
tools/create_assets.gd   Generador reproducible de assets
tests/                   Pruebas de progresión e integración
docs/                    Captura y decisiones de diseño
```

## Comprobar el proyecto

Con `godot` disponible en la terminal:

```powershell
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/test_progression.gd
godot --headless --path . --script tests/test_ui.gd -- --qa
```

La prueba de progresión usa un archivo de guardado independiente y lo elimina al terminar. La prueba de interfaz utiliza `--qa` para no tocar la partida real. La captura reproducible se obtiene con `godot --path . -- --capture` y se guarda en `docs/preview.png`; tampoco modifica la partida real.

Para regenerar los assets:

```powershell
godot --headless --path . --script tools/create_assets.gd
godot --headless --path . --editor --import --quit
```

## Alcance de esta versión

El ciclo de jugar, caer, mejorar y renacer está implementado. El equilibrio a largo plazo sigue siendo de prototipo. Los tres ambientes comparten arquitectura, el jefe repite su patrón de ataque y todavía no hay rutas alternativas, eventos narrativos, música completa ni exportaciones independientes para distribución. El proyecto está preparado para ampliar esos sistemas sin mezclar las reglas del juego con la interfaz.

Proyecto privado. No se concede una licencia de distribución pública por defecto.
