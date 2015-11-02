import sys
sys.path.append('../../sharedmem')
import neato
from pycuda import autoinit
import pycuda.gpuarray as gpuarray
import pycuda.driver as cuda
import numpy as np

from neato import NearToeplitzSolver
from prettytable import PrettyTable

sizes = (32, 64, 128, 256, 512, 1024, 2048)
num_systems = (32, 64, 128, 256, 512, 1024, 2048)

start = cuda.Event()
end = cuda.Event()
nsteps = 10

table = PrettyTable()
for N, nrhs in zip(sizes, num_systems):
    d = np.random.rand(nrhs, N)
    d_d = gpuarray.to_gpu(d)
    solver = NearToeplitzSolver(N, nrhs, (1., 2., 1./4, 1., 1./4, 2., 1.))
    for i in range(nsteps):
        if i == 1: start.record()
        solver.solve(d_d)
    end.record()
    end.synchronize()
    table.add_row((N, nrhs, start.time_till(end)/(nsteps-1)))
table.field_names = ('System size', 'Number of systems', 'Time to solve (ms)')
table.align = 'l'

print table
