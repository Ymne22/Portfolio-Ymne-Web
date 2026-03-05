shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_toon, specular_toon;

varying vec3 v_sphere_normal;

group_uniforms Albedo;
uniform sampler2D albedo_texture : source_color, filter_nearest;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float alpha_scissor : hint_range(0.0, 1.0) = 0.5;

group_uniforms Shading;
uniform bool use_unlit_mode = true; 
uniform float unlit_shadow_mix : hint_range(0.0, 1.0) = 0.0;
uniform bool use_hard_edge_shadow = true;
uniform float shadow_threshold : hint_range(0.0, 1.0, 0.00001) = 0.5;
uniform int shadow_steps : hint_range(1, 10) = 3;
uniform vec4 shadow_color : source_color = vec4(0.3, 0.3, 0.3, 1.0);
uniform float min_light : hint_range(0.0, 1.0) = 0.1;
uniform float cast_shadow_strength : hint_range(0.0, 1.0) = 0.0;

group_uniforms FaceCorrection;
uniform bool use_spherized_normals = false;
uniform vec3 sphere_center = vec3(0.0, 0.1, 0.0);
uniform vec4 sphere_shadow_color : source_color = vec4(0.7, 0.6, 0.6, 1.0);
uniform float sphere_light_offset : hint_range(0.0, 0.5) = 0.0;
uniform float flatten_normal : hint_range(0.0, 1.0) = 0.0;
uniform float shadow_coverage : hint_range(-0.5, 0.5) = 0.05;
uniform sampler2D face_shadow_map : hint_default_black, filter_linear;
uniform float shadow_map_strength : hint_range(0.0, 1.0) = 1.0;

group_uniforms Specular;
uniform float specular_size : hint_range(0.0, 1.0) = 0.1;
uniform vec4 specular_color : source_color = vec4(1.0);
uniform float specular_intensity : hint_range(0.0, 1.0) = 0.2;

group_uniforms SubsurfaceScattering;
uniform bool use_sss = true;
uniform vec4 sss_color : source_color = vec4(1.0, 0.5, 0.4, 1.0);
uniform float sss_amount : hint_range(0.0, 10.0) = 1.0;
uniform float sss_falloff : hint_range(1.0, 8.0) = 2.0;

group_uniforms RimLight;
uniform bool use_rim_light = true;
uniform bool rim_in_shadows_only = true;
uniform vec4 rim_color : source_color = vec4(0.8, 0.8, 1.0, 1.0);
uniform float rim_threshold : hint_range(0.0, 1.0) = 0.7;
uniform float rim_intensity : hint_range(0.0, 10.0) = 0.5;
uniform float rim_sharpness : hint_range(0.0, 1.0) = 0.1;

void vertex() {
	vec3 dir = normalize(VERTEX - sphere_center);
	v_sphere_normal = (MODELVIEW_MATRIX * vec4(dir, 0.0)).xyz;
}

void fragment() {
	vec4 tex = texture(albedo_texture, UV);
	ALBEDO = tex.rgb * albedo_color.rgb;
	ALPHA = tex.a * albedo_color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}

void light() {
	float spec_active = use_unlit_mode ? 0.0 : specular_intensity;
	float sss_active = use_unlit_mode ? 0.0 : sss_amount;
	vec3 active_shadow = use_spherized_normals ? sphere_shadow_color.rgb : shadow_color.rgb;

	// Normal calculation
	vec3 n = NORMAL;
	if (use_spherized_normals) {
		n = normalize(v_sphere_normal);
	} else if (flatten_normal > 0.0) {
		n = normalize(vec3(NORMAL.x * (1.0 - flatten_normal), NORMAL.y * (1.0 - flatten_normal), NORMAL.z));
	}

	float ndotl = dot(n, LIGHT);
	if (use_spherized_normals) ndotl += sphere_light_offset;
	
	float ndotl_clamped = clamp(ndotl, 0.0, 1.0);
	float attn = mix(1.0, ATTENUATION, cast_shadow_strength);
	float shadow_mask = texture(face_shadow_map, UV).r * shadow_map_strength;
	float light_res = ndotl_clamped + shadow_mask + shadow_coverage;

	// Cel Shading
	float cel = 0.0;
	if (use_hard_edge_shadow) {
		cel = step(shadow_threshold, light_res);
	} else {
		cel = floor(light_res * float(shadow_steps)) / (float(shadow_steps) - 0.5);
	}

	vec3 diffuse = mix(active_shadow, LIGHT_COLOR, cel * attn);

	// SSS
	if (use_sss && sss_active > 0.0) {
		float wrap = dot(n, LIGHT) * 0.5 + 0.5;
		float mask = clamp(1.0 - light_res, 0.0, 1.0); 
		diffuse += sss_color.rgb * LIGHT_COLOR * pow(wrap, sss_falloff) * mask * sss_active;
	}

	// Specular
	vec3 spec = vec3(0.0);
	if (spec_active > 0.0) {
		vec3 half = normalize(LIGHT + VIEW);
		float ndoth = clamp(dot(NORMAL, half), 0.0, 1.0); 
		float cut = step(1.0 - specular_size, ndoth);
		spec = specular_color.rgb * LIGHT_COLOR * cut * spec_active * attn;
	}

	// Rim
	vec3 rim_final = vec3(0.0);
	if (use_rim_light) {
		float rim_mask = mix(1.0, (cel < 0.01 ? 1.0 : 0.0), float(rim_in_shadows_only));
		float ndotv = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
		float rim = smoothstep(rim_threshold - rim_sharpness, rim_threshold + rim_sharpness, ndotv);
		rim_final = rim_color.rgb * rim * rim_mask * rim_intensity * LIGHT_COLOR;
	}

	vec3 base_lit = ALBEDO * diffuse;
	if (use_unlit_mode && cel < 0.5) {
		base_lit = mix(vec3(1.0), ALBEDO, unlit_shadow_mix) * diffuse;
	}

	DIFFUSE_LIGHT += base_lit + (ALBEDO * min_light) + rim_final + spec;
}