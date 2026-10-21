shader_type canvas_item;
// Turns a rendered 3D panel into comic-book art: flat colour bands, bold ink outlines, halftone dots in the shadows and a touch of paper grain.

uniform float levels : hint_range(2.0, 8.0) = 4.0;
uniform float ink : hint_range(0.0, 1.0) = 0.85;
uniform float dot_size = 5.0;
uniform float saturation = 1.35;

float lum(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE * 1.2;
	vec3 c = texture(TEXTURE, UV).rgb;
	// Sobel edge detection on luminance
	float tl = lum(texture(TEXTURE, UV + px * vec2(-1.0, -1.0)).rgb);
	float t0 = lum(texture(TEXTURE, UV + px * vec2(0.0, -1.0)).rgb);
	float tr = lum(texture(TEXTURE, UV + px * vec2(1.0, -1.0)).rgb);
	float l0 = lum(texture(TEXTURE, UV + px * vec2(-1.0, 0.0)).rgb);
	float r0 = lum(texture(TEXTURE, UV + px * vec2(1.0, 0.0)).rgb);
	float bl = lum(texture(TEXTURE, UV + px * vec2(-1.0, 1.0)).rgb);
	float b0 = lum(texture(TEXTURE, UV + px * vec2(0.0, 1.0)).rgb);
	float br = lum(texture(TEXTURE, UV + px * vec2(1.0, 1.0)).rgb);
	float gx = -tl - 2.0 * l0 - bl + tr + 2.0 * r0 + br;
	float gy = -tl - 2.0 * t0 - tr + bl + 2.0 * b0 + br;
	float edge = smoothstep(0.16, 0.42, length(vec2(gx, gy)));
	// flat colour bands, punchier colour
	vec3 p = floor(c * levels + 0.5) / levels;
	float l = lum(p);
	p = mix(vec3(l), p, saturation);
	// halftone dots, rotated 45 degrees, bigger where it is darker
	vec2 fc = FRAGCOORD.xy / dot_size;
	vec2 q = vec2(fc.x + fc.y, fc.y - fc.x) * 0.7071;
	float d = length(fract(q) - 0.5);
	float shade = 1.0 - smoothstep(0.0, 0.7, l);
	float dots = step(d, shade * 0.62);
	vec3 col = p * (1.0 - 0.5 * dots);
	// ink
	col = mix(col, vec3(0.02, 0.015, 0.03), edge * ink);
	// paper grain
	float g = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	col *= 0.97 + 0.05 * g;
	COLOR = vec4(col, 1.0);
}
