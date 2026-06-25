# Ítems (mejoras de la tienda)

En el juego, los "ítems" son las **mejoras** que se compran en la tienda entre
oleadas. Toda la lógica está en `Scripts/shop.gd` (escena: el nodo `Shop` dentro
de `Scenes/GameMode.tscn`).

## Cómo funcionan

- Cada ítem es un **diccionario** dentro del array `_pool` de `shop.gd`:

  ```gdscript
  {"name": "Daño de bala +1", "cost": 8, "icon": icon_damage,
      "apply": func(p): p.upgrade_bullet_damage(1)}
  ```

  - `name`: texto que se muestra en el botón.
  - `cost`: coste en monedas.
  - `icon`: textura (Texture2D) del botón.
  - `apply`: una `Callable` que recibe al jugador `p` y aplica el efecto
    llamando a un método del jugador (`Scripts/billy.gd`).

- Al abrir la tienda (`open()`) se hace una **tirada de dados** (`_roll()`) que
  elige `slots` ítems al azar del pool. El botón **"Tirar dado"** vuelve a
  tirar gastando `reroll_cost` monedas.
- Comprar un ítem (`_on_buy`) gasta monedas con `Game.spend(cost)` y, si hay
  saldo, ejecuta su `apply` sobre el jugador.

La economía es global: el autoload **`Game`** (`Scripts/game.gd`) guarda las
monedas y emite `coins_changed`. Las monedas las sueltan los enemigos (`coin.gd`).

## Ítems con habilidad especial

Además de los que dan estadísticas, hay 5 ítems que otorgan habilidades. Su
nivel se guarda en el jugador (`billy.gd`) y la lógica vive en el jugador, la
moneda (`coin.gd`) o la SpinShot (`spin_bullet.gd`).

| Ítem | Efecto | Acumulable | Dónde está la lógica |
|------|--------|-----------|----------------------|
| Robo de vida | 25% por nivel de curar 1–3 al recoger una moneda (máx 75%) | hasta 3 | `billy.on_coin_collected()` + `coin.gd` |
| Rebote ofensivo | Al impactar genera N SpinShots que **ignoran al enemigo de origen** y golpean a OTROS, en **reacción en cadena** con presupuesto decreciente (cada eslabón genera uno menos, así la cadena termina) | hasta 3 | `spin_bullet._spawn_bounce()` + `_ignore_enemy` |
| División de proyectil | A mitad de trayectoria la SpinShot se divide en dos (afecta a ambos clics y a las generadas por rebote) | única | `spin_bullet._spawn_split()` |
| Giro letal | 1% por nivel de matar al enemigo haciéndolo girar (reemplaza el daño) | ilimitado | `spin_bullet._on_body_entered` + `enemy.apply_lethal_spin()` |
| Esquiva automática | 25% por nivel de activar el dodge al recibir daño (máx 75%) | hasta 3 | `billy.take_damage()` |

Las SpinShots llevan estas habilidades como variables (`bounce_count`,
`has_split`, `lethal_chance`, `bullet_scene`), que `billy._shoot_spin_bullet()`
copia al crear cada bala. Como las balas se replican a sí mismas, la habilidad
de división también afecta a las creadas por el rebote.

## Cascos (sistema de ítems con desbloqueos persistentes)

Los **cascos** son una familia de ítems de la tienda con efectos que **se
acumulan** con el resto de mejoras (ver "QA: acumulación" más abajo). Su lógica
vive en `billy.gd` (sección "CASCOS").

| Casco | Efecto | Notas |
|-------|--------|-------|
| Casco de minion (`basic_helmet`) | −1 vida máx., +2 daño; +distancia de esquive y −enfriamiento de esquive | Siempre disponible |
| Casco de caballero (`soldier_helmet`) | +5 vida máx., +3 daño; −20 velocidad y +enfriamiento de esquive | Siempre disponible |
| Casco vikingo (`viking_helmet`) | −3 vida, +5 daño; +10% de **empujar** a los enemigos que tocan el `PushArea` del jugador. Acumulable hasta 50%. Pasado el tope: +1 vida y +3 daño por compra | El empuje usa `body.push()` (como el Cargador) |
| Casco de capitán (`capitan_helmet`) | +10 vida máx., +5 daño; **frenesí** (+velocidad y +daño) cuando la vida baja del 50% | **Desbloqueable** al derrotar a un `Bigminion_capitan`. Compra única (`max:1`) |
| Casco de gran capitán (`grancapitan_helmet`) | +15 vida máx., +10 daño; **invoca 4 `Bigminion_capitan` ALIADOS** | **Desbloqueable** al derrotar al minijefe `Bigminion_gran_capitan`. Compra única (`max:1`) |

### Desbloqueos persistentes

- Los desbloqueos se guardan en disco con el autoload `Game`
  (`Scripts/game.gd`) en `user://spinshot_save.cfg` (sección `[unlocks]`).
- `Game.unlock(id)` marca el desbloqueo (lo llaman `bigminion_capitan._die()` y
  `miniboss._die()`); `Game.is_unlocked(id)` lo consulta.
- `Game.reset()` (al empezar partida) **NO** borra los desbloqueos: una vez
  ganados, están disponibles en **todas** las partidas futuras.
- En la tienda, un ítem con el campo `"unlock": "<id>"` solo aparece si ese
  desbloqueo está activo (`shop._is_available`). Con `"max":1` solo puede
  comprarse **una vez por partida**.

### Aliados del casco de gran capitán

`billy._summon_ally_capitanes()` instancia 4 `BigminionCapitan` con
`is_ally = true`. En ese modo el capitán: sale del grupo `enemy` y entra en
`ally`, su `collision_layer = 0`, se tiñe de **azul**, persigue y golpea a los
**enemigos** (no al jugador) y **no** puede invocar Bigminión. El indicador de
aparición se muestra en **azul** (`Game.INDICATOR_ALLY`) para distinguir las
invocaciones aliadas de las enemigas (rojo, `Game.INDICATOR_ENEMY`).

