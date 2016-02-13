#define M_PI 3.141592653589793238462643383279
#define R_SQRT_2 0.7071067811865475
#define DEG_TO_RAD (M_PI/180.0)
#define SQ(x) ((x)*(x))

#define ROT_Y(a) mat3(0, cos(a), sin(a), 1, 0, 0, 0, sin(a), -cos(a))


// spectrum texture lookup helper macros
const float BLACK_BODY_TEXTURE_COORD = 1.0;
const float SINGLE_WAVELENGTH_TEXTURE_COORD = 0.5;
const float TEMPERATURE_LOOKUP_RATIO_TEXTURE_COORD = 0.0;

// black-body texture metadata
const float SPECTRUM_TEX_TEMPERATURE_RANGE = 65504.0;
const float SPECTRUM_TEX_WAVELENGTH_RANGE = 2048.0;
const float SPECTRUM_TEX_RATIO_RANGE = 6.48053329012;

// multi-line macros don't seem to work in WebGL :(
#define BLACK_BODY_COLOR(t) texture2D(spectrum_texture, vec2((t) / SPECTRUM_TEX_TEMPERATURE_RANGE, BLACK_BODY_TEXTURE_COORD))
#define SINGLE_WAVELENGTH_COLOR(lambda) texture2D(spectrum_texture, vec2((lambda) / SPECTRUM_TEX_WAVELENGTH_RANGE, SINGLE_WAVELENGTH_TEXTURE_COORD))
#define TEMPERATURE_LOOKUP(ratio) (texture2D(spectrum_texture, vec2((ratio) / SPECTRUM_TEX_RATIO_RANGE, TEMPERATURE_LOOKUP_RATIO_TEXTURE_COORD)).r * SPECTRUM_TEX_TEMPERATURE_RANGE)

uniform vec2 resolution;
uniform float time;

uniform vec3 cam_pos;
uniform vec3 cam_x;
uniform vec3 cam_y;
uniform vec3 cam_z;
uniform vec3 cam_vel;

uniform float planet_distance, planet_radius;

uniform sampler2D galaxy_texture, star_texture,
    accretion_disk_texture, planet_texture, spectrum_texture;

// stepping parameters
const int NSTEPS = {{n_steps}};
const float MAX_REVOLUTIONS = 2.0;

const float ACCRETION_MIN_R = 1.5;
const float ACCRETION_WIDTH = 5.0;
const float ACCRETION_BRIGHTNESS = 0.9;
const float ACCRETION_TEMPERATURE = 3900.0;

const float STAR_MIN_TEMPERATURE = 4000.0;
const float STAR_MAX_TEMPERATURE = 15000.0;

const float STAR_BRIGHTNESS = 1.0;
const float GALAXY_BRIGHTNESS = 0.4;

const float PLANET_AMBIENT = 0.1;
const float PLANET_LIGHTNESS = 1.5;

// background texture coordinate system
mat3 BG_COORDS = ROT_Y(45.0 * DEG_TO_RAD);

// planet texture coordinate system
const float PLANET_AXIAL_TILT = 30.0 * DEG_TO_RAD;
mat3 PLANET_COORDS = ROT_Y(PLANET_AXIAL_TILT);

const float FOV_ANGLE_DEG = 90.0;
float FOV_MULT = 1.0 / tan(DEG_TO_RAD * FOV_ANGLE_DEG*0.5);

// derived "constants" (from uniforms)
float PLANET_RADIUS,
    PLANET_DISTANCE,
    PLANET_ORBITAL_ANG_VEL,
    PLANET_ROTATION_ANG_VEL,
    PLANET_GAMMA;

vec2 sphere_map(vec3 p) {
    return vec2(atan(p.x,p.y)/M_PI*0.5+0.5, asin(p.z)/M_PI+0.5);
}

float smooth_step(float x, float threshold) {
    const float STEEPNESS = 1.0;
    return 1.0 / (1.0 + exp(-(x-threshold)*STEEPNESS));
}

vec3 lorentz_velocity_transformation(vec3 moving_v, vec3 frame_v) {
    float v = length(frame_v);
    if (v > 0.0) {
        vec3 v_axis = -frame_v / v;
        float gamma = 1.0/sqrt(1.0 - v*v);

        float moving_par = dot(moving_v, v_axis);
        vec3 moving_perp = moving_v - v_axis*moving_par;

        float denom = 1.0 + v*moving_par;
        return (v_axis*(moving_par+v)+moving_perp/gamma)/denom;
    }
    return moving_v;
}

