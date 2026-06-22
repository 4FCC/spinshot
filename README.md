# spinshot

Juego para una JAM cuyo tema principal es **GIRAR**.

La mecánica central es la **Spin-Bullet**: una bala que el jugador dispara y que
**orbita** un punto fijo describiendo una espiral hacia afuera. Desaparece al
impactar a un enemigo (o al propio jugador), dura hasta **8 segundos** en pantalla
y hay un cooldown de **0.5 s** entre disparos.

Sobre esa base hay un bucle estilo **Brotato**: oleadas de enemigos, monedas que
sueltan al morir y una tienda de mejoras entre oleadas.

Se usan los assets del pack *Tiny Swords (Free Pack)*.

## Controles (jugador, escena Main)

- **WASD / Flechas**: mover (con aceleración y fricción)
- **Espacio**: esquivar (gira sobre sí mismo + invulnerabilidad durante todo el
  recorrido del esquive)
- **Clic derecho**: Spin-Bullet con giro en **espiral**
- **Clic izquierdo**: Spin-Bullet con giro **ondulado** (trayectoria distinta)
- **ESC**: abrir/cerrar el **inventario** (también accesible en la tienda)

Al recibir daño el jugador tiene una breve **invulnerabilidad** durante la cual
no recibe más daño y **atraviesa a los enemigos** (normalmente choca con ellos
y con los muros del escenario).

### Código secreto (Easter egg)

Con las teclas de movimiento, el combo **arriba, arriba, abajo, abajo,
izquierda, derecha, izquierda, derecha** activa/desactiva el **god mode**
(no recibe daño) en cualquier escena, no solo en DEV-ROOM. Hay 1.5 s de margen
entre teclas antes de que se reinicie el combo. Mientras está activo, el sprite
del jugador **parpadea** (alterna opacidad) como indicador; el parpadeo se
detiene al volver a introducir el combo. Lógica en `Scripts/billy.gd`
(`_check_cheat_code` / `_toggle_secret_god_mode`).

## Bucle de juego (Main)

1. En la **pantalla de inicio** pulsa JUGAR.
2. La **oleada 1 empieza automáticamente** (cada oleada dura **40 s**, con cuenta atrás).
3. Mata enemigos con las Spin-Bullets; cada enemigo suelta **monedas** al morir.
4. Al terminar la oleada aparece un aviso grande **centrado en pantalla**
   ("¡Oleada N superada!") durante 2 s y luego se abre la **tienda**: al entrar,
   las Spin-Bullets que quedan en vuelo desaparecen y el jugador queda
   **congelado** (las monedas en el suelo NO se tocan, se recogen en la
   siguiente oleada). Compra mejoras (o usa **Tirar dado**) y pulsa
   **Continuar**: el jugador se descongela y la siguiente oleada empieza sola.
5. Tras la **oleada 10** se abre la tienda una última vez; al salir comienza el
   combate contra el **jefe final**. Al derrotarlo aparece la **pantalla de
   victoria**; si mueres, la **pantalla de muerte**. Ambas permiten reiniciar.

Todo el bucle (oleadas, tienda, jefe, pantallas, inventario) vive en la escena
reutilizable `GameMode.tscn`, que tanto **Main** como **DEV-ROOM** instancian.
La diferencia es el modo: Main juega solo (auto), DEV-ROOM es manual + depuración.

## Inventario

Se abre con **ESC** (o durante la tienda). Muestra en un panel de madera los
ítems comprados con su **sprite definitivo** y cantidad/nivel; al pasar el cursor
por encima aparece un **tooltip** con nombre, descripción, efectos y nivel.
Al abrirlo (igual que en las pantallas de inicio/muerte/victoria) se **ocultan
temporalmente** la barra de vida, la de esquive y los textos de info/monedas
para que la interfaz quede limpia.

## Interfaz / assets

- Los **ítems de la tienda e inventario** usan los sprites de `Items assets/`
  (un .png por ID de objeto).
