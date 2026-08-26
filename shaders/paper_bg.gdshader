shader_type canvas_item;
render_mode unshaded;

// Zemin. Tek duz renk veya basit bir degrade, ekranin "boş tuval" gibi
// gorunmesine yol aciyor. Burada dort katman var:
//
//   1. dikey sicaklik gecisi      -- ust acik krem, alt tarcin
//   2. tahtanin arkasindaki isik havuzu -- goz merkeze cekilir, oyun alani
//                                          kendiliginden one cikar
//   3. yumusak vinyet             -- kenarlar geri ceker
//   4. iki olcekli kagit tanesi   -- yuzeyin "kagit" oldugunu soyleyen sey
//
// Tane olmadan bu palet duz vektor gibi duruyor.

uniform vec4 top_color : source_color = vec4(0.973, 0.953, 0.918, 1.0);
uniform vec4 bottom_color : source_color = vec4(0.906, 0.855, 0.784, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.988, 0.949, 1.0);
uniform float grain : hint_range(0.0, 0.12) = 0.022;
uniform float vignette : hint_range(0.0, 0.8) = 0.30;
uniform float glow : hint_range(0.0, 1.0) = 0.55;
uniform vec2 focus = vec2(0.5, 0.46);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec3 col = mix(top_color.rgb, bottom_color.rgb, smoothstep(0.0, 1.0, UV.y));

	// oyun alaninin arkasindaki isik havuzu
	vec2 d = (UV - focus) * vec2(1.0, 1.35);
	float pool = 1.0 - smoothstep(0.05, 0.62, length(d));
	col = mix(col, glow_color.rgb, pool * glow);

	// vinyet
	float v = smoothstep(0.32, 0.98, length((UV - vec2(0.5)) * vec2(1.0, 1.15)));
	col *= 1.0 - v * vignette;

	// iki olcekli tane: ince gurultu + daha genis lif dalgalanmasi
	float fine = hash21(floor(FRAGCOORD.xy));
	float fiber = hash21(floor(FRAGCOORD.xy * 0.22));
	col += (fine - 0.5) * grain;
	col += (fiber - 0.5) * grain * 0.7;

	COLOR = vec4(col, 1.0);
}
