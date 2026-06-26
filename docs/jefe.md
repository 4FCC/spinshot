# Jefe final

Código en la carpeta **`mecanicas de jefe/`**:
- `boss.gd` — máquina de estados del jefe.
- `boss_bullet.gd` + `BossBullet.tscn` — proyectil recto para las voleas.
- `Boss.tscn` — escena del jefe (sprite, colisión, hitbox y barra de vida).

Diseño **original** inspirado (no copiado) en los scripts de referencia de
`mecanicas de jefe/*.txt` (Follow / Attack / Teleport / SpawnMinion / Death).

## Cómo aparece

- **Automático**: al terminar la **oleada 10** (`total_waves`), `game_mode.gd`
  llama a `_spawn_boss()` en vez de abrir la tienda.
- **Depuración**: pulsar **B** (`spawn_boss`) invoca al jefe en cualquier momento
  para pruebas. Funciona en `Main` y en `DEV-ROOM`.
- Al derrotarlo, el jefe emite la señal `died` y el GameMode muestra la
  pantalla de **victoria**.

## Máquina de estados (`boss.gd`)

Estados: `FOLLOW`, `ATTACK`, `TELEPORT`, `SPAWN`, `RANGED`, `DEAD`.

- **FOLLOW**: persigue al jugador. Si está cerca → `ATTACK`. Cada cierto tiempo
  decide una acción especial (`_choose_special`) según la fase.
- **ATTACK**: telegrafía (cambio de color) y luego da un golpe de área (`_do_slam`)
  que daña al jugador si está dentro de `slam_radius`. En fases altas suelta balas.
- **TELEPORT (absorbente)**: al desvanecerse **absorbe/elimina TODOS los
  proyectiles activos** en pantalla (del jugador, grupo `spin_bullet`, y de los
  enemigos, grupo `enemy_projectile`). Reaparece junto al jugador (posición
  **acotada al mapa**, ver más abajo) y, si absorbió proyectiles, los **devuelve
  todos de golpe** en una tormenta de dos anillos (`_unleash_absorbed`, con tope
  `absorb_cap`). Si no absorbió nada, encadena un ataque o volea.
- **SPAWN (masivo y variado)**: invoca `spawn_count` enemigos eligiendo al azar
  de `summon_scenes` (Minion, BigMinion, Cargador, BulletMinion). Cae al
  `minion_scene` si el array está vacío.
- **RANGED**: dispara una volea radial de `BossBullet` (doble anillo en fase 3).
  Las voleas son **más frecuentes** (menor `decide_interval`, más peso a
  "ranged" en `_choose_special`).
- **DEAD**: suelta monedas, emite `died` y se elimina.

### Fase crítica (<25% vida)
Una sola vez, el jefe invoca `critical_support_count` **SupportMinion** con
`heal_target = self`. En ese modo el Apoyo (ver `support_minion.gd`) **no
potencia a otros enemigos**: sigue al jefe y le **cura lentamente la barra de
vida** (`boss_heal_amount` por tick) mientras siga vivo. El jefe expone
`heal(amount)` para recibir esa curación.

### Clamp del teletransporte (corrección de bug)
El destino del teletransporte se acota con `_clamp_to_arena()` a
`ARENA_MIN (70,70)`–`ARENA_MAX (1850,1082)`, igual que el resto de enemigos, para
que el jefe **nunca reaparezca fuera del mapa** aunque el jugador lo arrincone.

### Fases por vida
- **Fase 1** (>66%): perseguir + golpe; teletransportes ocasionales.
- **Fase 2** (33–66%): añade invocación de minions y voleas de proyectiles.
- **Fase 3** (<33%): enfurecido: más rápido, más teletransportes y voleas dobles.
- **<25%**: además invoca los SupportMinion curanderos (ver "Fase crítica").

Parámetros configurables en el inspector del nodo `Boss` (vida, velocidad,
daños, número de minions, número de balas, monedas, etc.).

## Assets usados / colocación

- **Cuerpo del jefe**: se reutiliza el **Black Warrior** de *Tiny Swords*
  (`Units/Black Units/Warrior/Warrior_Idle.png` y `_Run.png`), escalado x1.6.
  Las animaciones `idle`/`run` se construyen en runtime desde esas hojas.
- **Proyectil**: se reutiliza `Arrow.png` del Archer.
- **Minions invocados**: se reutiliza `Scenes/Minion.tscn`.
- **Barra de vida**: `ProgressBar` en un `CanvasLayer` dentro de `Boss.tscn`.

## Assets que faltan (placeholders actuales)

El pack *Tiny Swords (Free Pack)* solo trae **idle** y **run** para las unidades,
así que las siguientes mecánicas se representan con **tintes/escala** como
placeholder. Para terminar el jefe harían falta estos recursos:

| Mecánica | Placeholder actual | Asset que se necesita |
|----------|--------------------|------------------------|
| Golpe (`ATTACK`) | tinte naranja/rojo | hoja de animación "attack/slam" del jefe + VFX de onda de impacto |
| Teletransporte (`TELEPORT`) | fundido de transparencia | VFX de aparición/desaparición (humo/portal) |
| Invocación (`SPAWN`) | tinte morado | animación "summon" + VFX de invocación |
| Volea (`RANGED`) | tinte azul | sprite propio de proyectil del jefe (ahora usa la flecha) |
| Muerte (`DEAD`) | desaparece al instante | animación "death" del jefe |
| Retrato/identidad | Label "JEFE FINAL" | sprite de jefe dedicado (idealmente más grande que una unidad normal) |

> Si se prefiere un marcador genérico en vez del Black Warrior, puede asignarse
> `icon.svg` (imagen básica de Godot) como hoja en los campos `idle_sheet` /
> `run_sheet` del nodo `Boss` con `idle_frames = 1`, `run_frames = 1` y
> `frame_size = 128`.

## Cómo ajustar o extender

- **Dificultad**: edita los `@export` del nodo `Boss` (`max_health`, `move_speed`,
  `slam_damage`, `ranged_count`, etc.).
- **Nuevos ataques**: añade un valor al enum `S`, su rama en el `match` de
  `_physics_process`, una función `_state_xxx(delta)` y enlázalo desde
  `_choose_special()`.
- **Cambiar cuándo aparece**: en `game_mode.gd`, `_end_wave()` decide el spawn al
  superar `total_waves`; la tecla de depuración está en `_unhandled_input`.
