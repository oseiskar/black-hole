import numpy as np
import matplotlib.pyplot as plt

# GLSL-like functions and constants
length = lambda v: np.linalg.norm(v)
normalize = lambda v: v * (1.0/length(v))
cross = np.cross
dot = np.dot
acos = np.arccos
sin = np.sin
cos = np.cos

M_PI = np.pi

def trace_fan(func, angle_min = 0.0, angle_max = 45, n_rays = 30, n_steps = 500):

    torad = lambda a: a / 180.0 * np.pi
    pos0 = (-4,0,0)
    spread_ang = 25 
    
    paths_x = np.zeros((n_steps, n_rays))
    paths_y = paths_x*0
    
    angles = np.linspace(torad(angle_min), torad(angle_max), n_rays+1)[1:]

    for j in range(len(angles)):
        
        path = np.zeros((n_steps,3)) + np.nan
        
        a = angles[j]
        ray = (np.cos(a), np.sin(a), 0)
        
        pos = np.ravel(pos0).T * 1.0
        ray = np.ravel(ray).T * 1.0
        
        func(pos, ray, path)
        paths_x[:,j] = path[:,0]
        paths_y[:,j] = path[:,1]
        
    plt.plot(paths_x, paths_y)
    
    PLT_SCALE = 5
    
    plt.xlim([-PLT_SCALE,PLT_SCALE])
    plt.ylim([-PLT_SCALE,PLT_SCALE])
    
def trace_u(pos, ray, path):
    
    n_steps = path.shape[0]
    
    u = 1.0 / length(pos)
    
    n = normalize(cross(pos, ray))
    x = normalize(pos)
    y = cross(n,x)
    
    du = -dot(ray,x) / dot(ray,y) * u
    
    theta = 0
    
    MAX_REVOLUTIONS = 2
    step = 2.0*M_PI*MAX_REVOLUTIONS / float(n_steps)
    
    for j in range(n_steps):
        
        path[j,:] = pos

        ddu = -u*(1.0 - 1.5*u*u)
        u += du*step

        if u < 0.0: break

        du += ddu*step

        theta += step

        old_pos = pos
        pos = (cos(theta)*x + sin(theta)*y)/u
        
        if u > 1.0: break # even horizon is at 1
