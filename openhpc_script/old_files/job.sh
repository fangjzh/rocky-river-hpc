#!/bin/sh
#SBATCH -N 2
#SBATCH -p normal
#SBATCH -n 4
mpirun   /opt/ohpc/pub/apps/lammps/lmp_mpi  -i in.lj