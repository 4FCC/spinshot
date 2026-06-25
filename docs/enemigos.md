# Enemigos, variantes y minijefe

Sprites en `Sprites_Minions/` (hojas de "correr" de 6 fotogramas 64×64). Todos
los enemigos comparten un **efecto de impacto** (oscurecen el sprite de forma
intermitente al recibir daño, `enemy._flash`).

## Enemigos normales (`Scripts/enemy.gd` y subclases)

| Enemigo | Script | Sprite | Mecánica destacada |
|--------|--------|--------|--------------------|
| Minion | `enemy.gd` | `Minion.png` | Persigue al jugador (aparece en todas las rondas). |
| BigMinion | `big_minion.gd` | `BigMinion.png` | Robusto. Recibe **buff de daño y velocidad** dentro del aura del Bigminion_capitan (grupo `bigminion`). |
| BulletMinion | `bullet_minion.gd` | `Sprite_BulletMinion_var1.png` | Dispara `HomingBullet` (orbe verde) con **parpadeo rojo de aviso**; cada cierto tiempo lanza un **patrón circular** de balas que NO siguen al jugador. |
| SupportMinion | `support_minion.gd` | `SupportMinion.png` | Cura y da +daño a aliados. Al usar su habilidad muestra el **efecto de corazones** (`SupportMinion_effet`) sobre los aliados y parpadea en **rosa**. |
| ChargerMinion | `charger_minion.gd` | `ChargerMinion.png` | Embiste; durante la carga **empuja** a otros enemigos que se cruzan. |

## Variantes

| Variante | Script | Sprite | Mecánica |
|----------|--------|--------|----------|
| Bigminion_capitan | `bigminion_capitan.gd` | `Bigminion_var1.png` | Más vida/daño. **Aura** que potencia solo a los Bigminión normales. **Frenesí** (+velocidad) si baja del 25% de vida. Si lo invoca el minijefe, puede invocar 4 Bigminión una vez. |
| Bullet_minion_sad | `bullet_minion_sad.gd` | `Sprite_BulletMinion_var3.png` | Mantiene distancia. Escudo con **25%** de eliminar cada SpinShot que toca; al acumular varias, suelta un **anillo** de `HomingBullet` (no teledirigidas). |
| Bullet_minion_gotica | `bullet_minion_gotica.gd` | `Sprite_BulletMinion_var2.png` | **Teletransporte** frecuente a distancia segura; tras teletransportarse suelta 2 patrones (círculo + triángulo) de `HomingBullet`; luego evade hasta recargar. |

## Minijefe — Bigminion_gran_capitan (Oleada 10)

`Scripts/miniboss.gd` / `Scenes/Miniboss.tscn` (sprite `Bigminion_var2_capitan.png`).
Barra de vida propia y fases:

- **>75%:** embestidas (como el Cargador).
- **<75%:** patrones de `HomingBullet` en **triángulo** y **"X"**.
- **<50%:** invoca 4 `Bigminion_capitan` (que invocan 4 Bigminión una vez); repite cada **30 s**.
- **<25%:** deja de invocar capitanes; invoca 4 `Bullet_minion_sad` **guardianes** (tinte morado). Mientras vivan, **<10%** de anular el daño al minijefe.
- **Oleada 10 sin temporizador:** solo se gana derrotando al minijefe (`game_mode._start_miniboss_wave` / `_on_miniboss_defeated`). Al caer → tienda → jefe final.

## Atajos de desarrollo (solo DEV-ROOM, `debug_mode`)

- **1–5:** maniquíes (no atacan): Minion, BigMinion, BulletMinion, Charger, Support.
- **6:** Bigminion_capitan · **7:** Bullet_minion_sad · **8:** Bullet_minion_gotica · **9:** Minijefe (funcionales, atacan).
- **M/N:** iniciar/terminar oleada · **B:** jefe · **O:** tienda · **C:** +100 monedas · **G:** god mode.
