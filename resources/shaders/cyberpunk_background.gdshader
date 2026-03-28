shader_type canvas_item;

// Cyberpunk background shader with scanlines, vignette, pulsation, and parallax
// Optimized for GL Compatibility renderer

uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.08;
uniform float scanline_count : hint_range(50.0, 500.0) = 150.0;
uniform float vignette_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float vignette_softness : hint_range(0.0, 1.0) = 0.6;
uniform float pulse_speed : hint_range(0.0, 5.0) = 0.5;
uniform float pulse_intensity : hint_range(0.0, 0.5) = 0.05;
uniform vec3 tint_color : source_color = vec3(0.3, 0.6, 1.0);
uniform float tint_strength : hint_range(0.0, 1.0) = 0.0;

// Parallax uniforms
uniform vec2 parallax_offset = vec2(0.0, 0.0);
uniform float parallax_strength : hint_range(0.0, 0.2) = 0.05;

void fragment() {
	// Apply parallax offset to UV
	vec2 parallax_uv = UV + parallax_offset * parallax_strength;
	
	// Clamp UV to avoid texture wrapping artifacts
	parallax_uv = clamp(parallax_uv, 0.0, 1.0);
	
	vec4 tex_color = texture(TEXTURE, parallax_uv);
	
	// Scanlines effect (moves with parallax for stylized look)
	float scanline = sin(parallax_uv.y * scanline_count * 3.14159) * 0.5 + 0.5;
	scanline = mix(1.0, scanline, scanline_intensity);
	
	// Vignette effect (stays fixed to screen)
	vec2 uv_centered = UV - 0.5;
	float vignette = 1.0 - dot(uv_centered, uv_centered) * (2.0 - vignette_softness);
	vignette = clamp(vignette, 0.0, 1.0);
	vignette = mix(1.0, vignette, vignette_intensity);
	
	// Pulsation effect (subtle brightness variation)
	float pulse = sin(TIME * pulse_speed) * 0.5 + 0.5;
	float brightness = 1.0 + pulse * pulse_intensity;
	
	// Apply all effects
	vec3 final_color = tex_color.rgb;
	final_color *= scanline;
	final_color *= vignette;
	final_color *= brightness;
	
	// Optional cyan tint for extra cyberpunk feel
	final_color = mix(final_color, final_color * tint_color, tint_strength);
	
	COLOR = vec4(final_color, tex_color.a);
}
