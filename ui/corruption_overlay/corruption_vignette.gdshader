shader_type canvas_item;
// Korruptionsstufe 1 (Phase 5): "Bildschirmraender entsaettigen".
// Liest die fertige Szene aus dem Backbuffer und zieht ihr zum Rand hin die Farbe raus. Bewusst
// nur am Rand: die Bildmitte, in der gekaempft wird, bleibt unangetastet lesbar — die Korruption
// soll beunruhigen, nicht die Lesbarkeit des Kampfes kosten.

uniform sampler2D screen_tex : hint_screen_texture, repeat_disable, filter_nearest;
// 0 = unkorrumpiert (Node ist dann ausgeblendet), 1 = Vollausschlag.
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
// Radius (0 = Mitte, 1 = Ecke), ab dem die Entsaettigung einsetzt bzw. voll ist.
uniform float inner_radius : hint_range(0.0, 1.0) = 0.30;
uniform float outer_radius : hint_range(0.0, 1.0) = 0.95;
// Restfarbstich der entsaettigten Raender.
uniform vec3 tint : source_color = vec3(0.82, 0.78, 0.95);

void fragment() {
	vec3 col = texture(screen_tex, SCREEN_UV).rgb;
	vec2 p = (SCREEN_UV - vec2(0.5)) * 2.0;
	float d = length(p) / 1.41421356;
	float edge = smoothstep(inner_radius, outer_radius, d) * intensity;

	float grey = dot(col, vec3(0.299, 0.587, 0.114));
	vec3 drained = vec3(grey) * tint;
	vec3 result = mix(col, drained, edge) * mix(1.0, 0.78, edge);
	COLOR = vec4(result, 1.0);
}
