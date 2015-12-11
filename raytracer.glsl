#define M_PI 3.141592653589793238462643383279
#define R_SQRT_2 0.7071067811865475

uniform vec2 resolution;
uniform float time;

uniform float fov_mult;
uniform vec3 cam_pos;
uniform vec3 cam_x;
uniform vec3 cam_y;
uniform vec3 cam_z;

uniform sampler2D galaxy_texture, star_texture, accretion_disk_texture;

const int NSTEPS = 100;
const float MAX_REVOLUTIONS = 2.0;

const float ACCRETION_MIN_R = 1.5;
const float ACCRETION_WIDTH = 5.0;
const float ACCRETION_BRIGHTNESS = 2.0;
const float STAR_BRIGHTNESS = 1.0;
const float GALAXY_BRIGHTNESS = 0.5;

const float PLANET_RADIUS = 0.3;
const float PLANET_DISTANCE = 8.0;

const vec4 PLANET_COLOR = vec4(0.3, 0.5, 0.8, 1.0);
const float PLANET_AMBIENT = 0.1;

// background texture coordinate system
const vec3 bg_x = vec3(0,R_SQRT_2,R_SQRT_2);
const vec3 bg_y = vec3(1,0,0);
const vec3 bg_z = vec3(0,R_SQRT_2,-R_SQRT_2);

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
    
    const float PLANET_ANGULAR_VELOCITY = 1.0 / sqrt(2.0*(PLANET_DISTANCE-1.0));
    
    vec3 old_pos;
    
    float planet_ang = time * PLANET_ANGULAR_VELOCITY;
    vec3 planet_pos = vec3(cos(planet_ang), sin(planet_ang), 0)*PLANET_DISTANCE;
                
    for (int j=0; j < NSTEPS; j++) {
        
        step = MAX_REVOLUTIONS * 2.0*M_PI / float(NSTEPS);
        old_u = u;
    
        float ddu = -u*(1.0 - 1.5*u*u);
        u += du*step;
        
        if (u < 0.0) break;
        
        du += ddu*step;
        
        theta += step;
        
        old_pos = pos;
        pos = (cos(theta)*x + sin(theta)*y)/u;
        
        ray = pos-old_pos;
        float solid_isec_t = 2.0;
        
        {{#planet}}
        if (old_pos.z * pos.z < 0.0 ||
            min(abs(old_pos.z), abs(pos.z)) < PLANET_RADIUS) {
            
            // ray-sphere intersection
            vec3 d = old_pos - planet_pos;
            float dotp = dot(d,ray);
            float c_coeff = dot(d,d) - PLANET_RADIUS*PLANET_RADIUS;
            float ray2 = dot(ray, ray);
            float discr = dotp*dotp - ray2*c_coeff;
            
            if (discr > 0.0) {
                float isec_t = (-dotp - sqrt(discr)) / ray2;
                if (isec_t >= 0.0 && isec_t < 1.0) {
                    vec3 normal = (old_pos + isec_t*ray - planet_pos) / PLANET_RADIUS;
                    vec3 light_dir = planet_pos/PLANET_DISTANCE;
                    float diffuse = max(0.0, dot(normal, -light_dir));
                    color += PLANET_COLOR * ((1.0-PLANET_AMBIENT)*diffuse + PLANET_AMBIENT);
                    solid_isec_t = isec_t;
                }
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
                    color += texture2D(accretion_disk_texture,
                        vec2(
                            (r-ACCRETION_MIN_R)/ACCRETION_WIDTH,
                            atan(isec.x, isec.y)/M_PI*0.5+0.5
                        )) * ACCRETION_BRIGHTNESS;
                    
                    // opaque disk
                    //if (r < ACCRETION_MIN_R+ACCRETION_WIDTH) { solid_isec_t = 0.5; }
                }
            }
        }
        {{/accretion_disk}}
        
        if (solid_isec_t <= 1.0) u = 2.0; // break
        if (u > 1.0) break;
    }
        
    // the event horizon is at u = 1
    if (u < 1.0) { 
        ray = normalize(pos - old_pos);
        vec2 tex_coord = vec2(
            atan(dot(ray,bg_x),dot(ray,bg_y))/M_PI*0.5+0.5,
            asin(dot(ray,bg_z))/M_PI+0.5
        );
        
        color += texture2D(star_texture, tex_coord) * STAR_BRIGHTNESS;
        color += texture2D(galaxy_texture, tex_coord) * GALAXY_BRIGHTNESS;
    }
    
    gl_FragColor = color;
}