### QA: acumulación de efectos (sin sobrescribir)

Los efectos de cascos e ítems **se suman** y no se pisan entre sí:

- Las mejoras (vida, daño, velocidad, dash) modifican **campos base** de forma
  aditiva (`modify_max_health`, `bullet_damage += …`, etc.).
- El **frenesí** del casco de capitán es un **multiplicador/bonus aparte**
  (`_frenzy_speed_mult`, `_frenzy_damage_bonus`) que se aplica en el punto de
  uso (movimiento y disparo), por lo que convive con los ítems de velocidad y
  cadencia sin sobrescribir sus valores base.

## Límites de compra (campo `max`) e inventario

Cada ítem del pool tiene un campo `"max"` (número máximo de compras; **0 = ilimitado**):

- Los ítems de **compra única** usan `"max": 1` (p. ej. *División de proyectil*).
- Los **acumulables** usan su tope (`coinheal`, `bounce`, `autododge` → `"max": 3`).
- Los de estadística o sin tope usan `"max": 0`.

La tienda solo ofrece ítems **disponibles** (`_is_available`): los que ya
alcanzaron su `max` **no vuelven a salir** ni al abrir la tienda ni al usar el
dado.

Al **comprar** una carta, esta **desaparece** y deja un hueco vacío en la
tienda (`_on_buy` pone `_current[index] = null`). La tienda **no se repone
automáticamente**: para conseguir nuevas cartas hay que usar el botón **ROLL**
(`_on_reroll`), que paga su coste y genera un nuevo conjunto de opciones.

Cada compra se registra en el inventario del jugador (`billy.register_item`),
que la **UI de inventario** (ESC) muestra con su sprite, cantidad/nivel y un
tooltip con nombre, descripción y efectos. Para que un ítem aparezca bien en el
inventario, su entrada del pool debe tener `id`, `name`, `desc` e `icon`.

## Efectos disponibles en el jugador

Los `apply` llaman a métodos de `billy.gd`. Los actuales:

| Método | Efecto |
|--------|--------|
| `upgrade_max_health(n)` | Sube vida máxima y cura `n`. |
| `upgrade_bullet_damage(n)` | +`n` daño por Spin-Bullet. |
| `upgrade_speed(n)` | +`n` velocidad de movimiento. |
| `upgrade_fire_rate(factor)` | Reduce el cooldown de disparo (`factor` < 1). |
| `add_coin_heal()` | +1 nivel de robo de vida (máx 3). |
| `add_bounce()` | +1 SpinShot de rebote (máx 3). |
| `enable_split()` | Activa la división de proyectil. |
| `add_lethal()` | +1% de giro letal (ilimitado). |
| `add_autododge()` | +1 nivel de esquiva automática (máx 3). |
| `modify_max_health(n)` | Suma/resta vida máxima (al subir cura; al bajar no, mín 1). |
| `reduce_dodge_cooldown(s)` / `increase_dodge_cooldown(s)` | Ajustan el enfriamiento del esquive (mín 0.2 s). |
| `increase_dodge_distance(n)` | +`n` a la velocidad del dash (más "distancia" de esquive). |
| `add_basic_helmet()` / `add_soldier_helmet()` / `add_viking_helmet()` / `add_capitan_helmet()` / `add_grancapitan_helmet()` | Aplican los cascos (ver tabla de cascos). |

> Los ítems **Chanclas** (`speed`) ahora también **reducen** el enfriamiento de
> esquive, y el **Gatillo veloz** (`firerate`) además da algo de velocidad y
> distancia de esquive.

## Cómo agregar un ítem nuevo

### Caso A: usa un efecto ya existente
1. Abre `Scripts/shop.gd` → `_build_pool()`.
2. Añade un diccionario al array `_pool` con `name`, `cost`, `icon` y `apply`.
   - Para el `icon` puedes reutilizar uno de los exportados
     (`icon_health`, `icon_damage`, `icon_speed`, `icon_firerate`,
     `icon_extra1`, `icon_extra2`).

### Caso B: necesita un efecto nuevo
1. Añade el método de mejora en `Scripts/billy.gd`
   (sección "MEJORAS"), por ejemplo:
   ```gdscript
   func upgrade_dodge_cooldown(factor: float) -> void:
       dodge_cooldown_time = maxf(0.1, dodge_cooldown_time * factor)
       dodge_cooldown.wait_time = dodge_cooldown_time
   ```
2. Crea el ítem en `_build_pool()` con `"apply": func(p): p.upgrade_dodge_cooldown(0.85)`.

### Si quieres un icono nuevo
1. El icono es un `Texture2D` (los actuales son `UI Elements/.../Icons/Icon_0X.png`).
2. Añade un `@export var icon_nuevo: Texture2D` en `shop.gd`.
3. Asigna la textura en el nodo `Shop` dentro de `Scenes/GameMode.tscn`.
4. Úsalo como `"icon": icon_nuevo` en el ítem.

## Archivos y recursos a modificar (resumen)

| Quiero… | Archivos a tocar |
|---------|------------------|
| Cambiar coste/nombre/efecto de un ítem | `Scripts/shop.gd` (`_build_pool`) |
| Efecto nuevo sobre el jugador | `Scripts/billy.gd` + `Scripts/shop.gd` |
| Icono nuevo | `Scripts/shop.gd` (export) + `Scenes/GameMode.tscn` (asignar) |
| Cuántas opciones se ven / coste del dado | `Scripts/shop.gd` (`slots`, `reroll_cost`) |
