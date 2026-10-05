# Personajes ImageGen — 4 de octubre de 2026

Cinco hojas nuevas creadas con la herramienta integrada ImageGen de OpenAI, sin usar la API/CLI. PNG originales con alfa real, conservados sin modificar. El juego usa estos personajes; los anteriores de Gemini se conservan como referencia.

Cada hoja tiene 24 poses: seis de reposo, seis de movimiento, seis de ataque, tres de daño y tres de muerte. En la gelatina se excluyen dos poses de ataque donde los ojos cambian de orientación. `characters.json` contiene recortes, puntos de apoyo y secuencias; `tools/import_imagegen.gd` reconstruye solo estos metadatos. Algunos golpes se dibujan por partes para separar capas y efectos que invaden el espacio entre celdas. El motor usa filtro nearest para conservar bordes definidos.

Los clics encolan como máximo un ataque visual y no reinician un golpe a mitad. Daño y muerte pueden interrumpirlo. Los fondos, iconos, efectos y compañeros conservan el arte anterior; este lote renueva al portador y los cuatro enemigos.

## Prompts de producción (registro de las especificaciones)

Especificación común: sprites para Godot de fantasía oscura, pixel art de 16 bits con grupos de píxeles definidos y paleta limitada. Lienzo transparente de 1536 × 1024, seis columnas y cuatro filas de 256 × 256, sin cuadrícula, etiquetas, tablero ni fondo. Identidad, equipo y escala constantes. Fila 1: seis poses de reposo; fila 2: seis de movimiento; fila 3: seis de ataque con anticipación, extensión y recuperación; fila 4: tres de daño y tres de muerte. Personajes completos, con margen para armas y capas. El resultado requirió ajustes de regiones porque la generación no respetó todos los márgenes.

### hero-v3.png

Create a NEW coherent pixel-art animation sprite sheet of a small ember knight, facing RIGHT throughout. Charcoal steel helmet with readable amber eye slit, short burnt-orange scarf and cape, small mint-green ember gem in chest, ivory steel sword held in right hand. Strong attractive silhouette, compact body but articulated legs and arms, hand-pixelled 16-bit aesthetic with deliberately crisp clusters, limited flat palette, restrained highlights. NO blurry painted rendering.

Canvas 1536x1024, exactly SIX columns and FOUR rows, each invisible cell 256x256. 24 distinct animation frames, one full-body character per cell. Fixed character proportions, no camera movement or perspective changes. Feet baseline at y=224 within each cell, torso near x=120. Standing character 160 pixels tall, all sword/cape motions inside its cell with transparent margins. The images will be displayed around 150px tall. Actual transparent background; no checkerboard, shadows, labels, text, grid or separators.

Row1 frames1-6: looping breathing battle idle with visibly bending knees, shoulders rising/falling and fluttering scarf, sword angled low right. Same baseline.
Row2 frames1-6: full readable running cycle toward right IN PLACE: contact right foot, compress, passing, contact left foot, compress, passing. Clearly alternating legs and cape movement.
Row3 frames1-6: ONE dramatically readable sword attack: low crouch preparation, sword pulled high BACK, torso twist and sword overhead, long forward lunge with sword extended horizontally RIGHT, low follow-through blade pointing down-right, recovery back to guard. Six genuinely different body/arm/sword poses, not cloned idle images. Brief crisp pale blade trail only frames4-5.
Row4 frames1-3: hurt recoil backward, crouched bracing, return guard; frames4-6: death kneeling, collapsing on knees with ember escaping, helmet and cape lying on floor with few small mint embers. Every frame self-contained, silhouettes uncropped.
Keep exactly the same knight identity, equipment, palette and sprite size across all24 frames. This is an animation asset, not an illustration or mockup.

### slime-v3.png

A squat soot-and-mint jelly monster, two amber eyes, dark charcoal ash chunks suspended in its mint body. Face LEFT. Very expressive squash and stretch.

Idle: breathing expanding and compressing. Walk: squash, push-off, rising, airborne round shape, falling, landing wide squash. Attack: pull mass backward to RIGHT, crouch, stretch body far LEFT, peak leftward lunge, elastic rebound, return mound. Hurt first3: dent right side, recoil toward right, recover. Death last3: flatten, burst into clearly separate droplets, small ash puddle.

### wisp-v3.png

A violet spectral flame with dark purple outlined silhouette, pale ivory core and small amber eyes, fragmented trailing tail. Face LEFT. Crisp flat pixel clusters, no fuzzy glow.

Idle: flame stretches and curls with face maintaining identity. Walk: tail waves on the RIGHT, entire body leans LEFT and recoils over6frames. Attack: small core begins contracting, compressed core, pulled-back flame toward RIGHT, vigorous firebolt projected LEFT inside own cell, stretched follow-through, recovery. Hurt first3: core contracts, flame bends away toward right, recover. Death last3: flame shrinks, scattered violet sparks, tiny final sparks.

### sentinel-v3.png

A heavy hollow knight of blue-grey stone armor, square featureless helmet with narrow orange slit, broad blocky shoulders, orange ember crack in chest, massive stone forearm hammer. Face LEFT. Thick legs and blunt geometry. No sword.

Idle: heavy breath and small shoulder settling. Walk: obvious alternating stomp cycle with bent knees, different leg positions. Attack: crouch, lift hammer arm far above head, torso pulled back to RIGHT, slam hammer LEFT downward, crouched full follow-through, stand recover. Hurt first3: recoil backward, brace, recover. Death last3: kneel, torso breaks down into stone blocks, pile of armor with ember dying.

### boss-v3.png

A hollow monarch with a broken golden crown, pale metal mask, long ragged crimson cloak, black empty chest ringed with amber embers, black armor and articulated boots. Face LEFT. Tall threatening but fully visible character, identical size across poses.

Idle: ominous chest breathing and visibly billowing cloak. Walk: 6 distinct slow deliberate alternating steps with cape dragging behind to RIGHT. Attack: reach back, raise hand forming small fire orb, wide crouch charge, thrust hand sharply LEFT releasing bright angular fire blast inside cell, follow-through, recover. Hurt first3: bend backward toward right, brace, recover. Death last3: kneel crown falling, dissolve into ashes, crown alone on small ash mound.

### Corrección del jefe

Edit this existing 1536x1024 transparent 6-column by4-row sprite sheet. Preserve the monarch identity, all poses, exact grid positions, all other frames and actual transparency. Fix ONLY frame boundaries in the THIRD ROW: the fourth frame (cell x768..1023,y512..767) has a leftward fire blast extending out of its cell and contaminating the previous character's frame. Shorten that blast so that ALL pixels of the fourth pose including fire stay inside x780..1010. Remove the stray blast pixels from the third cell x512..767 without changing that third character or its small chest orb. Keep the fourth king's hand thrusting LEFT, full body, crown and cape in its cell. Also keep second frame's raised flame inside x268..499. Do not add a background, grid, text, shadows, checkerboard or blur. Same canvas size. Exact transparent sprites ready for slicing.
