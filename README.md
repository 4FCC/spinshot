# spinshot

Juego para una JAM cuyo tema principal es **GIRAR**.

Prototipo funcional con movimiento básico y esquive. El esquive hace que el
personaje **gire sobre sí mismo** mientras es invulnerable (de ahí el tema).
Se usa el sprite genérico de Godot (`icon.svg`) como marcador de posición.

## Controles

- **WASD / Flechas**: mover
- **Espacio**: esquivar (gira y da invulnerabilidad breve, con cooldown)
- **K**: recibir daño (para probar el estado de daño)

## Estructura

- `Scripts/billy.gd`: personaje con máquina de estados (movimiento, esquive,
  recibir daño y muerte).
- `Scenes/Main.tscn`: escena principal con el jugador y la UI (barra de vida y
  barra del esquive que indica si ya se puede usar).