- La interfaz (tienda, inventario, pantallas, barras de vida/esquive) comparte
  un estilo **madera/dorado** centralizado en `Scripts/ui_theme.gd`
  (`UiTheme`), acorde al kit `UI assets/MediavelFree.png`.

## Herramientas de depuración (solo DEV-ROOM)

- **M**: iniciar la siguiente oleada · **N**: terminar la oleada actual
- **B**: invocar al jefe
- **1–5**: generar enemigos de prueba (Minion / BigMinion / BulletMinion / Cargador / Apoyo) — no atacan
- **O**: abrir la tienda en cualquier momento
- **C**: +100 monedas
- **G**: activar/desactivar el god mode (mismo efecto que el código secreto de
  arriba, pero con un solo atajo, sólo disponible en DEV-ROOM)

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

### Velocidades

El jugador se mueve a **300**. Todos los enemigos comunes (Minion, BigMinion,
BulletMinion, SupportMinion, ChargerMinion) van a **268**, ligeramente más
lentos que el jugador (tras varias rondas de ajuste a partir del feedback de
playtesting). La embestida especial del ChargerMinion no usa `move_speed`, sino
`charge_speed` = **750**, sin cambios.

## Jefe final

Máquina de estados (Follow / Attack / Teleport / Spawn / Ranged / Death) con
**3 fases según su vida**: persigue y golpea, se teletransporta, invoca minions
y lanza voleas radiales. Aparece al terminar la oleada 10 o con la tecla **B**.
Su velocidad base (`move_speed` = 300, igual al jugador) se multiplica por fase
para que se sienta **lento → igual → rápido** a medida que pierde vida (0.85 /
1.0 / 1.15). Su código está en la carpeta `mecanicas de jefe/`. Detalles y los
assets que faltarían para pulirlo en [`docs/jefe.md`](docs/jefe.md).

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

La cámara sigue al jugador con suavizado de posición (sin lookahead hacia el
cursor). El zoom se ajusta automáticamente al tamaño de la ventana para
mostrar siempre la misma cantidad de mundo, independientemente de la
resolución.

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
- `Scripts/game_mode.gd`: bucle de juego reutilizable (oleadas, tienda, pantallas, aviso centrado).
- `Scripts/floor_builder.gd`: construye el suelo de césped en el `Ground` (TileMapLayer).
- `Scripts/border_trees.gd`: genera en runtime el anillo de árboles que delimita el DEV-ROOM.
- `Scripts/decoration_scatter.gd`: reparte al azar los obstáculos interiores del DEV-ROOM.
- `Scripts/shop.gd`: tienda con tirada de dados.
- `Scenes/`: `Main` y `DEV-ROOM` (ambas usan `floor_builder` + `GameMode`),
  `GameMode`, `Player`, `spin-bullet`, `Coin`, `Minion`, `BigMinion`,
  `BulletMinion`, `HomingBullet`, `grass_tileset.tres`, `player_frames.tres`.

## DEV-ROOM

Sala de pruebas de **32×32 tiles** (2048×2048 px, tile = 64 px). Incluye:
- Suelo de césped con `TileMapLayer`.
- Decoraciones interiores (árboles, rocas, arbustos, tocones) con colisión,
  colocadas al azar por `decoration_scatter.gd` (mínimo 10 obstáculos),
  evitando una zona segura alrededor del spawn del jugador.
- Anillo de árboles perimetral generado en runtime (`border_trees.gd`) más
  muros invisibles de seguridad, que impiden salir del área de juego.
- El sistema completo de oleadas, tienda y pantallas (mismo `GameMode` que Main).

Ábrela y pulsa **F6** para ejecutarla de forma aislada.

## Documentación

- [`docs/oleadas.md`](docs/oleadas.md): sistema de oleadas y cómo modificarlas/añadirlas.
- [`docs/items.md`](docs/items.md): mejoras de la tienda y cómo agregar nuevas.
- [`docs/jefe.md`](docs/jefe.md): diseño del jefe y assets que faltarían.
