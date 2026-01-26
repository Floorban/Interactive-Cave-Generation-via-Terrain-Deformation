shader_type spatial;

// --- Transvoxel transition support (from Zylann’s shader) ---
uniform int u_transition_mask;

float get_transvoxel_secondary_factor(int idata) {
	int transition_mask = u_transition_mask & 0xff;
	int cell_border_mask = (idata >> 0) & 63;
	int vertex_border_mask = (idata >> 8) & 63;
	int m = transition_mask & cell_border_mask;
	float t = float(m != 0);
	t *= float((vertex_border_mask & ~transition_mask) == 0);
	return t;
}

vec3 get_transvoxel_position(vec3 vertex_pos, vec4 fdata) {
	int idata = floatBitsToInt(fdata.a);
	float secondary_factor = get_transvoxel_secondary_factor(idata);
	vec3 secondary_position = fdata.xyz;
	vec3 pos = mix(vertex_pos, secondary_position, secondary_factor);
	int itransition = (idata >> 16) & 0xff;
	float transition_cull = float(itransition == 0 || (itransition & u_transition_mask) != 0);
	pos *= transition_cull;
	return pos;
}

// --- Texture blending ---
uniform sampler2DArray u_texture_array;
uniform float uv_scale : hint_range(0.1, 10.0) = 0.5;

// Painting influence
uniform float paint_strength = 1.0;

varying vec4 v_indices;
varying vec4 v_weights;
varying vec3 v_normal;
varying vec3 v_pos;

// --- Decode 8-bit packed floats ---
vec4 decode_8bit_vec4(float v) {
	uint i = floatBitsToUint(v);
	return vec4(
		float(i & uint(0xff)),
		float((i >> uint(8)) & uint(0xff)),
		float((i >> uint(16)) & uint(0xff)),
		float((i >> uint(24)) & uint(0xff))
	);
}

// --- Triplanar blending ---
vec3 get_triplanar_blend(vec3 normal) {
	vec3 blend = abs(normal);
	blend = normalize(max(blend, vec3(0.00001)));
	float sum = blend.x + blend.y + blend.z;
	return blend / vec3(sum, sum, sum);
}

vec3 sample_triplanar(sampler2DArray tex, vec3 pos, vec3 blend, float layer) {
	vec3 xaxis = texture(tex, vec3(pos.yz, layer)).rgb;
	vec3 yaxis = texture(tex, vec3(pos.xz, layer)).rgb;
	vec3 zaxis = texture(tex, vec3(pos.xy, layer)).rgb;
	return xaxis * blend.x + yaxis * blend.y + zaxis * blend.z;
}

// --- Vertex processing ---
void vertex() {
	VERTEX = get_transvoxel_position(VERTEX, CUSTOM0);
	v_indices = decode_8bit_vec4(CUSTOM1.x);
	v_weights = decode_8bit_vec4(CUSTOM1.y) / 255.0;
	v_pos = VERTEX;
	v_normal = NORMAL;
}

// --- Fragment processing ---
void fragment() {
	vec3 blend = get_triplanar_blend(v_normal);

	// Sample up to 4 painted textures
	vec3 paint0 = sample_triplanar(u_texture_array, v_pos * uv_scale, blend, v_indices.x).rgb;
	vec3 paint1 = sample_triplanar(u_texture_array, v_pos * uv_scale, blend, v_indices.y).rgb;
	vec3 paint2 = sample_triplanar(u_texture_array, v_pos * uv_scale, blend, v_indices.z).rgb;
	vec3 paint3 = sample_triplanar(u_texture_array, v_pos * uv_scale, blend, v_indices.w).rgb;

	// Normalize weights
	vec4 weights = v_weights;
	weights /= (weights.x + weights.y + weights.z + weights.w + 0.00001);

	// Combine painted layers
	vec3 painted = paint0 * weights.r + paint1 * weights.g + paint2 * weights.b + paint3 * weights.a;

	// Apply final color (painted only, CPU already chose correct voxel type)
	ALBEDO = painted;
}
