# Guía de sprites de UI (para dibujarlos a mano)

Este documento lista **cada elemento de interfaz**, su **tamaño en píxeles**, los
márgenes de borde para *9-slice*, y los detalles de formato/importación para que
los hagas en pixel art y encajen sin problemas.

---

## 0. Reglas generales (LEER PRIMERO)

- **Formato: PNG de 32 bits (RGBA, con transparencia).**
  **NO uses JPG**: no admite transparencia y comprime con pérdida (rompe el
  pixel art con halos/artefactos). Siempre PNG.
- **Resolución base del juego: 1280 × 720** (definida en `project.godot →
  [display]`). La UI se dibuja **1:1 en ese espacio**: 1 px de tu sprite = 1 px
  a 720p. En pantalla completa Godot **escala** todo el lienzo (modo
  `canvas_items`), así que no tienes que dibujar a la resolución del monitor.
- **Filtro de textura: Nearest** (sin suavizado) para que el pixel art se vea
  nítido. En Godot: selecciona el PNG → pestaña *Import* → **Filter = Nearest**,
  **Mipmaps = Off**, **Compress Mode = Lossless** → *Reimport*. (El proyecto ya
  fuerza Nearest en los iconos por código, pero ponlo también en el import.)
- **Dos técnicas según el elemento:**
  - **9-slice** (paneles, botones, marcos, barras): dibuja un recuadro
    **pequeño** con esquinas + bordes; Godot lo estira a cualquier tamaño sin
    deformar las esquinas. Indico el **margen de borde** de cada uno.
  - **Tamaño fijo** (iconos, monedas): dibuja al tamaño indicado.
- **Paleta sugerida** (la actual, por coherencia; puedes cambiarla):
  madera oscura `#221710`, madera media `#4D3420`, dorado `#CCA36B`,
  dorado apagado `#75603F`, texto `#F5E8D2`.
- Trabaja en **múltiplos de 2** y deja 1–2 px de margen interno transparente en
  los bordes exteriores para que el 9-slice no recorte el contorno.

---

## 1. Marco / Panel base (9-slice)  ⭐ el más importante

Se usa como fondo de: **tienda, inventario, panel de estadísticas, tarjetas de
ítem, pantallas (inicio/victoria/muerte) y barra del jefe**. Con UN solo marco
9-slice bien hecho se cubre casi toda la interfaz.

- **Lienzo recomendado:** `64 × 64 px`.
- **Margen de borde 9-slice:** `20 px` por lado (esquinas de 20×20; el centro
  de 24×24 es lo que se estira/rellena).
- Borde de madera con filete dorado; centro relleno (puede ser semitransparente,
  alpha ~245/255) o sólido.
- Tamaños a los que se estirará en pantalla (solo de referencia, NO los dibujes
  a ese tamaño):
  - Tienda: **1060 × 596**
  - Panel de inventario: **≈ 440 × 470**
  - Panel de estadísticas: **≈ 240–280 × 300**
  - Tarjeta de ítem: **≈ 200 × 470**
  - Pantallas (inicio/muerte/victoria): **se ajusta al contenido** (~460 × 320)

> Opcional: si quieres variantes, haz un segundo marco "oscuro/sólido" para las
> tarjetas y otro "resaltado" (borde dorado más brillante) para el ítem
> seleccionado. No es obligatorio.

---

## 2. Botones (9-slice, 4 estados)

Botones: COMPRAR, REROLL, CONTINUAR, JUGAR/REINTENTAR.

- **Lienzo recomendado por estado:** `48 × 24 px`.
- **Margen de borde 9-slice:** `8 px` por lado.
- Haz **4 archivos** (mismas dimensiones), uno por estado:
  1. `boton_normal.png`
  2. `boton_hover.png` (cursor encima — un poco más claro)
  3. `boton_pressed.png` (pulsado — un poco más oscuro/hundido)
  4. `boton_disabled.png` (deshabilitado — apagado/grisáceo)