vec3 contract(vec3 x, vec3 d, float mult) {
    float par = dot(x,d);
    return (x-par*d) + d*par*mult;
}

vec4 planet_intersection(vec3 old_pos, vec3 ray, float t, float dt,
        vec3 planet_pos0, float ray_doppler_factor) {

    vec4 ret = vec4(0,0,0,0);
    vec3 ray0 = ray;
    ray = ray/dt;

    vec3 planet_dir = vec3(planet_pos0.y, -planet_pos0.x, 0.0) / PLANET_DISTANCE;

    {{#light_travel_time}}
    float planet_ang1 = (t-dt) * PLANET_ORBITAL_ANG_VEL;
    vec3 planet_pos1 = vec3(cos(planet_ang1), sin(planet_ang1), 0)*PLANET_DISTANCE;
    vec3 planet_vel = (planet_pos1-planet_pos0)/dt;

    // transform to moving planet coordinate system
    ray = ray - planet_vel;
    {{/light_travel_time}}
    {{^light_travel_time}}
    vec3 planet_vel = planet_dir * PLANET_ORBITAL_ANG_VEL * PLANET_DISTANCE;
    {{/light_travel_time}}

    // ray-sphere intersection
    vec3 d = old_pos - planet_pos0;

    {{#lorentz_contraction}}
    ray = contract(ray, planet_dir, PLANET_GAMMA);
    d = contract(d, planet_dir, PLANET_GAMMA);
    {{/lorentz_contraction}}

    float dotp = dot(d,ray);
    float c_coeff = dot(d,d) - SQ(PLANET_RADIUS);
    float ray2 = dot(ray, ray);
    float discr = dotp*dotp - ray2*c_coeff;

    if (discr < 0.0) return ret;
    float isec_t = (-dotp - sqrt(discr)) / ray2;

    float MIN_ISEC_DT = 0.0;
    {{#lorentz_contraction}}
    MIN_ISEC_DT = -dt;
    {{/lorentz_contraction}}

    if (isec_t < MIN_ISEC_DT || isec_t > dt) return ret;

    vec3 surface_point = (d + isec_t*ray) / PLANET_RADIUS;

    isec_t = isec_t/dt;

    vec3 light_dir = planet_pos0;
    float rot_phase = t;

    {{#light_travel_time}}
    light_dir += planet_vel*isec_t*dt;
    rot_phase -= isec_t*dt;
    {{/light_travel_time}}

    rot_phase = rot_phase * PLANET_ROTATION_ANG_VEL*0.5/M_PI;
    light_dir = light_dir / PLANET_DISTANCE;

    {{#light_travel_time}}
    light_dir = light_dir - planet_vel;
    {{/light_travel_time}}

    vec3 surface_normal = surface_point;
    {{#lorentz_contraction}}
    light_dir = contract(light_dir, planet_dir, PLANET_GAMMA);
    {{/lorentz_contraction}}
    light_dir = normalize(light_dir);

    vec2 tex_coord = sphere_map(surface_point * PLANET_COORDS);
    tex_coord.x = mod(tex_coord.x + rot_phase, 1.0);

    float diffuse = max(0.0, dot(surface_normal, -light_dir));
    float lightness = ((1.0-PLANET_AMBIENT)*diffuse + PLANET_AMBIENT) *
        PLANET_LIGHTNESS;

    float light_temperature = ACCRETION_TEMPERATURE;
    {{#doppler_shift}}
    float doppler_factor = SQ(PLANET_GAMMA) *
        (1.0 + dot(planet_vel, light_dir)) *
        (1.0 - dot(planet_vel, normalize(ray)));
    light_temperature /= doppler_factor * ray_doppler_factor;
    {{/doppler_shift}}

    vec4 light_color = BLACK_BODY_COLOR(light_temperature);
    ret = texture2D(planet_texture, tex_coord) * lightness * light_color;
    if (isec_t < 0.0) isec_t = 0.5;
    ret.w = isec_t;

    return ret;
}

vec4 galaxy_color(vec2 tex_coord, float doppler_factor) {

    vec4 color = texture2D(galaxy_texture, tex_coord);
    {{^observerMotion}}
    return color;
    {{/observerMotion}}

    {{#observerMotion}}
    vec4 ret = vec4(0.0,0.0,0.0,0.0);
    float red = max(0.0, color.r - color.g);

    const float H_ALPHA_RATIO = 0.1;
    const float TEMPERATURE_BIAS = 0.95;

    color.r -= red*H_ALPHA_RATIO;

    float i1 = max(color.r, max(color.g, color.b));
    float ratio = (color.g+color.b) / color.r;

    if (i1 > 0.0 && color.r > 0.0) {

        float temperature = TEMPERATURE_LOOKUP(ratio) * TEMPERATURE_BIAS;
        color = BLACK_BODY_COLOR(temperature);

        float i0 = max(color.r, max(color.g, color.b));
        if (i0 > 0.0) {
            temperature /= doppler_factor;
            ret = BLACK_BODY_COLOR(temperature) * max(i1/i0,0.0);
        }
    }

    ret += SINGLE_WAVELENGTH_COLOR(656.28 * doppler_factor) * red / 0.214 * H_ALPHA_RATIO;

    return ret;
    {{/observerMotion}}
}

void main() {

    {{#planetEnabled}}
    // "constants" derived from uniforms
    PLANET_RADIUS = planet_radius;
    PLANET_DISTANCE = max(planet_distance,planet_radius+1.5);
    PLANET_ORBITAL_ANG_VEL = -1.0 / sqrt(2.0*(PLANET_DISTANCE-1.0)) / PLANET_DISTANCE;
    float MAX_PLANET_ROT = max((1.0 + PLANET_ORBITAL_ANG_VEL*PLANET_DISTANCE) / PLANET_RADIUS,0.0);
    PLANET_ROTATION_ANG_VEL = -PLANET_ORBITAL_ANG_VEL + MAX_PLANET_ROT * 0.5;
    PLANET_GAMMA = 1.0/sqrt(1.0-SQ(PLANET_ORBITAL_ANG_VEL*PLANET_DISTANCE));
    {{/planetEnabled}}

    vec2 p = -1.0 + 2.0 * gl_FragCoord.xy / resolution.xy;
    p.y *= resolution.y / resolution.x;

    vec3 pos = cam_pos;
    vec3 ray = normalize(p.x*cam_x + p.y*cam_y + FOV_MULT*cam_z);

    {{#aberration}}
    ray = lorentz_velocity_transformation(ray, cam_vel);
    {{/aberration}}

    float ray_intensity = 1.0;
    float ray_doppler_factor = 1.0;

    float gamma = 1.0/sqrt(1.0-dot(cam_vel,cam_vel));
    ray_doppler_factor = gamma*(1.0 + dot(ray,-cam_vel));
    {{#beaming}}
    ray_intensity /= ray_doppler_factor*ray_doppler_factor*ray_doppler_factor;
    {{/beaming}}
    {{^doppler_shift}}
    ray_doppler_factor = 1.0;
    {{/doppler_shift}}

    float step = 0.01;
    vec4 color = vec4(0.0,0.0,0.0,1.0);

    // initial conditions
    float u = 1.0 / length(pos), old_u;
    float u0 = u;

    vec3 normal_vec = normalize(pos);
    vec3 tangent_vec = normalize(cross(cross(normal_vec, ray), normal_vec));

    float du = -dot(ray,normal_vec) / dot(ray,tangent_vec) * u;
    float du0 = du;

    float phi = 0.0;
    float t = time;
    float dt = 1.0;

    {{^light_travel_time}}
    float planet_ang0 = t * PLANET_ORBITAL_ANG_VEL;
    vec3 planet_pos0 = vec3(cos(planet_ang0), sin(planet_ang0), 0)*PLANET_DISTANCE;
    {{/light_travel_time}}

    vec3 old_pos;

    for (int j=0; j < NSTEPS; j++) {

        step = MAX_REVOLUTIONS * 2.0*M_PI / float(NSTEPS);

        // adaptive step size, some ad hoc formulas
        float max_rel_u_change = (1.0-log(u))*10.0 / float(NSTEPS);
        if ((du > 0.0 || (du0 < 0.0 && u0/u < 5.0)) && abs(du) > abs(max_rel_u_change*u) / step)
            step = max_rel_u_change*u/abs(du);

        old_u = u;

        {{#light_travel_time}}
        {{#gravitational_time_dilation}}
        dt = sqrt(du*du + u*u*(1.0-u))/(u*u*(1.0-u))*step;
        {{/gravitational_time_dilation}}
        {{/light_travel_time}}

        // Leapfrog scheme
        u += du*step;
        float ddu = -u*(1.0 - 1.5*u*u);
        du += ddu*step;

        if (u < 0.0) break;

        phi += step;

        old_pos = pos;
        pos = (cos(phi)*normal_vec + sin(phi)*tangent_vec)/u;

        ray = pos-old_pos;
        float solid_isec_t = 2.0;
        float ray_l = length(ray);

        {{#light_travel_time}}
        {{#gravitational_time_dilation}}
        float mix = smooth_step(1.0/u, 8.0);
        dt = mix*ray_l + (1.0-mix)*dt;
        {{/gravitational_time_dilation}}
        {{^gravitational_time_dilation}}
        dt = ray_l;
        {{/gravitational_time_dilation}}
        {{/light_travel_time}}

        {{#planetEnabled}}
        if (
            (
                old_pos.z * pos.z < 0.0 ||
                min(abs(old_pos.z), abs(pos.z)) < PLANET_RADIUS
            ) &&
            max(u, old_u) > 1.0/(PLANET_DISTANCE+PLANET_RADIUS) &&
            min(u, old_u) < 1.0/(PLANET_DISTANCE-PLANET_RADIUS)
        ) {

            {{#light_travel_time}}
            float planet_ang0 = t * PLANET_ORBITAL_ANG_VEL;
            vec3 planet_pos0 = vec3(cos(planet_ang0), sin(planet_ang0), 0)*PLANET_DISTANCE;
            {{/light_travel_time}}

            vec4 planet_isec = planet_intersection(old_pos, ray, t, dt,
                    planet_pos0, ray_doppler_factor);
            if (planet_isec.w > 0.0) {
                solid_isec_t = planet_isec.w;
                planet_isec.w = 1.0;
                color += planet_isec;
            }
        }
        {{/planetEnabled}}

        {{#accretion_disk}}
        if (old_pos.z * pos.z < 0.0) {
            // crossed plane z=0

            float acc_isec_t = -old_pos.z / ray.z;
            if (acc_isec_t < solid_isec_t) {
                vec3 isec = old_pos + ray*acc_isec_t;

                float r = length(isec);

                if (r > ACCRETION_MIN_R) {
                    vec2 tex_coord = vec2(
                            (r-ACCRETION_MIN_R)/ACCRETION_WIDTH,
                            atan(isec.x, isec.y)/M_PI*0.5+0.5
                    );

                    float accretion_intensity = ACCRETION_BRIGHTNESS;
                    //accretion_intensity *= 1.0 / abs(ray.z/ray_l);
                    float temperature = ACCRETION_TEMPERATURE;

                    vec3 accretion_v = vec3(-isec.y, isec.x, 0.0) / sqrt(2.0*(r-1.0)) / (r*r);
                    gamma = 1.0/sqrt(1.0-dot(accretion_v,accretion_v));
                    float doppler_factor = gamma*(1.0+dot(ray/ray_l,accretion_v));
                    {{#beaming}}
                    accretion_intensity /= doppler_factor*doppler_factor*doppler_factor;
                    {{/beaming}}
                    {{#doppler_shift}}
                    temperature /= ray_doppler_factor*doppler_factor;
                    {{/doppler_shift}}

                    color += texture2D(accretion_disk_texture,tex_coord)
                        * accretion_intensity
                        * BLACK_BODY_COLOR(temperature);
                }
            }
        }
        {{/accretion_disk}}

        {{#light_travel_time}}
        t -= dt;
        {{/light_travel_time}}

        if (solid_isec_t <= 1.0) u = 2.0; // break
        if (u > 1.0) break;
    }

    // the event horizon is at u = 1
    if (u < 1.0) {
        ray = normalize(pos - old_pos);
        vec2 tex_coord = sphere_map(ray * BG_COORDS);
        float t_coord;

        vec4 star_color = texture2D(star_texture, tex_coord);
        if (star_color.r > 0.0) {
            t_coord = (STAR_MIN_TEMPERATURE +
                (STAR_MAX_TEMPERATURE-STAR_MIN_TEMPERATURE) * star_color.g)
                 / ray_doppler_factor;

            color += BLACK_BODY_COLOR(t_coord) * star_color.r * STAR_BRIGHTNESS;
        }

        color += galaxy_color(tex_coord, ray_doppler_factor) * GALAXY_BRIGHTNESS;
    }

    gl_FragColor = color*ray_intensity;
}
