shader_type sky;

group_uniforms PlanetSettings;
uniform vec4 ground_color : source_color = vec4(0.369, 0.349, 0.341, 1.0);
uniform float planet_radius : hint_range(6000.0, 7000.0) = 6371.0;
uniform float atmosphere_radius : hint_range(6000.0, 7000.0) = 6471.0;

group_uniforms SunSettings;
uniform float sun_intensity : hint_range(0.0, 512.0) = 256.0;
uniform float sun_size : hint_range(0.0, 0.01) = 0.000025;

group_uniforms AtmosphereDensity;
uniform float rayleigh_scale_height = 8000.0;
uniform float mie_scale_height = 1200.0;
uniform float mie_g : hint_range(-0.99, 0.99) = 0.8;

group_uniforms ScatteringCoefficients;
uniform vec3 beta_r = vec3(0.0000058, 0.0000135, 0.0000331);
uniform float mie_coefficient = 0.000001;

group_uniforms DayNightTransition;
uniform float sun_fade_start_angle : hint_range(0.0, 90.0) = 5.0;
uniform float sun_fade_end_angle : hint_range(-90.0, 0.0) = -2.0;
uniform bool invert_day_night = false;

group_uniforms DayAndFogColors;
uniform vec4 sky_tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 sunset_tint : source_color = vec4(0.05, 0.08, 0.117, 1.0);
uniform vec4 horizon_color : source_color = vec4(1.0, 0.8, 0.6, 1.0);

group_uniforms DomeFog;
uniform bool enable_dome_fog = true;
uniform vec4 dome_fog_color : source_color = vec4(0.194, 0.230, 0.283, 1.0);
uniform float dome_fog_start : hint_range(-1.0, 1.0) = -1.0;
uniform float dome_fog_end : hint_range(-1.0, 1.0) = 0.35;
uniform float dome_fog_intensity : hint_range(0.0, 100.0) = 32.0;

group_uniforms GlobalFog;
uniform bool enable_global_fog = true;
uniform bool global_fog_cover_bottom = false;
uniform vec4 global_fog_color : source_color = vec4(0.5, 0.6, 0.7, 1.0);
uniform vec4 global_fog_color_night : source_color = vec4(0.1, 0.1, 0.2, 1.0);
uniform float global_fog_intensity : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform float global_fog_height_start : hint_range(-2000.0, 2000.0, 1.0) = 0.0;
uniform float global_fog_height_end : hint_range(-2000.0, 8000.0, 1.0) = 1000.0;
uniform float global_sun_glow_intensity : hint_range(0.0, 128.0, 0.1) = 32.0;

group_uniforms NightSky;
uniform sampler2D moon_tex : hint_default_white, filter_linear, repeat_disable;
uniform float moon_size : hint_range(0.0, 0.1) = 0.0374;
uniform float moon_intensity : hint_range(0.0, 32.0) = 8.0;
uniform vec4 night_ambient_color : source_color = vec4(0.05, 0.08, 0.15, 1.0);
uniform float min_ground_ambient : hint_range(0.0, 0.1) = 0.01;

group_uniforms StarsSettings;
uniform float stars_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float stars_density : hint_range(0.9, 0.999) = 0.9;
uniform float stars_scale : hint_range(50.0, 500.0) = 128.0;
uniform float stars_twinkle_speed : hint_range(0.0, 10.0) = 0.25;
uniform bool enable_star_rotation = true;
uniform float stars_rotation_speed : hint_range(0.0, 1.0) = 0.8;

group_uniforms ProceduralVolumetricClouds;
uniform bool enable_procedural_clouds = true;
uniform float cloud_min_height : hint_range(100.0, 8000.0) = 1500.0;
uniform float cloud_max_height : hint_range(1000.0, 16000.0) = 5000.0;
uniform float cloud_curvature : hint_range(0.0, 1.0) = 1.0;
uniform float noise_scale : hint_range(0.1, 1.0) = 0.5;
uniform float coverage : hint_range(0.0, 1.0) = 0.45;
uniform float density : hint_range(0.0, 1.0) = 0.1;
uniform float softness : hint_range(0.1, 2.0) = 1.0;
uniform float curliness : hint_range(0.1, 5.0) = 1.5;
uniform float detail_intensity : hint_range(0.0, 1.0) = 0.25;
uniform float detail_noise_scale : hint_range(1.0, 128.0) = 32.0;
uniform float detail_fade_distance : hint_range(0.0, 50000.0) = 4096.0;
uniform float cloud_distance_fade : hint_range(0.0, 100000.0) = 8192.0;