- Tamaños en pantalla a los que se estiran (referencia):
  - REROLL: 220 × 48 · CONTINUAR: ancho × 50 · COMPRAR: ancho de tarjeta × 44 ·
    Botón de pantalla (JUGAR/REINTENTAR): 240 × 54.
- El **texto lo pone el motor** encima; no escribas texto en el sprite.

---

## 3. Barras de progreso (vida, esquive, jefe)

Cada barra necesita **2 piezas** (y, opcional, un marco):
- **Fondo (under):** la ranura vacía.
- **Relleno (fill):** la parte llena (se recorta según el %).

Recomendado para todas (9-slice horizontal):
- **Lienzo:** `32 × 16 px` cada pieza.
- **Margen de borde 9-slice:** `6 px` izquierda/derecha, `6 px` arriba/abajo.

Barras y su tamaño/color en pantalla:
| Barra | Tamaño en pantalla | Color del relleno | Notas |
|-------|--------------------|-------------------|-------|
| Vida (HUD) | **300 × 32** | rojo | esquina sup-izq. |
| Esquive (HUD) | **300 × 32** | claro/cian | debajo de la vida |
| Jefe | **600 × 28** | rojo | borde inferior, centrada |

Puedes reutilizar el mismo fondo para las tres y solo cambiar el color del
relleno. El **texto** ("Vida: 20/20", etc.) lo dibuja el motor encima.

---

## 4. Casilla de ítem del inventario (tamaño fijo)

Recuadro donde va el sprite de cada ítem comprado, en la rejilla del inventario.

- **Tamaño exacto:** `80 × 80 px` (dibújalo a ese tamaño, NO 9-slice).
- Marco/hueco de madera; el sprite del ítem (64×64) se centra dentro con ~6 px
  de aire por lado.
- Opcional: una versión "vacía" y otra "con borde dorado" (seleccionado).

---

## 5. Iconos de ítems (tamaño fijo)  — ya los tienes, referencia

Ya existen en `Items assets/` (uno por ID). Si rehaces alguno:
- **Tamaño recomendado:** `64 × 64 px` (también vale 32×32; se escalan con
  Nearest y se ven nítidos).
- Fondo **transparente**.
- IDs/archivos actuales: `Poción_de_vida_5`, `Poción_dev_vida_10`,
  `item_de_daño1`, `Item_de_Daño2`, `Item_de_velocidad`,
  `Item_cadecia_de_tiro`, `Item_paytowin` (robo de vida), `Item_bounce`,
  `Item_split`, `Item_lethal`, `Item_autododge1`.

---

## 6. Icono de moneda (tamaño fijo)

Para mostrar junto a los precios/monedas ("204 monedas", "REROLL (9)").

- **Tamaño recomendado:** `24 × 24 px` (o 32×32).
- Fondo transparente. Una sola imagen (sin animación) basta; opcional 4–6
  fotogramas en tira horizontal si quieres que gire.

---

## 7. Cursor (opcional)

Si quieres un puntero personalizado:
- **Tamaño:** `32 × 32 px`, con la punta activa en la esquina sup-izq.
- PNG con transparencia.

---

## Resumen rápido de tamaños

| Elemento | Tipo | Lienzo a dibujar | 9-slice (borde) |
|----------|------|------------------|------------------|
| Marco/panel base | 9-slice | 64 × 64 | 20 px |
| Botón (×4 estados) | 9-slice | 48 × 24 | 8 px |
| Barra: fondo | 9-slice | 32 × 16 | 6 px |
| Barra: relleno | 9-slice | 32 × 16 | 6 px |
| Casilla de ítem | fijo | 80 × 80 | — |
| Icono de ítem | fijo | 64 × 64 | — |
| Icono de moneda | fijo | 24 × 24 | — |
| Cursor (opcional) | fijo | 32 × 32 | — |

