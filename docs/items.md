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

## Efectos disponibles en el jugador

Los `apply` llaman a métodos de `billy.gd`. Los actuales:

| Método | Efecto |
|--------|--------|
| `upgrade_max_health(n)` | Sube vida máxima y cura `n`. |
| `upgrade_bullet_damage(n)` | +`n` daño por Spin-Bullet. |
| `upgrade_speed(n)` | +`n` velocidad de movimiento. |
| `upgrade_fire_rate(factor)` | Reduce el cooldown de disparo (`factor` < 1). |

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
