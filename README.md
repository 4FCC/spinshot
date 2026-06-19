# spinshot

Juego para una JAM cuyo tema principal es **GIRAR**.

La mecánica central es la **Spin-Bullet**: una bala que el jugador dispara y que
empieza a **orbitar** a su alrededor describiendo una espiral hacia afuera.

Se usan las animaciones del Pawn del pack *Tiny Swords (Free Pack)* para el
movimiento del jugador.

## Controles

- **WASD / Flechas**: mover
- **Espacio**: esquivar (gira sobre sí mismo + invulnerabilidad breve, con cooldown)
- **Clic derecho**: disparar la **Spin-Bullet** (orbita al jugador)
- **K**: recibir daño (para probar el estado de daño)

## Estructura del proyecto

- `Scripts/billy.gd`: personaje con máquina de estados (movimiento, esquive,
  recibir daño, muerte), animaciones del Pawn y disparo de la Spin-Bullet.
- `Scripts/spin_bullet.gd`: bala que orbita al jugador. Se inicializa con
  `setup(jugador, direccion)` o asignando `player_path` en el editor.
- `Scripts/dev_room.gd`: genera el suelo de césped del DEV-ROOM por código
  usando el `TileMapLayer`.
- `Scenes/Player.tscn`: jugador reutilizable (sprite animado, cámara, colisión
  y HUD). Se instancia tanto en `Main` como en `DEV-ROOM`.
- `Scenes/spin-bullet.tscn`: escena de la Spin-Bullet.
- `Scenes/player_frames.tres`: animaciones idle/run del Pawn.
- `Scenes/grass_tileset.tres`: TileSet de césped (Tiny Swords) para el tilemap.
- `Scenes/Main.tscn`: escena principal del juego.
- `Scenes/DEV-ROOM.tscn`: sala de pruebas con entorno hecho con TileMap y
  decoraciones (árboles, rocas, arbustos) para probar mecánicas.

## DEV-ROOM

Escena pensada para probar mecánicas, objetos y funcionalidades durante el
desarrollo. El suelo se construye con un `TileMapLayer` + el tileset de césped,
y se añaden decoraciones del pack. Para abrirla en el editor, ábrela y pulsa
**F6** (Ejecutar escena actual).
