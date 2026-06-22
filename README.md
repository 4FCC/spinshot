# spinshot

Juego para una JAM cuyo tema principal es **GIRAR**.

La mecánica central es la **Spin-Bullet**: una bala que el jugador dispara y que
**orbita** un punto fijo describiendo una espiral hacia afuera. Desaparece al
impactar a un enemigo (o al propio jugador), dura hasta **8 segundos** en pantalla
y hay un cooldown de **0.5 s** entre disparos.

Sobre esa base hay un bucle estilo **Brotato**: oleadas de enemigos, monedas que
sueltan al morir y una tienda de mejoras entre oleadas.

Se usan los assets del pack *Tiny Swords (Free Pack)*.

## Controles

- **WASD / Flechas**: mover (con aceleración y fricción)
- **Espacio**: esquivar (gira sobre sí mismo + invulnerabilidad breve)
- **Clic derecho**: Spin-Bullet con giro en **espiral**
- **Clic izquierdo**: Spin-Bullet con giro **ondulado** (trayectoria distinta)
- **N**: iniciar una oleada
- **M**: terminar la oleada actual (abre la tienda)
- **B**: invocar al jefe (tecla de depuración para pruebas)
- **K**: recibir daño (prueba)

Al recibir daño el jugador tiene una breve **invulnerabilidad** durante la cual
no recibe más daño y **atraviesa a los enemigos** (normalmente choca con ellos).

## Bucle de juego

1. En la **pantalla de inicio** pulsa JUGAR.
2. Pulsa **N** para iniciar una oleada (dura **60 s**, con cuenta atrás en pantalla).
3. Mata enemigos con las Spin-Bullets; cada enemigo suelta **monedas** al morir.
4. La oleada termina a los 60 s (o antes con **M**): se abre la **tienda**.
5. Compra mejoras (o usa **Tirar dado** para cambiar las opciones) y pulsa **Continuar**:
   la siguiente oleada empieza automáticamente.
6. Tras la **oleada 10** se abre la tienda una última vez; al salir comienza el
   combate contra el **jefe final**. Al derrotarlo aparece la **pantalla de
   victoria**; si mueres, la **pantalla de muerte**. Ambas permiten reiniciar.

Todo el bucle (oleadas, tienda y pantallas) funciona tanto en **Main** como en
**DEV-ROOM**, porque vive en una escena reutilizable `GameMode.tscn`.

### Oleadas

Hay **10 oleadas** definidas en una tabla de datos (`game_mode.gd` →
`_build_waves`). Cada oleada mezcla varios tipos de enemigo con pesos y van
subiendo de dificultad. Al terminar la oleada 10 aparece el **jefe final**.
Detalles y cómo editarlas en [`docs/oleadas.md`](docs/oleadas.md).

## Enemigos

- **Minion** (Red Pawn): básico, cuerpo a cuerpo. Vida 6, daño 2.
- **BigMinion** (Red Warrior): más resistente (vida 12, daño 4). Para cerca del jugador.
- **BulletMinion** (Red Archer): mantiene la distancia y dispara un **proyectil teledirigido**.
- **Cargador** (Red Lancer): persigue y hace **cargas rápidas** en línea recta (telegrafiadas).
- **Apoyo** (Red Monk): no ataca; **regenera** a los enemigos cercanos y se esconde detrás de ellos.
- **Jefe final** (Black Warrior): ver más abajo.

Los enemigos se empujan entre sí para no apilarse, formando un muro peligroso
cuando llegan en masa.

## Jefe final

Máquina de estados (Follow / Attack / Teleport / Spawn / Ranged / Death) con
**3 fases según su vida**: persigue y golpea, se teletransporta, invoca minions
y lanza voleas radiales. Aparece al terminar la oleada 10 o con la tecla **B**.
Su código está en la carpeta `mecanicas de jefe/`. Detalles y los assets que
faltarían para pulirlo en [`docs/jefe.md`](docs/jefe.md).

## Tienda

Muestra 4 mejoras tomadas al azar de un pool. El botón **Tirar dado** cambia las
opciones por monedas. Además de las de estadísticas (vida, daño, velocidad,
cadencia) hay **ítems con habilidad especial**:

- **Robo de vida**: 25%/nivel de curar 1–3 al recoger moneda (máx 75%).
- **Rebote ofensivo**: la SpinShot genera nuevas SpinShots al impactar (máx 3).
- **División de proyectil**: la SpinShot se parte en dos a media trayectoria.
- **Giro letal**: +1%/compra de matar al enemigo haciéndolo girar.
- **Esquiva automática**: 25%/nivel de esquivar al recibir daño (máx 75%).

Detalles en [`docs/items.md`](docs/items.md).

## Cámara

La cámara sigue al jugador con suavizado y se desplaza ligeramente hacia la
posición del cursor (lookahead). El zoom se ajusta automáticamente al tamaño de
la ventana para mostrar siempre la misma cantidad de mundo, independientemente
de la resolución.

## Estructura del proyecto

- `Scripts/billy.gd`: jugador (estados, animaciones, Spin-Bullet, mejoras, cámara, señal `died`).
- `Scripts/spin_bullet.gd`: bala orbital; desaparece al impactar. `pattern_mode` define el giro.
- `Scripts/enemy.gd`: enemigo base cuerpo a cuerpo (clase `Enemy`); colisión entre enemigos.
- `Scripts/bullet_minion.gd`: enemigo a distancia (extiende `Enemy`).
- `Scripts/charger_minion.gd`: enemigo Cargador con embestidas (extiende `Enemy`).
- `Scripts/support_minion.gd`: enemigo de Apoyo que cura aliados (extiende `Enemy`).
- `Scripts/homing_bullet.gd`: proyectil teledirigido del BulletMinion.
- `mecanicas de jefe/boss.gd` + `boss_bullet.gd`: jefe final y su proyectil.
- `Scripts/coin.gd`: moneda recogible.
- `Scripts/game.gd`: singleton (autoload `Game`) con la economía.
- `Scripts/game_mode.gd`: bucle de juego reutilizable (oleadas, tienda, pantallas).
- `Scripts/floor_builder.gd`: construye el suelo de césped en el `Ground` (TileMapLayer).
- `Scripts/border_trees.gd`: genera en runtime el anillo de árboles que delimita el DEV-ROOM.
- `Scripts/shop.gd`: tienda con tirada de dados.
- `Scenes/`: `Main` y `DEV-ROOM` (ambas usan `floor_builder` + `GameMode`),
  `GameMode`, `Player`, `spin-bullet`, `Coin`, `Minion`, `BigMinion`,
  `BulletMinion`, `HomingBullet`, `grass_tileset.tres`, `player_frames.tres`.

## DEV-ROOM

Sala de pruebas de **30×30 tiles** (1920×1920 px). Incluye:
- Suelo de césped con `TileMapLayer`.
- Decoraciones interiores (árboles, rocas, arbustos, tocón) con colisión.
- Anillo de árboles perimetral generado en runtime (`border_trees.gd`) más
  muros invisibles de seguridad, que impiden salir del área de juego.
- El sistema completo de oleadas, tienda y pantallas (mismo `GameMode` que Main).

Ábrela y pulsa **F6** para ejecutarla de forma aislada.

## Documentación

- [`docs/oleadas.md`](docs/oleadas.md): sistema de oleadas y cómo modificarlas/añadirlas.
- [`docs/items.md`](docs/items.md): mejoras de la tienda y cómo agregar nuevas.
- [`docs/jefe.md`](docs/jefe.md): diseño del jefe y assets que faltarían.
