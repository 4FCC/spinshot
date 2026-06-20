# spinshot

Juego para una JAM cuyo tema principal es **GIRAR**.

La mecánica central es la **Spin-Bullet**: una bala que el jugador dispara y que
**orbita** un punto fijo describiendo una espiral hacia afuera. Daña a los
enemigos que atraviesa, pero también puede dañar al propio jugador.

Sobre esa base hay un bucle estilo **Brotato**: oleadas de enemigos, monedas que
sueltan al morir y una tienda de mejoras entre oleadas.

Se usan los assets del pack *Tiny Swords (Free Pack)*.

## Controles

- **WASD / Flechas**: mover
- **Espacio**: esquivar (gira sobre sí mismo + invulnerabilidad breve)
- **Clic derecho**: disparar la **Spin-Bullet**
- **N**: iniciar una oleada
- **M**: terminar la oleada actual (abre la tienda)
- **K**: recibir daño (prueba)

## Bucle de juego

1. Pulsa **N** para iniciar una oleada. Los enemigos aparecen alrededor del jugador.
2. Mata enemigos con las Spin-Bullets; cada enemigo suelta **monedas** al morir.
3. Pulsa **M** para terminar la oleada: se limpian los enemigos y se abre la **tienda**.
4. Compra mejoras con tus monedas y pulsa **Continuar** para preparar la siguiente oleada.

### Etapas (oleadas)

- **Etapa 1** — solo **Minions** (frecuentes).
- **Etapa 2** — solo **BigMinions** (menos frecuentes).
- **Etapa 3** — solo **BulletMinions** (aún menos frecuentes).

## Enemigos

- **Minion** (Red Pawn): básico, cuerpo a cuerpo. Vida 6, daño 2 (1.5× menos que la Spin-Bullet).
- **BigMinion** (Red Warrior): el doble de vida y daño que el Minion (vida 12, daño 4).
- **BulletMinion** (Red Archer): no ataca cuerpo a cuerpo; mantiene la distancia y
  dispara un **proyectil teledirigido**. Vida como el BigMinion (12), daño como el Minion (2).

## Tienda (4 mejoras)

- Vida máxima +5
- Daño de bala +1
- Velocidad +40
- Cadencia de disparo +15%

Se compran con monedas. El coste y los efectos son configurables en `shop.gd`.

## Estructura del proyecto

- `Scripts/billy.gd`: jugador (estados, animaciones, Spin-Bullet, mejoras).
- `Scripts/spin_bullet.gd`: bala que orbita un punto fijo y daña a quien toca.
- `Scripts/enemy.gd`: enemigo base cuerpo a cuerpo (clase `Enemy`).
- `Scripts/bullet_minion.gd`: enemigo a distancia (extiende `Enemy`).
- `Scripts/homing_bullet.gd`: proyectil teledirigido del BulletMinion.
- `Scripts/coin.gd`: moneda recogible.
- `Scripts/game.gd`: singleton (autoload `Game`) con la economía.
- `Scripts/arena.gd`: bucle principal (suelo, oleadas, spawns, UI).
- `Scripts/shop.gd`: tienda entre oleadas.
- `Scripts/dev_room.gd`: suelo del DEV-ROOM por código.
- `Scenes/`: `Main` (arena de juego), `Player`, `spin-bullet`, `Coin`,
  `Minion`, `BigMinion`, `BulletMinion`, `HomingBullet`, `DEV-ROOM`,
  `grass_tileset.tres`, `player_frames.tres`.

## DEV-ROOM

Sala de pruebas (suelo con `TileMapLayer` + decoraciones). Ábrela y pulsa **F6**
para ejecutarla de forma aislada.
