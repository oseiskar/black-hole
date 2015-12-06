#define M_PI 3.141592653589793238462643383279

uniform vec2 resolution;
uniform float time;

uniform float fov_mult;
uniform vec3 cam_pos;
uniform vec3 cam_x;
uniform vec3 cam_y;
uniform vec3 cam_z;

uniform sampler2D bg_texture;

void main() {

    vec2 p = -1.0 + 2.0 * gl_FragCoord.xy / resolution.xy;
    p.y *= resolution.y / resolution.x;
    
    vec3 pos = cam_pos;
    vec3 ray = normalize(p.x*cam_x + p.y*cam_y + fov_mult*cam_z);
    
    float step = 0.01;
    float col = 0.0;
    
    float u = 1.0 / length(pos);
    
    vec3 n = normalize(cross(pos, ray));
    vec3 x = normalize(pos);
    vec3 y = cross(n,x);
    float du = -dot(ray,x) / dot(ray,y) * u;
    
    float theta = M_PI*0.5 - acos(dot(x,ray));
    y = ray;
    x = cross(y,n);
    
    vec3 old_pos;
    
    const int NSTEPS = 300;
    
    for (int j=0; j < NSTEPS; j++) {
        
        step = 2.0 * 2.0*M_PI / float(NSTEPS);
    
        float ddu = -u*(1.0 - 1.5*u*u);
        u += du*step;
        
        if (u < 0.0) break;
        
        du += ddu*step;
        
        theta += step;
        
        old_pos = pos;
        pos = (cos(theta)*x + sin(theta)*y)/u;
        
        if (abs(pos.z) < 0.1 && abs(length(pos.xy)-0.3) < 0.1 + sin(time*0.1)*0.05) {
            col += 0.02;
        }
        
        if (u > 10.0) break;
    }
    
    vec4 color = vec4(col, col, col, 1.0);
        
    // the event horizon is at u = 1
    if (u < 1.0) { 
        ray = normalize(pos - old_pos);
        vec2 tex_coord = vec2(atan(ray.x,ray.y)/M_PI*0.5+0.5, asin(ray.z)/M_PI+0.5);
        
        color += texture2D(bg_texture, tex_coord);
    }
    
    gl_FragColor = color;
}
