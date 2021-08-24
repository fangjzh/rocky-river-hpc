#!/bin/sh

source ./env.sh
. /etc/profile.d/xcat.sh

## xdcp ${nodename} /etc/slurm/slurm.conf /etc/slurm/slurm.conf
xdcp compute /etc/munge/munge.key /etc/munge/munge.key


#######################################################################
#######################################################################



## this command is ok 
pdsh -w ${compute_prefix}0[1-2]  echo 'export MODULEPATH=\${MODULEPATH}:/opt/ohpc/pub/apps/intel/modulefiles' \>\> /etc/profile.d/lmod.sh


#######################################################################
#######################################################################

######
## moldify the /etc/slurm/slurm.conf
## change node name, cpu number, slots et.al.
################
sed -i '/^PartitionName=normal/d'  /etc/slurm/slurm.conf
nodenum=$(cat /etc/hosts | grep ${compute_prefix}0 |wc -l)
echo "PartitionName=normal Nodes=${compute_prefix}0[1-${nodenum}] Default=YES MaxTime=24:00:00 State=UP Oversubscribe=EXCLUSIVE" >> /etc/slurm/slurm.conf


systemctl restart munge
systemctl restart slurmctld


pdsh -w cnode0[1-2] systemctl restart munge
pdsh -w cnode0[1-2] systemctl restart slurmd