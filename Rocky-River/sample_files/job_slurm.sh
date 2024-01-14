#!/bin/bash
#SBATCH --job-name=test                 # Job name
#SBATCH --nodes=1                       # Maximum number of nodes to be allocated
#SBATCH --ntasks=48                     # Run on 52 cores
#SBATCH --partition=normal                   # Partitions name
#SBATCH --output=%j.log            # Standard output and error log

echo "Date              = $(date)"
echo "Hostname          = $(hostname -s)"
echo "Working Directory = $(pwd)"
echo ""
echo "Number of Nodes Allocated      = $SLURM_JOB_NUM_NODES"
echo "Number of Tasks Allocated      = $SLURM_NTASKS"
echo "Number of Cores/Task Allocated = $SLURM_CPUS_PER_TASK"

#module load compiler/latest
module load mpi

mpirun -np $SLURM_NTASKS /opt/ohpc/pub/apps/lammps-stable_23Jun2022_update3/src/lmp_mpi -i in.eam