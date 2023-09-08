import numpy as np

# ------------------------------------------------------------------------------ 
# Triangles 
# ------------------------------------------------------------------------------ 

def triangle_base(area, height):
    return area * 2 / height 


def triangle_area(base, height):
    return base * height / 2 


def law_of_sins_side(alpha, beta, b):
    return b * (np.sin(alpha) / np.sin(beta))


def law_cosines_side(alpha, beta, gamma):
    return np.sqrt(alpha**2 * beta**2 - (2 * alpha * np.cos(gamma))) 

# ------------------------------------------------------------------------------ 
# Cones 
# ------------------------------------------------------------------------------ 


def cone_volume(radius, height):
   return np.pi * radius**2 * (height/3) 


# ------------------------------------------------------------------------------ 
# Circles 
# ------------------------------------------------------------------------------ 

def circle_area_from_radius(radius):
    return np.pi * radius**2


def circle_area_from_diameter(diameter):
    return np.pi * diameter**2 / 4 


def circle_diameter_from_area(area):
    return np.sqrt(area * 4 / np.pi)


def circle_radius_from_area(area):
    return np.sqrt(area  / np.pi)

# ------------------------------------------------------------------------------ 
# Tubes
# ------------------------------------------------------------------------------ 

def tube_inner_surface_area(r, h):
    return 2 * np.pi * r  * h