group_uniforms CloudAnimation;
uniform vec3 wind_direction = vec3(-1.0, 0.0, 1.0);
uniform float wind_speed : hint_range(0.0, 100.0) = 10.0;
uniform float cloud_morph_speed : hint_range(0.0, 0.1) = 0.005;
uniform vec3 noise_seed_offset = vec3(-5600.0, 1200.0, 1800.0);
uniform float cloud_morph_seed : hint_range(0.0, 1000.0) = 0.0;

group_uniforms CloudLighting;
uniform float cloud_thickness : hint_range(0.0, 0.1) = 0.01;
uniform float light_absorption : hint_range(0.1, 5.0) = 1.5;
uniform float self_shadow_strength : hint_range(0.1, 5.0) = 2.0;
uniform float cloud_ambient_intensity : hint_range(0.0, 100.0) = 25.0;
uniform vec4 cloud_base_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cloud_shadow_color : source_color = vec4(0.2, 0.25, 0.35, 1.0);
uniform vec4 cloud_night_color : source_color = vec4(0.05, 0.08, 0.15, 1.0);
uniform float cloud_brightness : hint_range(0.1, 5.0) = 1.0;
uniform float cloud_phase_intensity : hint_range(0.0, 5.0) = 1.5;
uniform float cloud_anisotropy_g : hint_range(0.0, 0.99) = 0.8;
uniform float powder_effect_intensity : hint_range(0.0, 1.0) = 0.4;
uniform float cloud_scattering_intensity : hint_range(0.0, 10.0) = 1.0;

group_uniforms WeatherMap;
uniform bool enable_weather_map = true;
uniform float weather_map_scale : hint_range(0.01, 1.0) = 0.1;
uniform float weather_map_influence : hint_range(0.0, 1.0) = 0.5;

group_uniforms FlatDomeClouds;
uniform bool enable_flat_clouds = true;
uniform sampler2D flat_cloud_map : hint_default_black, filter_linear_mipmap;
uniform vec4 flat_cloud_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flat_cloud_tiling : hint_range(0.0, 1.0) = 0.35;
uniform float flat_cloud_speed : hint_range(-0.1, 0.1) = -0.01;
uniform float flat_cloud_rotation_speed : hint_range(0.0, 0.1) = 0.01;
uniform float flat_cloud_cover : hint_range(0.0, 1.0) = 0.6;
uniform float flat_cloud_opacity : hint_range(0.0, 1.0) = 0.1;
uniform float flat_cloud_scattering : hint_range(0.0, 20.0) = 1.0;
uniform float flat_cloud_anisotropy : hint_range(-0.9, 0.9) = 0.1;

group_uniforms PerformanceAndQuality;
uniform int view_samples : hint_range(1, 32) = 8;
uniform int light_samples : hint_range(1, 16) = 2;
uniform float exposure : hint_range(0.1, 5.0) = 1.0;
uniform int cloud_steps : hint_range(0, 128) = 16;
uniform int light_steps : hint_range(0, 8) = 2;
uniform bool enable_adaptive_light_steps = true;
uniform float light_step_fade_dist : hint_range(1000.0, 16000.0) = 4096.0;
uniform bool use_blue_noise_dithering = false;
uniform sampler2D blue_noise_tex : hint_default_black, filter_linear, repeat_enable;
uniform float blue_noise_tiling : hint_range(0.1, 10.0) = 1.0;

// --- UTILITIES ---

vec3 hash3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123);
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

