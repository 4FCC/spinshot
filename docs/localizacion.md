# Localización (idiomas) y resolución

## Idiomas

El juego usa el sistema de traducción de Godot a través del autoload
`Scripts/i18n.gd` (singleton **`I18n`**).

- El **texto fuente está en inglés** y actúa como clave de traducción.
- El **idioma por defecto es inglés** (`I18n.DEFAULT_LOCALE = "en"`).
- El español se registra en `I18n.ES` (mapa `inglés -> español`).
- Cambiar idioma: `I18n.set_language("en" | "es")`. Emite `language_changed`.

### Cómo se actualizan los textos al cambiar de idioma

- **Textos estáticos** (botones, títulos, etc.): se asigna el texto **en inglés**
  al `text` del Control. Godot los **auto-traduce** automáticamente al cambiar el
  idioma (no hay que hacer nada más).
- **Textos con formato** (con `%d`, `%s`, etc.): se usan con
  `tr("Coins: %d") % total` y se **refrescan** al recibir `I18n.language_changed`
  (ver `game_mode._on_language_changed`, `shop._refresh`). El HUD del jugador
  (`billy.gd`) usa `tr(...)` cada frame, así que se actualiza solo.

### Cómo añadir una cadena nueva

1. Escribe el texto **en inglés** en el código (en `text` o con `tr(...)`).
2. Añade la entrada `"texto inglés": "texto español"` en `I18n.ES`.

### Cómo añadir otro idioma

1. Crea otro diccionario (p. ej. `FR`) en `i18n.gd`.
2. Regístralo en `_ready()` con un `Translation` cuyo `locale` sea el código.
3. Añádelo a `LOCALES` y crea su botón en el submenú **Idioma**.

## Resolución

En el menú **ESC → Resolution** el jugador puede elegir el tamaño de ventana:
**1280×720, 1366×768, 1600×900, 1920×1080** o **Fullscreen**.

- `game_mode._apply_resolution(size)` pone la ventana en modo ventana, ajusta el
  tamaño y la centra en la pantalla actual.
- `game_mode._apply_fullscreen()` cambia a pantalla completa.
- El proyecto usa `stretch/mode = canvas_items` con `aspect = expand`, así que el
  contenido se reescala correctamente a cualquier tamaño.

Ambas opciones (Idioma y Resolución) están en el menú **ESC**, junto a Controles.
