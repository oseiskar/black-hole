import numpy as np
import matplotlib.pyplot as plt

from glsl_helpers import *

degtorad = lambda a: a / 180.0 * np.pi

def smooth_step(x, threshold, steepness):
    #return np.arctan((x-threshold)/width)/M_PI+0.5
    return 1.0 / (1.0 + exp(-(x-threshold)*steepness))

def trace_u(pos, ray, path):
    """Main raytracer function"""
    
    n_steps = path.shape[0]
    
    u0 = 1.0 / length(pos)
    u = u0
    
    normal_vec = normalize(pos)
    tangent_vec = normalize(cross(cross(normal_vec, ray), normal_vec))
    
    du = -dot(ray,normal_vec) / dot(ray,tangent_vec) * u
    du0 = du
    
    theta = 0
    t = 0
    ddu = 0
    
    MAX_REVOLUTIONS = 2
    theta_step = 2.0*M_PI*MAX_REVOLUTIONS / float(n_steps)
    
    for j in range(n_steps):
        
        max_rel_u_change = (1-log(u))*10.0 / float(n_steps)
        
        step = theta_step
            
        if (du > 0 or (du0 < 0.0 and u0/u < 5.0)) and abs(du) > abs(max_rel_u_change*u) / theta_step:
            step = max_rel_u_change*u/abs(du)
        
        path[j,0:3] = pos
        path[j,3] = t

        u += du*step
        ddu = -u*(1.0 - 1.5*u*u)
        du += ddu*step
        
        if u < 0.0: break
        if u < 1.0: dt = sqrt(du*du + u*u*(1.0-u))/(u*u*(1.0-u))*step
        
        theta += step

        old_pos = pos
        pos = (cos(theta)*normal_vec + sin(theta)*tangent_vec)/u
        
        if u > 1.0: break # even horizon is at 1
        
        # Far away, dr/dtheta becomes large and dt inaccurate:
        # Then just use a classical formula (no Shapiro delay)
        mix = smooth_step(1.0/u, 8.0, 2.0)
        dt = mix*length(pos-old_pos) + (1.0-mix)*dt
        
        #if du < 0 and u < 1.0/5.0:
        
        t += dt


# ---- plotting helpers        

def path_r(path):
    return np.sqrt(np.sum(path[:,0:3]*path[:,0:3],1))

def path_x(path): return path[:,0]
def path_y(path): return path[:,1]
def path_time(path): return path[:,3]
def path_arc_length(path):
    return np.hstack(([0], np.cumsum(path_r(path[1:]-path[:-1]))))

def path_angle(path):
    angles = np.zeros(path[:,0].shape) + np.nan
    diffs = path[1:]-path[:-1]
    angles[:-1] = np.arctan2(diffs[:,1], diffs[:,0])
    return angles

def get_first_non_nas(array):
    nas = np.where(np.logical_not(np.isfinite(array)))[0]
    if nas.size == 0 or nas[0] == 0: return array
    return array[:nas[0]]

def last_cont_non_na(array):
    array = get_first_non_nas(array)
    if array.size == 0: return np.nan
    return array[-1]

def crossing_func(path, x_func, y_func, threshold):
    x = get_first_non_nas(x_func(path))
    y = get_first_non_nas(y_func(path))
    if x.size < 2 or y.size < 2: return np.nan
    
    ins = np.where(y < threshold)[0]
    if ins.size == 0 or ins[0] == 0: return np.nan
    i1 = ins[0]
    i0 = i1 - 1
    return np.interp(threshold, [y[i1], y[i0]], [x[i1], x[i0]])

def ball_entry_time(path, radius):
    return crossing_func(path, path_time, path_r, radius) 
    
def ball_entry_dist(path, radius):
    return crossing_func(path, path_arc_length, path_r, radius) 

def last_angle(path):
    return last_cont_non_na(path_angle(path))
    
def deflection_angle(path):
    if last_cont_non_na(path_r(path)) < 2.0: return np.nan
    return last_angle(path) - path_angle(path)[0]

class PlotParams:
    def __init__(self, **kwargs):
        self.solver_func = trace_u
        self.n_steps = 500
        self.angle = 30
        self.x0 = -4
        self.plot = True
        self.plot_scale = 5
        self.plot_xlim = None
        self.plot_ylim = None
        self.plot_x = path_x
        self.plot_y = path_y
        self.plot_args = {}
        
    def set_params(self, **kwargs):
        for param, value in kwargs.items():
            setattr(self, param, value)
               
def trace_ray(ray=None, **kwargs):
    
    if ray is None: ray = PlotParams()
    ray.set_params(**kwargs)
    
    path = np.zeros((ray.n_steps,4)) + np.nan
    
    a = degtorad(ray.angle)
    pos0 = (ray.x0,0,0)
    ray_dir = (np.cos(a), np.sin(a), 0)
    
    pos = np.ravel(pos0).T * 1.0
    ray_dir = np.ravel(ray_dir).T * 1.0
    
    ray.solver_func(pos, ray_dir, path)
    
    if ray.plot is True:
        plt.plot(ray.plot_x(path), ray.plot_y(path), **ray.plot_args)
        
        if ray.plot_scale is not None:
            plt.xlim([-ray.plot_scale, ray.plot_scale])
            plt.ylim([-ray.plot_scale, ray.plot_scale])
        if ray.plot_xlim is not None: plt.xlim(ray.plot_xlim)
        if ray.plot_ylim is not None: plt.ylim(ray.plot_ylim)
    
    return path

def trace_rays(n_rays = 1, **kwargs):

    agg_xy = np.zeros((n_rays,2)) + np.nan
    
    for j in range(n_rays):
        ray = PlotParams()
        ray.aggregate_plot_x = None
        ray.set_params(**kwargs)
        ray.idx = j
        ray.rel = (j+1) / float(n_rays)
        yield(ray)
        path = trace_ray(ray)
        
        if ray.aggregate_plot_x is not None:
            agg_xy[j,0] = ray.aggregate_plot_x(path)
            agg_xy[j,1] = ray.aggregate_plot_y(path)
    
    if ray.aggregate_plot_x is not None:
        if ray.plot is True: plt.show()
        plt.plot(agg_xy[:,0], agg_xy[:,1])
