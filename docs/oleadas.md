# Sistema de oleadas

El bucle de oleadas vive en `Scripts/game_mode.gd` (escena reutilizable
`Scenes/GameMode.tscn`, instanciada en `Main` y `DEV-ROOM`).

## Cómo funciona

1. El jugador pulsa **N** (`start_wave`) para iniciar una oleada.
2. La oleada dura `wave_duration` segundos (60 por defecto), con cuenta atrás
   en pantalla. También se puede terminar antes con **M** (`end_wave`).
3. Mientras la oleada está activa, cada `interval` segundos aparece un enemigo
   en un punto aleatorio a `spawn_radius` píxeles alrededor del jugador.
4. Al terminar la oleada se limpian los enemigos restantes y:
   - si quedan oleadas, se abre la **tienda** y al continuar empieza la siguiente;
   - si era la **última** oleada (`total_waves`, por defecto **10**), aparece el **jefe**.
5. Al derrotar al jefe se muestra la pantalla de **victoria**.

Variables principales (exportadas en el nodo `GameMode`):

| Variable | Significado |
|----------|-------------|
| `total_waves` | Número de oleadas antes del jefe (10). |
| `wave_duration` | Duración de cada oleada en segundos. |
| `spawn_radius` | Distancia a la que aparecen los enemigos. |
| `minion_scene`, `bigminion_scene`, `bulletminion_scene`, `charger_scene`, `support_scene` | Escenas de cada tipo de enemigo. |
| `boss_scene` | Escena del jefe final. |

## Cómo se decide qué enemigos aparecen

La composición de cada oleada está en la función `_build_waves()` como una
**tabla de datos**. Cada entrada del array `_waves` (índice 0 = oleada 1) es un
diccionario:

```gdscript
{"interval": 0.9, "pool": [[minion_scene, 2], [charger_scene, 2], [support_scene, 1]]}
```

- `interval`: segundos entre apariciones en esa oleada (menor = más enemigos).
- `pool`: lista de pares `[escena, peso]`. Al aparecer un enemigo se elige una
  escena al azar **ponderada por su peso** (`_pick_enemy_scene()`).
  En el ejemplo: 40% minion, 40% charger, 20% support.

Las entradas con escena `null` (un tipo sin asignar) se ignoran automáticamente,
así que el juego no falla si falta una escena.

Composición actual (resumen):

| Oleada | Enemigos (pesos) |
|-------:|------------------|
| 1 | Minion |
| 2 | Minion ×3, Cargador ×1 |
| 3 | Minion ×2, BigMinion ×1 |
| 4 | Minion ×2, Cargador ×2 |
| 5 | BigMinion ×2, BulletMinion ×1 |
| 6 | Minion ×2, Cargador ×2, Apoyo ×1 |
| 7 | BulletMinion ×2, BigMinion ×1, Apoyo ×1 |
| 8 | Cargador ×2, BigMinion ×2, BulletMinion ×1 |
| 9 | Mezcla de todos |
| 10 | Mezcla intensa de todos → luego **Jefe** |

## Cómo modificar o agregar oleadas

1. **Cambiar la composición** de una oleada: edita su entrada en `_build_waves()`
   (pesos, tipos, `interval`).
2. **Añadir más oleadas**: agrega más diccionarios al array `_waves` y sube
   `total_waves` al nuevo total. Si `wave_number` supera el tamaño de `_waves`,
   se reutiliza la última entrada (clamp), así que conviene que coincidan.
3. **Añadir un tipo de enemigo nuevo a las oleadas**:
   - Crea su escena (ver un enemigo existente como plantilla, p. ej.
     `Scenes/ChargerMinion.tscn`).
   - Añade un `@export var nuevo_scene: PackedScene` en `game_mode.gd`.
   - Asígnalo en `Scenes/GameMode.tscn`.
   - Úsalo dentro de los `pool` de `_build_waves()`.

> Nota: los enemigos deben estar en el grupo `"enemy"` (lo hace `enemy.gd` en
> `_ready`) para que las Spin-Bullets los dañen y el sistema los limpie.
