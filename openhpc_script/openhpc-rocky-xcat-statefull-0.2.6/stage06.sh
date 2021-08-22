source ./env.sh
. /etc/profile.d/xcat.sh
##

###install develop tools##
yum -y -q install ohpc-autotools
yum -y -q install EasyBuild-ohpc
yum -y -q install gnu9-compilers-ohpc
yum -y -q install mpich-ucx-gnu9-ohpc
yum -y -q install openmpi4-gnu9-ohpc mpich-ofi-gnu9-ohpc
####
yum -y -q install lmod-defaults-gnu9-openmpi4-ohpc
yum -y -q install glibc-static libstdc++-static
yum -y -q install dos2unix
###


#####install intel one api########
###extract and install#
# cd ${package_dir}
sh ${package_dir}/l_BaseKit_p_2021.3.0.3219_offline.sh -x 
cd l_BaseKit_p_2021.3.0.3219_offline
##./install.sh --install-dir=/opt/ohpc/pub/apps/intel --silent --eula accept
./install.sh --components intel.oneapi.lin.dpcpp-cpp-compiler:intel.oneapi.lin.mkl.devel  --install-dir=/opt/ohpc/pub/apps/intel --silent --eula accept
sleep 6
cd ..

# cd ${package_dir}
sh ${package_dir}/l_HPCKit_p_2021.3.0.3230_offline.sh -x
cd l_HPCKit_p_2021.3.0.3230_offline
##./install.sh --install-dir=/opt/ohpc/pub/apps/intel --silent --eula accept
./install.sh --components intel.oneapi.lin.ifort-compiler:intel.oneapi.lin.dpcpp-cpp-compiler-pro:intel.oneapi.lin.mpi.devel --install-dir=/opt/ohpc/pub/apps/intel --silent --eula accept
sleep 6
cd ..

## how to make module###
/opt/ohpc/pub/apps/intel/modulefiles-setup.sh
echo 'export MODULEPATH=${MODULEPATH}:/opt/ohpc/pub/apps/intel/modulefiles' >> /etc/profile.d/lmod.sh
