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

const int NSTEPS = 200;
const float ACCRETION_MIN_R = 1.5;
const float ACCRETION_WIDTH = 5.0;
const float ACCRETION_BRIGHTNESS = 2.0;
const float STAR_BRIGHTNESS = 1.0;
const float GALAXY_BRIGHTNESS = 0.5;

const float MAX_REVOLUTIONS = 2.0;

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
    
    float u = 1.0 / length(pos);
    
    vec3 n = normalize(cross(pos, ray));
    vec3 x = normalize(pos);
    vec3 y = cross(n,x);
    float du = -dot(ray,x) / dot(ray,y) * u;
    
    
    float theta = M_PI*0.5 - acos(dot(x,ray));
    y = ray;
    x = cross(y,n);
    
    vec3 old_pos;
    
    for (int j=0; j < NSTEPS; j++) {
        
        step = MAX_REVOLUTIONS * 2.0*M_PI / float(NSTEPS);
    
        float ddu = -u*(1.0 - 1.5*u*u);
        u += du*step;
        
        if (u < 0.0) break;
        
        du += ddu*step;
        
        theta += step;
        
        old_pos = pos;
        pos = (cos(theta)*x + sin(theta)*y)/u;
        
        if (old_pos.z * pos.z < 0.0) {
            // crossed plane z=0
            
            ray = pos-old_pos;
            vec3 isec = old_pos + ray*(-old_pos.z / ray.z);
            
            
            float r = length(isec);
            
            if (r > ACCRETION_MIN_R) {
                color += texture2D(accretion_disk_texture,
                    vec2(
                        (r-ACCRETION_MIN_R)/ACCRETION_WIDTH,
                        atan(isec.x, isec.y)/M_PI*0.5+0.5
                    )) * ACCRETION_BRIGHTNESS;
                
                // opaque disk
                //if (r < ACCRETION_MIN_R+ACCRETION_WIDTH) { u = 1.5; break; }
            }
        }
        
        if (u > 10.0) break;
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
