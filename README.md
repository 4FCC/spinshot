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
- **K**: recibir daño (prueba)

## Bucle de juego

1. En la **pantalla de inicio** pulsa JUGAR.
2. Pulsa **N** para iniciar una oleada (dura **60 s**, con cuenta atrás en pantalla).
3. Mata enemigos con las Spin-Bullets; cada enemigo suelta **monedas** al morir.
4. La oleada termina a los 60 s (o antes con **M**): se abre la **tienda**.
5. Compra mejoras (o usa **Tirar dado** para cambiar las opciones) y pulsa **Continuar**:
   la siguiente oleada empieza automáticamente.
6. Al superar la última oleada aparece la **pantalla de victoria**; si mueres, la
   **pantalla de muerte**. Ambas permiten reiniciar.

Todo el bucle (oleadas, tienda y pantallas) funciona tanto en **Main** como en
**DEV-ROOM**, porque vive en una escena reutilizable `GameMode.tscn`.

### Etapas (oleadas)

- **Etapa 1** — solo **Minions** (frecuentes).
- **Etapa 2** — solo **BigMinions** (menos frecuentes).
- **Etapa 3** — solo **BulletMinions** (aún menos frecuentes).

## Enemigos

- **Minion** (Red Pawn): básico, cuerpo a cuerpo. Vida 6, daño 2.
- **BigMinion** (Red Warrior): más resistente (vida 12, daño 4). Para a 60 px del jugador.
- **BulletMinion** (Red Archer): no ataca cuerpo a cuerpo; mantiene la distancia y
  dispara un **proyectil teledirigido**. Vida 12, daño 2 por proyectil.

Los enemigos se empujan entre sí para no apilarse, formando un muro peligroso
cuando llegan en masa.

## Tienda

Muestra 4 mejoras tomadas al azar de un pool (vida +5/+10, daño +1/+2,
velocidad +40, cadencia +15%). El botón **Tirar dado** cambia las opciones por
monedas. Costes y efectos son configurables en `shop.gd`.

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
- `Scripts/homing_bullet.gd`: proyectil teledirigido del BulletMinion.
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