vec2 ray_sphere_intersect(vec3 ro, vec3 rd, float r) {
	float b = dot(ro, rd);
	float c = dot(ro, ro) - r * r;
	float h = b * b - c;
	return h < 0.0 ? vec2(-1.0) : vec2(-b - sqrt(h), -b + sqrt(h));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
					 mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
					 mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p, int octaves) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < octaves; i++) { v += a * noise(p); p *= 2.0; a *= 0.5; }
	return v;
}

vec3 curl_noise(vec3 p) {
	const float e = 0.1;
	vec3 dx = vec3(e, 0, 0), dy = vec3(0, e, 0), dz = vec3(0, 0, e);
	return normalize(vec3(fbm(p + dy, 1) - fbm(p + dz, 1), fbm(p + dz, 1) - fbm(p + dx, 1), fbm(p + dx, 1) - fbm(p + dy, 1))) / e;
}

// --- CORE ATMOSPHERE ---

float get_optical_depth(vec3 ro, vec3 rd, float len, float sh) {
	float od = 0.0, step_len = len / float(light_samples);
	for (int i = 0; i < light_samples; i++) {
		float h = length(ro + rd * (float(i) + 0.5) * step_len) - planet_radius;
		if (h < 0.0) return 1e10;
		od += exp(-h / sh);
	}
	return od * step_len;
}

float rayleigh_phase(float ct) { return (3.0 / (16.0 * PI)) * (1.0 + ct * ct); }
float hg_phase(float ct, float g) {
	float g2 = g * g;
	return (1.0 / (4.0 * PI)) * ((1.0 - g2) / pow(1.0 + g2 - 2.0 * g * ct, 1.5));
}

vec3 calculate_scattering(vec3 sun_dir, float sun_inst, vec3 view_dir, vec3 camera_pos, float ray_len, vec3 br, float bm) {
	vec3 rayleigh = vec3(0.0), mie = vec3(0.0);
	float step_len = ray_len / float(view_samples);
	for (int i = 0; i < view_samples; i++) {
		vec3 p = camera_pos + view_dir * (float(i) + 0.5) * step_len;
		float h = length(p) - planet_radius;
		if (h < 0.0) continue;
		float od_v_r = get_optical_depth(camera_pos, view_dir, distance(camera_pos, p), rayleigh_scale_height);
		float od_v_m = get_optical_depth(camera_pos, view_dir, distance(camera_pos, p), mie_scale_height);
		vec2 li = ray_sphere_intersect(p, sun_dir, atmosphere_radius);
		if (li.y > 0.0) {
			float od_l_r = get_optical_depth(p, sun_dir, li.y, rayleigh_scale_height);
			float od_l_m = get_optical_depth(p, sun_dir, li.y, mie_scale_height);
			vec3 tr = exp(-((od_l_r + od_v_r) * br + (od_l_m + od_v_m) * bm));
			float ct = dot(view_dir, sun_dir);
			rayleigh += tr * rayleigh_phase(ct) * exp(-h / rayleigh_scale_height);
			mie += tr * hg_phase(ct, mie_g) * exp(-h / mie_scale_height);
		}
	}
	return (rayleigh * br + mie * bm) * sun_inst * step_len;
}

vec4 calculate_global_fog(vec3 pos, vec3 dir, vec3 sun, vec3 col, float sun_f) {
	float h = length(pos) - planet_radius;
	float f = clamp(smoothstep(global_fog_height_end, global_fog_height_start, h), 0.0, 1.0) * global_fog_intensity;
	vec3 base = mix(global_fog_color_night.rgb, global_fog_color.rgb, sun_f);
	float sun_glow = pow(clamp(dot(dir, sun), 0.0, 1.0), 32.0);
	return vec4(base + col * sun_glow * global_sun_glow_intensity * sun_f, f);
}

// --- CLOUDS ---

