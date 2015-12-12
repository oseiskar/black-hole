#define M_PI 3.141592653589793238462643383279
#define R_SQRT_2 0.7071067811865475
#define DEG_TO_RAD (M_PI/180.0)
#define SQ(x) ((x)*(x))

#define ROT_Y(a) mat3(0, cos(a), sin(a), 1, 0, 0, 0, sin(a), -cos(a))

uniform vec2 resolution;
uniform float time;

uniform float fov_mult;
uniform vec3 cam_pos;
uniform vec3 cam_x;
uniform vec3 cam_y;
uniform vec3 cam_z;

uniform sampler2D galaxy_texture, star_texture,
    accretion_disk_texture, planet_texture;

// stepping parameters
const int NSTEPS = 100;
const float MAX_REVOLUTIONS = 2.0;
const float MAX_U_REL_CHANGE = 0.5;

const float ACCRETION_MIN_R = 1.5;
const float ACCRETION_WIDTH = 5.0;
const float ACCRETION_BRIGHTNESS = 2.0;
const float STAR_BRIGHTNESS = 1.0;
const float GALAXY_BRIGHTNESS = 0.5;

const float PLANET_RADIUS = 0.4;
const float PLANET_DISTANCE = 8.0;

//const vec4 PLANET_COLOR = vec4(0.3, 0.5, 0.8, 1.0);
const float PLANET_AMBIENT = 0.1;

// background texture coordinate system
const mat3 BG_COORDS = ROT_Y(45.0 * DEG_TO_RAD);

// planet texture coordinate system
const float PLANET_AXIAL_TILT = 30.0 * DEG_TO_RAD;
const mat3 PLANET_COORDS = ROT_Y(PLANET_AXIAL_TILT);

const float PLANET_ORBITAL_ANG_VEL = 1.0 / sqrt(2.0*(PLANET_DISTANCE-1.0)) / PLANET_DISTANCE;
const float MAX_PLANET_ROT = (1.0 - PLANET_ORBITAL_ANG_VEL*PLANET_DISTANCE) / PLANET_RADIUS;
const float PLANET_ROTATION_ANG_VEL = -PLANET_ORBITAL_ANG_VEL + MAX_PLANET_ROT * 0.5;

vec2 sphere_map(vec3 p) {
    return vec2(atan(p.x,p.y)/M_PI*0.5+0.5, asin(p.z)/M_PI+0.5);
}

