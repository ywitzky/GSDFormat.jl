### taken from https://hoomd-blue.readthedocs.io/en/latest/tutorial/00-Introducing-HOOMD-blue/03-Initializing-the-System-State.html

import itertools
import math

import numpy
import copy
import os 
dir_path = os.path.dirname(os.path.realpath(__file__))

m = 2
N_particles = 2 * m**3

spacing = 1.0
K = math.ceil(N_particles ** (1 / 3))
L = K * spacing


x = numpy.linspace(-L / 2, L / 2, K, endpoint=False)
position = list(itertools.product(x, repeat=3))
position = position[0:N_particles]


import gsd.hoomd
frame = gsd.hoomd.Frame()
frame.particles.N = N_particles
frame.particles.position = position

frame.particles.mass = [123.5] *N_particles
frame.particles.charge = [-1.0] *N_particles
frame.particles.diameter = [5.0] *N_particles
frame.particles.body = [3.0]*N_particles
frame.particles.moment_inertia = [1.0, 2.0, 3.0]*N_particles
frame.particles.velocity = [4.0, 5.0, 6.0]*N_particles
frame.particles.angmom = [7.0, 8.0, 9.0, 10.0]*N_particles
frame.particles.image =  [(0, 0, 1)] * (N_particles)
frame.particles.orientation = [(1, 0, 0, 0)] * (N_particles)

frame.particles.typeid = [1.0] * N_particles
frame.particles.types = ['octahedron']
frame.configuration.box = [L, L, L, 0, 0, 0]
frame.configuration.step = 1
frame.configuration.dimensions = 3


frame.bonds.N =2
frame.bonds.typeid=[0,1]
frame.bonds.types = ['typea', 'typeb']
frame.bonds.group = [[0,1], [1,2]]

frame.angles.N =3
frame.angles.typeid=[0,1,2]
frame.angles.types = ['bond_a', 'bond_b', 'bond_c']
frame.angles.group = [[0,1,2], [1,2,3], [2,3,4]]

frame.dihedrals.N =4
frame.dihedrals.typeid=[0,1,2,3]
frame.dihedrals.types = ['dih_a', 'dih_b', 'dih_c', 'dih_d']
frame.dihedrals.group = [[0,1,2,3], [1,2,3,4], [2,3,4,5], [3,4,5,6]]

with gsd.hoomd.open(name=f"{dir_path}/python_output.gsd", mode='w') as f:
    f.append(frame)
    frame.particles.mass = [13.5] *N_particles

    frame2 = copy.deepcopy(frame)
    frame2.particles.orientation = [(1, 0, 0, 1)] * N_particles
    frame2.particles.mass = [321.5] *N_particles
    frame2.particles.image =  [(0, 0, 0)] * N_particles

    frame2.particles.typeid = [1.0] * N_particles
    frame2.particles.types = ['my_new_name']

    f.append(frame2)
