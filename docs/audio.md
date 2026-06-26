# Audio (música y efectos de sonido)

El audio se reparte en dos capas con buses dedicados, controlables desde el
menú **ESC → Sonido**:

- **Música** → bus `Music`. La reproducen los `AudioStreamPlayer` del
  `GameMode` (`Scenes/GameMode.tscn`).
- **Efectos (SFX)** → bus `SFX`. Los reproduce el autoload **`Audio`**
  (`Scripts/audio.gd`) desde un *pool* reutilizable.

Los buses se definen en `default_bus_layout.tres` (Master → Music, SFX) y se
cargan vía `project.godot` (`[audio] buses/default_bus_layout`).

## Música por estado (en `game_mode.gd`)

| Momento | Pista | Nodo |
|---------|-------|------|
| Rondas normales / tienda | `maksymmalko-…` (celta) | `MusicBase` |
| **Minijefe (ronda 10)** | `ob-lix-…` (batalla) | `MusicBoss1` |
| Jefe final | `junipersona-…` | `MusicBoss2` |

`_play_music(p)` detiene las demás y reproduce `p`. La **ronda 10** llama a
`_start_miniboss_wave()` → `_play_music(_music_boss1)` **antes** de invocar al
minijefe (verificado: al llegar a la ronda 10 suena `MusicBoss1` y se detiene
`MusicBase`).

## Gestor de SFX (`Scripts/audio.gd`, autoload `Audio`)

`Audio.play(key, pitch_var = 0.0, min_interval_ms = 0, volume_db = 0.0)`:

- Reutiliza un **pool** de `AudioStreamPlayer` (no crea un nodo por evento).
- `pitch_var`: variación aleatoria de tono (±) para que no suene mecánico.
- `min_interval_ms`: **anti-saturación**. Si el mismo `key` sonó hace menos de
  ese tiempo, se omite (evita 20 sonidos idénticos simultáneos).

### Catálogo y dónde se dispara

| key | Evento | Lugar |
|-----|--------|-------|
| `ui_click` | Clic en botones de UI | `game_mode` (`_make_rect_button`, `_make_esc_button`), `shop._on_continue` |
| `buy` | Compra exitosa | `shop._on_buy` |
| `denied` | Acción inválida (sin monedas, carta no disponible) | `shop._on_buy`, `_on_reroll` |
| `reroll` | Botón ROLL | `shop._on_reroll` |
| `hit` | SpinShot golpea a un enemigo (incluye las de rebote) | `spin_bullet._on_body_entered` |
| `coin` | Recoger moneda (pitch+debounce anti-saturación) | `coin.gd` |
| `dodge` | Esquive manual y automático | `billy.start_dodge` |
| `lethal` | Muerte instantánea del ítem letal | `spin_bullet._on_body_entered` |
| `teleport_enemy` | Teletransporte de la gótica | `bullet_minion_gotica` |
| `teleport_boss` | Teletransporte del jefe | `boss.gd` |
| `sad_eat` | El sad elimina una SpinShot | `bullet_minion_sad` |
| `charge_push` | El Cargador embiste/empuja (1 por contacto) | `charger_minion` |
| `support` | Habilidad del Apoyo | `support_minion` |
| `buff` | Enemigo recibe buff del **Capitán** (1 por grupo, debounce) | `bigminion_capitan` |

> Anti-saturación destacada: **monedas** (pitch ±18% + debounce), **buff** del
> capitán (debounce 700 ms → un solo sonido aunque se potencien 20 a la vez) y
> **empuje** del cargador (1 por contacto). El buff del **Apoyo** NO usa el
> sonido de buff (tiene el suyo, `support`).

## Menú Sonido (ESC → Sonido)

`game_mode._build_sound_box()` crea dos canales (Música y Efectos), cada uno con:

- Un **interruptor** (CheckButton) para silenciar/activar.
- Un **deslizador** (HSlider, 0–100%) de volumen.

Los cambios llaman a `Audio.set_music_enabled/volume` y `set_sfx_enabled/volume`,
que aplican mute/volumen al bus correspondiente y **persisten** en
`user://spinshot_audio.cfg`.

## Notas técnicas

- Los SFX usan `AudioStreamPlayer` (no posicional): la cámara sigue al jugador,
  así que la acción ocurre centrada; evita el coste de espacialización 2D y de
  crear/destruir nodos.
- Los `.wav` del pack venían en 24 bits/96 kHz, que el importador de Godot
  rechaza; se reconvirtieron a **PCM 16 bits** para que importen correctamente.
- El SFX de **disparo** (`mixkit-thin-icicles-spell-882.wav`) se **retiró** del
  repositorio por problemas con el archivo de origen. La llamada `Audio.play("shoot")`
  queda inerte hasta que se añada un archivo nuevo y la clave `"shoot"` en `audio.gd`.