float get_cloud_density(vec3 pos, float detail_f) {
	vec3 p = ((pos + noise_seed_offset) + normalize(wind_direction) * wind_speed * TIME) * noise_scale * 0.001;
	p += vec3(0, 0, (TIME * cloud_morph_speed) + cloud_morph_seed);
	float dyn_cov = coverage;
	if (enable_weather_map) dyn_cov -= fbm(p * weather_map_scale, 3) * weather_map_influence;
	float base = clamp((fbm(p, 4) - dyn_cov) / max(0.001, 1.0 - dyn_cov), 0.0, 1.0);
	if (base < 0.01) return 0.0;
	base = clamp(base - fbm(p * mix(detail_noise_scale, 4.0, detail_f), 3) * detail_intensity * (1.0 - detail_f), 0.0, 1.0);
	base = clamp(base + curl_noise(p * curliness).x * 0.01, 0.0, 1.0);
	float h = mix((pos.y - (planet_radius + cloud_min_height)) / (cloud_max_height - cloud_min_height), (length(pos) - planet_radius - cloud_min_height) / (cloud_max_height - cloud_min_height), cloud_curvature);
	return clamp(base * smoothstep(0.0, 0.15, h) * (1.0 - smoothstep(0.8, 1.0, h)) * density * softness, 0.0, 1.0);
}

vec3 calculate_procedural_clouds(vec3 ro, vec3 rd, vec3 sun, vec3 sun_c, vec3 sky_c, vec3 bg_c) {
	float t_min, t_max;
	if (cloud_curvature > 0.0) {
		vec2 t_c = ray_sphere_intersect(ro, rd, planet_radius + cloud_max_height);
		if (t_c.y < 0.0) return bg_c;
		t_min = max(0.0, t_c.x); t_max = t_c.y;
	} else {
		float d1 = ((planet_radius + cloud_min_height) - ro.y) / rd.y, d2 = ((planet_radius + cloud_max_height) - ro.y) / rd.y;
		if (abs(rd.y) < 0.001) { if (ro.y < planet_radius + cloud_min_height || ro.y > planet_radius + cloud_max_height) return bg_c; t_min = 0.0; t_max = cloud_distance_fade; }
		else { t_min = max(0.0, min(d1, d2)); t_max = max(d1, d2); }
	}
	t_max = min(t_max, cloud_distance_fade);
	if (t_min >= t_max) return bg_c;
	float step_sz = (t_max - t_min) / float(cloud_steps), tr = 1.0;
	vec3 acc = vec3(0.0);
	float offset = use_blue_noise_dithering ? texture(blue_noise_tex, vec2(atan(rd.x, -rd.z) / (2.0 * PI) + 0.5, asin(rd.y) / PI + 0.5) * blue_noise_tiling).r : hash(rd * 16.0);
	float t = t_min + offset * step_sz;
	for (int s = 0; s < cloud_steps; s++, t += step_sz) {
		if (t > t_max || tr < 0.01) break;
		vec3 p = ro + rd * t;
		float lod = smoothstep(detail_fade_distance * 0.5, detail_fade_distance, t), d = get_cloud_density(p, lod);
		if (d > 0.01) {
			int lsteps = enable_adaptive_light_steps ? max(1, int(mix(float(light_steps), 1.0, smoothstep(light_step_fade_dist * 0.75, light_step_fade_dist, t)))) : light_steps;
			float ld = 0.0, lstep_sz = 96.0;
			for (int ls = 0; ls < lsteps; ls++) ld += get_cloud_density(p + sun * lstep_sz * (float(ls) + 0.5), lod);
			float en = exp(-ld * lstep_sz * self_shadow_strength * light_absorption * cloud_thickness);
			vec3 amb = sky_c * cloud_shadow_color.rgb * cloud_ambient_intensity;
			vec3 direct = sun_c * hg_phase(dot(rd, sun), cloud_anisotropy_g) * cloud_phase_intensity;
			vec3 cloud_c = cloud_base_color.rgb * (amb + direct * (en + pow(1.0 - en, 2.0) * powder_effect_intensity)) * cloud_brightness;
			float st_tr = exp(-d * step_sz * light_absorption * cloud_thickness);
			acc += mix(cloud_c, sky_c, clamp(smoothstep(0.0, cloud_distance_fade, t) * cloud_scattering_intensity, 0.0, 1.0)) * (1.0 - st_tr) * tr;
			tr *= st_tr;
		}
	}
	return acc + bg_c * tr;
}

// --- MAIN ---