vec4 planet_intersection(vec3 old_pos, vec3 ray, float t, float dt, vec3 planet_pos0) {
    vec4 ret = vec4(0,0,0,0);
    
{{#light_travel_time}}
    float planet_ang1 = (t-dt) * PLANET_ORBITAL_ANG_VEL;
    vec3 planet_pos1 = vec3(cos(planet_ang1), sin(planet_ang1), 0)*PLANET_DISTANCE;
    vec3 planet_vel = (planet_pos1-planet_pos0)/dt;
    
    // transform to moving planet coordinate system
    vec3 rel_ray = ray/dt - planet_vel;
    
    // ray-sphere intersection
    vec3 d = old_pos - planet_pos0;
    float dotp = dot(d,rel_ray);
    float c_coeff = dot(d,d) - SQ(PLANET_RADIUS);
    float ray2 = dot(rel_ray, rel_ray);
    float discr = dotp*dotp - ray2*c_coeff;
    
    if (discr < 0.0) return ret;
    
    float isec_t = (-dotp - sqrt(discr)) / ray2;
    
    if (isec_t < 0.0 || isec_t > dt) return ret;
    
    vec3 surface_point = (old_pos + isec_t*rel_ray - planet_pos0) / PLANET_RADIUS;
    vec3 light_dir = (planet_pos0 + planet_vel*isec_t)/PLANET_DISTANCE;
    float rot_phase = (t-isec_t)*PLANET_ROTATION_ANG_VEL*0.5/M_PI;
    
    isec_t = isec_t/dt;
    
{{/light_travel_time}}
    
{{^light_travel_time}}    
    // ray-sphere intersection
    vec3 d = old_pos - planet_pos0;
    float dotp = dot(d,ray);
    float c_coeff = dot(d,d) - SQ(PLANET_RADIUS);
    float ray2 = dot(ray, ray);
    float discr = dotp*dotp - ray2*c_coeff;
    
    if (discr < 0.0) return ret;
    float isec_t = (-dotp - sqrt(discr)) / ray2;
    
    if (isec_t < 0.0 || isec_t > 1.0) return ret;
    
    vec3 surface_point = (old_pos + isec_t*ray - planet_pos0) / PLANET_RADIUS;
    float rot_phase = time*PLANET_ROTATION_ANG_VEL*0.5/M_PI;
    vec3 light_dir = planet_pos0/PLANET_DISTANCE;
    
{{/light_travel_time}}
    
    vec2 tex_coord = sphere_map(surface_point * PLANET_COORDS);
    tex_coord.x = mod(tex_coord.x + rot_phase, 1.0);
    
    float diffuse = max(0.0, dot(surface_point, -light_dir));
    float lightness = ((1.0-PLANET_AMBIENT)*diffuse + PLANET_AMBIENT);
    
    ret = texture2D(planet_texture, tex_coord) * lightness;
    ret.w = isec_t;
    
    return ret;
}

void main() {
    
    vec2 p = -1.0 + 2.0 * gl_FragCoord.xy / resolution.xy;
    p.y *= resolution.y / resolution.x;
    
    vec3 pos = cam_pos;
    vec3 ray = normalize(p.x*cam_x + p.y*cam_y + fov_mult*cam_z);
    
    float step = 0.01;
    vec4 color = vec4(0.0,0.0,0.0,1.0);
    
    float u = 1.0 / length(pos), old_u;
    
    vec3 n = normalize(cross(pos, ray));
    vec3 x = normalize(pos);
    vec3 y = cross(n,x);
    float du = -dot(ray,x) / dot(ray,y) * u;
    float theta = 0.0;
    float t = time;
    float dt = 0.0;
{{^light_travel_time}}
    float planet_ang0 = t * PLANET_ORBITAL_ANG_VEL;
    vec3 planet_pos0 = vec3(cos(planet_ang0), sin(planet_ang0), 0)*PLANET_DISTANCE;
    
{{/light_travel_time}}
    
    vec3 old_pos;
                
    for (int j=0; j < NSTEPS; j++) {
        
        step = MAX_REVOLUTIONS * 2.0*M_PI / float(NSTEPS);
{{#light_travel_time}}
        if (du > 0.0 && abs(du) > abs(MAX_U_REL_CHANGE*u) / step)
            step = MAX_U_REL_CHANGE*u/du;
{{/light_travel_time}}
        
        old_u = u;
    
        float ddu = -u*(1.0 - 1.5*u*u);
        
{{#light_travel_time}}
{{#gravitational_time_dilation}}
        dt = sqrt(du*du + u*u*(1.0-u))/(u*u*(1.0-u))*step;
{{/gravitational_time_dilation}}
{{/light_travel_time}}
        
        u += du*step;
        
        if (u < 0.0) break;
        
        du += ddu*step;
        
        theta += step;
        
        old_pos = pos;
        pos = (cos(theta)*x + sin(theta)*y)/u;
        
        ray = pos-old_pos;
        float solid_isec_t = 2.0;
        
{{#light_travel_time}}
{{#gravitational_time_dilation}}
        if (min(u,old_u) < 1.0/30.0)
{{/gravitational_time_dilation}}
            dt = length(ray);
{{/light_travel_time}}
        
{{#planet}}
        if (
            (
                old_pos.z * pos.z < 0.0 ||
                min(abs(old_pos.z), abs(pos.z)) < PLANET_RADIUS
            ) &&
            1.0/max(u, old_u) < (PLANET_RADIUS+PLANET_DISTANCE) && 
            1.0/min(u, old_u) > (PLANET_RADIUS-PLANET_DISTANCE)
        ) {
                
{{#light_travel_time}}
            float planet_ang0 = t * PLANET_ORBITAL_ANG_VEL;
            vec3 planet_pos0 = vec3(cos(planet_ang0), sin(planet_ang0), 0)*PLANET_DISTANCE;
{{/light_travel_time}}
            
            vec4 planet_isec = planet_intersection(old_pos, ray, t, dt, planet_pos0);
            if (planet_isec.w > 0.0) {
                solid_isec_t = planet_isec.w;
                planet_isec.w = 1.0;
                color += planet_isec;
            }
        }
{{/planet}}
        
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
                    
                    // accretion disk time evolution
                    //float rot_phase = 1.0 / sqrt(2.0*(r-1.0)) * time * 0.5 / M_PI;
                    //tex_coord.y = mod(tex_coord.x + rot_phase, 1.0);
                    
                    color += texture2D(accretion_disk_texture,tex_coord) * ACCRETION_BRIGHTNESS;
                    
                    // opaque disk
                    //if (r < ACCRETION_MIN_R+ACCRETION_WIDTH) { solid_isec_t = 0.5; }
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
        
        color += texture2D(star_texture, tex_coord) * STAR_BRIGHTNESS;
        color += texture2D(galaxy_texture, tex_coord) * GALAXY_BRIGHTNESS;
    }
    
    gl_FragColor = color;
}
