#!/bin/sh

source ./env.sh
. /etc/profile.d/xcat.sh

## xdcp ${nodename} /etc/slurm/slurm.conf /etc/slurm/slurm.conf
xdcp compute /etc/munge/munge.key /etc/munge/munge.key


#######################################################################
#######################################################################

###install develop tools##
yum -y install ohpc-autotools
yum -y install EasyBuild-ohpc
yum -y install gnu9-compilers-ohpc
yum -y install mpich-ucx-gnu9-ohpc
yum -y install openmpi4-gnu9-ohpc mpich-ofi-gnu9-ohpc
####
yum -y install lmod-defaults-gnu9-openmpi4-ohpc

#####install intel one api########
###extract and install#
cd ${package_dir}
sh l_BaseKit_p_2021.3.0.3219_offline.sh -x 
cd l_BaseKit_p_2021.3.0.3219_offline
##./install.sh --install-dir=/opt/ohpc/pub/apps/intel --silent --eula accept
./install.sh --components intel.oneapi.lin.dpcpp-cpp-compiler:intel.oneapi.lin.mkl.devel  --install-dir=/opt/ohpc/pub/apps/intel --silent --eula accept

sleep 6

cd ${package_dir}
sh l_HPCKit_p_2021.3.0.3230_offline.sh -x
cd l_HPCKit_p_2021.3.0.3230_offline
##./install.sh --install-dir=/opt/ohpc/pub/apps/intel --silent --eula accept
./install.sh --components intel.oneapi.lin.ifort-compiler:intel.oneapi.lin.dpcpp-cpp-compiler-pro:intel.oneapi.lin.mpi.devel --install-dir=/opt/ohpc/pub/apps/intel --silent --eula accept

sleep 6

## how to make module###
/opt/ohpc/pub/apps/intel/modulefiles-setup.sh

echo 'export MODULEPATH=${MODULEPATH}:/opt/ohpc/pub/apps/intel/modulefiles' >> /etc/profile.d/lmod.sh

## this command is ok 
pdsh -w ${compute_prefix}0[1-2]  echo 'export MODULEPATH=\${MODULEPATH}:/opt/ohpc/pub/apps/intel/modulefiles' \>\> /etc/profile.d/lmod.sh


#######################################################################
#######################################################################

######
## moldify the /etc/slurm/slurm.conf
## change node name, cpu number, slots et.al.
################
sed -i '/^PartitionName=normal/d'  /etc/slurm/slurm.conf
nodenum=$(cat /etc/hosts | grep cnode0 |wc -l)
echo "PartitionName=normal Nodes=${compute_prefix}0[1-${nodenum}] Default=YES MaxTime=24:00:00 State=UP Oversubscribe=EXCLUSIVE" >> /etc/slurm/slurm.conf

systemctl enable munge
systemctl enable slurmctld
systemctl start munge
systemctl start slurmctld


pdsh -w cnode0[1-2] systemctl start munge
pdsh -w cnode0[1-2] systemctl start slurmd