**Mínimo imprescindible** para renovar toda la UI: **#1 (marco)**, **#2 (botón,
4 estados)** y **#3 (barras)**. Con eso ya cambia el 90 % del aspecto.

---

## Dónde colocarlos y cómo se conectan

1. Guarda los PNG en una carpeta, p. ej. `UI assets/` (o `assets/ui/`).
2. En Godot, selecciona cada PNG → *Import* → Filter **Nearest**, Mipmaps
   **Off**, Compress **Lossless** → *Reimport*.
3. Avísame cuando estén y los **cableo en el código**:
   - Hoy la UI se estiliza por código en `Scripts/ui_theme.gd` con
     `StyleBoxFlat` (colores planos). Cambiaré esos `StyleBoxFlat` por
     **`StyleBoxTexture`** (paneles/botones, con sus márgenes 9-slice) y las
     barras a **`TextureProgressBar`** (fondo + relleno).
   - Como todo pasa por `UiTheme`, tocar ese único archivo actualiza tienda,
     inventario, estadísticas y pantallas a la vez.

> Si prefieres, en vez de pasarme los archivos sueltos puedes meterlos en una
> sola lámina (atlas) y me dices las coordenadas; pero archivos separados es lo
> más cómodo para el 9-slice.

---

## Apéndice: sprites descargados ya integrados (no hay que dibujarlos)

Estos assets externos ya están conectados en el código y las escenas:

### Barras de vida y esquiva — `UI assets/04.png` (336×240)
Lámina de barras en 4 colores × 3 estilos. Se usa el estilo redondeado:
- **Vida (rojo):** región `Rect2(57, 131, 32, 11)`.
- **Esquiva (azul):** región `Rect2(57, 147, 32, 11)`.

En `Scenes/Player.tscn` las barras son `TextureProgressBar` con
`nine_patch_stretch` (márgenes 6/4/6/4). El **fondo** de ambas es el sprite
`Rectangulo_UI_Para_texto` recortado a su marco `Rect2(18, 23, 108, 39)`.

### SpinShots — `ASSET_SPINBULLET/Bullet 24x24 Free  Part 1B.png` (576×360, celdas 24×24)
- **Clic derecho (azul):** fila 0, fotogramas 0–7 (orbe giratorio).
- **Clic izquierdo (naranja):** fila 10, fotogramas 0–7.

Recurso de animación: `Scenes/spin_bullet_frames.tres` (animaciones `blue` y
`orange`, en bucle a 14 fps). Lo reproduce `Scripts/spin_bullet.gd`
(`_apply_visual`) según el patrón del disparo.

### Efectos de partículas — `asset_particulas_efectos/` (celdas 64×64)
Animación de un solo uso:
- **`25.png` (896×576) → "dust":** nube de polvo gris de la **esquiva
  automática** (fila 5, fotogramas 0–11).
- **`486.png` (768×576) → "burst":** estallido **azul** de **división** y
  **rebote** de proyectil (fila 2, la variante azul que combina con las
  SpinShots; fotogramas 1–10).

Recurso: `Scenes/effect_frames.tres`; escena reutilizable `Scenes/Effect.tscn`
(`Scripts/effect.gd`) que reproduce la animación y se autodestruye al terminar.

### Indicador de aparición — `UI assets/Spritesheet_UI_Flat_Animated.png` (128×128)
La lámina son celdas de 16×16; cada bloque de **32×32** (2×2 celdas) es un marco
de **4 esquinas** (reticle). Se usa la **animación de retícula** (NO la caja
rellena): bloques `y=0`, fotogramas en `x = 0, 32, 64, 96` (las esquinas laten
hacia dentro y fuera), en bucle. Recurso `Scenes/spawn_indicator_frames.tres`,
escena `Scenes/SpawnIndicator.tscn` (`Scripts/spawn_indicator.gd`). El color
**rojo** se aplica por código (`INDICATOR_COLOR` en `game_mode.gd`), con un pulso
de escala para que destaque.