void sky() {
	vec3 view_dir = EYEDIR, sun_dir = LIGHT0_DIRECTION, camera_pos = vec3(0.0, planet_radius + 1.0, 0.0);
	float sun_f = invert_day_night ? 1.0 - smoothstep(sin(radians(sun_fade_end_angle)), sin(radians(sun_fade_start_angle)), sun_dir.y) : smoothstep(sin(radians(sun_fade_end_angle)), sin(radians(sun_fade_start_angle)), sun_dir.y);
	vec3 color = vec3(0.0);

	if (ray_sphere_intersect(camera_pos, view_dir, planet_radius).x > 0.0) {
		if (enable_global_fog && global_fog_cover_bottom) color = mix(global_fog_color_night.rgb, global_fog_color.rgb, sun_f);
		else color = ground_color.rgb * (mix(night_ambient_color.rgb * moon_intensity * 0.5, mix(horizon_color.rgb, vec3(1.0), clamp(sun_dir.y * 2.0, 0.0, 1.0)) * sun_intensity * 0.01, sun_f) + min_ground_ambient);
	} else {
		float ray_len = ray_sphere_intersect(camera_pos, view_dir, atmosphere_radius).y, sunset_f = smoothstep(0.2, 0.0, sun_dir.y);
		vec3 br_dyn = beta_r * mix(vec3(1.0), vec3(1.2, 0.55, 0.25), sunset_f);
		vec3 day_s = calculate_scattering(sun_dir, sun_intensity, view_dir, camera_pos, ray_len, br_dyn, mie_coefficient);
		day_s += mix(horizon_color.rgb, sunset_tint.rgb, pow(clamp(dot(view_dir, sun_dir) * 0.5 + 0.5, 0.0, 1.0), 4.0)) * pow(clamp(1.0 - view_dir.y, 0.0, 1.0), 8.0) * pow(clamp(dot(view_dir, sun_dir) * 0.5 + 0.5, 0.0, 1.0), 128.0) * sun_intensity * sunset_f * 0.04;
		vec3 sky_c = mix(calculate_scattering(-sun_dir, moon_intensity, view_dir, camera_pos, ray_len, beta_r, mie_coefficient) + night_ambient_color.rgb, day_s * sky_tint.rgb, sun_f);
		
		if (sun_f < 0.8) {
			vec3 svd = enable_star_rotation ? transpose(mat3(vec3(cos(atan(sun_dir.x, sun_dir.z) * stars_rotation_speed), 0.0, sin(atan(sun_dir.x, sun_dir.z) * stars_rotation_speed)), vec3(0.0, 1.0, 0.0), vec3(-sin(atan(sun_dir.x, sun_dir.z) * stars_rotation_speed), 0.0, cos(atan(sun_dir.x, sun_dir.z) * stars_rotation_speed))) * mat3(vec3(1.0, 0.0, 0.0), vec3(0.0, cos(asin(-sun_dir.y) * stars_rotation_speed), -sin(asin(-sun_dir.y) * stars_rotation_speed)), vec3(0.0, sin(asin(-sun_dir.y) * stars_rotation_speed), cos(asin(-sun_dir.y) * stars_rotation_speed)))) * view_dir : view_dir;
			vec3 cid = floor(svd * stars_scale), ch = hash3(cid);
			if (ch.x > stars_density) sky_c += vec3(1.0) * (0.5 + 0.5 * hash3(cid + 1.0).y) * exp(-40.0 * dot((svd * stars_scale) - (cid + ch.yz), (svd * stars_scale) - (cid + ch.yz))) * (0.5 + 0.5 * sin((hash3(cid + 1.0).x + TIME * stars_twinkle_speed) * 5.0)) * stars_intensity * (1.0 - clamp(sun_f * 2.0, 0.0, 1.0));
		}

		vec3 moon_c = vec3(0.0), moon_dir = -sun_dir; float md = dot(view_dir, moon_dir);
		if (md > 0.0 && dot(view_dir - moon_dir * md, view_dir - moon_dir * md) < moon_size * moon_size) {
			vec3 mr = normalize(cross(moon_dir, abs(moon_dir.y) < 0.99 ? vec3(0,1,0) : vec3(1,0,0))), mu = cross(mr, moon_dir);
			moon_c = texture(moon_tex, vec2(dot(view_dir - moon_dir * md, mr), dot(view_dir - moon_dir * md, mu)) / moon_size * 0.5 + 0.5).rgb * moon_intensity;
		}

		vec3 sun_c = vec3(0.0); float sd = smoothstep(1.0 - sun_size, 1.0, dot(view_dir, sun_dir));
		if (sd > 0.0) sun_c = sd * exp(-(get_optical_depth(camera_pos, sun_dir, ray_sphere_intersect(camera_pos, sun_dir, atmosphere_radius).y, rayleigh_scale_height) * br_dyn + get_optical_depth(camera_pos, sun_dir, ray_sphere_intersect(camera_pos, sun_dir, atmosphere_radius).y, mie_scale_height) * mie_coefficient)) * mix(vec3(1.0, 0.95, 0.9), sunset_tint.rgb, sunset_f) * sun_intensity * 0.5;

		vec3 sky_base = sky_c + mix(moon_c, sun_c, sun_f);
		
		if (enable_flat_clouds) {
			mat2 rot = mat2(vec2(cos(TIME * flat_cloud_rotation_speed), sin(TIME * flat_cloud_rotation_speed)), vec2(-sin(TIME * flat_cloud_rotation_speed), cos(TIME * flat_cloud_rotation_speed)));
			vec3 rv = view_dir; rv.xz = rot * rv.xz;
			vec3 w = pow(abs(rv), vec3(1.0)); w /= (w.x + w.y + w.z);
			float cs = smoothstep(1.0 - flat_cloud_cover, 1.0, texture(flat_cloud_map, rv.zy * flat_cloud_tiling + vec2(TIME * flat_cloud_speed, 0.0)).r * w.x + texture(flat_cloud_map, rv.xz * flat_cloud_tiling + vec2(TIME * flat_cloud_speed, 0.0)).r * w.y + texture(flat_cloud_map, rv.xy * flat_cloud_tiling + vec2(TIME * flat_cloud_speed, 0.0)).r * w.z);
			if (cs > 0.01) sky_base = mix(sky_base, flat_cloud_color.rgb * mix(calculate_scattering(-sun_dir, moon_intensity, view_dir, camera_pos, ray_len, beta_r, mie_coefficient) + night_ambient_color.rgb * 0.2, day_s, sun_f) + mix(night_ambient_color.rgb * moon_intensity * 0.5, mix(vec3(1.0, 0.95, 0.9), sunset_tint.rgb, sunset_f) * sun_intensity * 0.05, sun_f) * hg_phase(dot(view_dir, mix(moon_dir, sun_dir, sun_f)), flat_cloud_anisotropy) * flat_cloud_scattering, cs * flat_cloud_opacity * pow(clamp(1.0 - view_dir.y, 0.0, 1.0), 2.0));
		}

		color = enable_procedural_clouds ? calculate_procedural_clouds(camera_pos, view_dir, sun_dir, mix(night_ambient_color.rgb * moon_intensity * 2.0, mix(vec3(1.0, 0.95, 0.9), sunset_tint.rgb, sunset_f) * sun_intensity, sun_f), day_s * sun_f + (night_ambient_color.rgb + cloud_night_color.rgb * cloud_night_color.a) * (1.0 - sun_f), sky_base) : sky_base;
		
		if (enable_dome_fog) color = mix(color, mix((calculate_scattering(-sun_dir, moon_intensity, view_dir, camera_pos, ray_len, beta_r, mie_coefficient) + night_ambient_color.rgb), day_s, sun_f) * dome_fog_color.rgb * dome_fog_intensity, 1.0 - smoothstep(dome_fog_start, dome_fog_end, view_dir.y));
		if (enable_global_fog) { vec4 gf = calculate_global_fog(camera_pos + view_dir * ray_len, view_dir, sun_dir, LIGHT0_COLOR * LIGHT0_ENERGY, sun_f); color = mix(color, gf.rgb, gf.a); }
	}
	COLOR = color * exposure;
}