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
    
    vec3 pos = cam_pos;
    vec3 ray = normalize(p.x*cam_x + p.y*cam_y + fov_mult*cam_z);
    
    float step = 0.01;
    float col = 0.0;
    
    float u = 1.0 / length(pos);
    
    vec3 n = normalize(cross(pos, ray));
    vec3 x = normalize(pos);
    vec3 y = cross(n,x);
    
    float du = -dot(ray,x) / dot(ray,y) * u * u * u;
    
    float theta = 0.0;
    
    vec3 old_pos;
    
    for (int j=0; j < 100; j++) {
        
        step = 0.01;
    
        float ddu = -u*(1.0 - 1.5*u*u);
        u += du*step;
        du += ddu*step;
        
        theta += step;
        
        old_pos = pos;
        pos = (cos(theta)*x + sin(theta)*y)/u;
        
        if (abs(pos.z) < 0.1 && abs(length(pos.xy)-0.3) < 0.1 + sin(time*0.1)*0.05) {
            col += 0.02;
        }
    }
    
    float ang = atan(-du / (u*u*u));
    ray = cos(theta)*x + sin(theta)*y;
    ray = sin(ang) * ray + cos(ang) * cross(ray,n);
    
    //ray = normalize(pos - old_pos);
    
    vec4 color = vec4(col, col, col, 1.0);
    vec2 tex_coord = vec2(atan(ray.x,ray.y)/M_PI*0.5+0.5, asin(ray.z)/M_PI+0.5);
    
    color += texture2D(bg_texture, tex_coord);
    
    gl_FragColor = color;
}
