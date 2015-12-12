# GLSL-like functions and constants
import numpy as np

length = lambda v: np.linalg.norm(v)
normalize = lambda v: v * (1.0/length(v))
cross = np.cross
dot = np.dot
acos = np.arccos
sin = np.sin
cos = np.cos
sqrt = np.sqrt

M_PI = np.pi

vec3 = lambda x,y,z: np.array((x,y,z))
