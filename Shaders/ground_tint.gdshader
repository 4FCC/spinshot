shader_type canvas_item;

// =============================================================================
// GROUND TINT — Atenúa/desatura el suelo y el fondo para mejorar el contraste
// =============================================================================
// Objetivo: que el césped/piedra "se hundan" un poco (más apagados y oscuros)
// para que el jugador, los enemigos y la UI RESALTEN, sin tocar los assets.
// Es muy barato (un solo material en GPU) y respeta el pixel art (solo ajusta
// el color por píxel; el muestreo sigue siendo NEAREST del propio nodo).

uniform float darken : hint_range(0.0, 1.0) = 0.74;        // 1 = igual, <1 más oscuro
uniform float desaturation : hint_range(0.0, 1.0) = 0.40;  // 0 = color original, 1 = gris
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);    // tinte multiplicativo (leve)

void fragment() {
	// COLOR entrante = modulate del nodo (se conserva multiplicando al final).
	vec4 node_modulate = COLOR;
	vec4 tex = texture(TEXTURE, UV);
	vec3 c = tex.rgb;
	// Desaturar hacia su luminancia.
	float g = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(g), desaturation);
	// Oscurecer y teñir.
	c *= darken;
	c *= tint;
	COLOR = vec4(c, tex.a) * node_modulate;
}
