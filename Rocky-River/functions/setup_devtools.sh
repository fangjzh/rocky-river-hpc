#!/bin/bash
if [ -z ${sms_name} ]; then
    source ./env.text
fi

echo "-->执行 $0 : 安装设置开发环境 - - - - - - - -"

###install develop tools##
# yum -y -q install automake libtool autogen
yum -y -q install ohpc-autotools
yum -y -q install EasyBuild-ohpc
yum -y -q install gnu12-compilers-ohpc
yum -y -q install mpich-ucx-gnu12-ohpc
yum -y -q install openmpi4-gnu12-ohpc mpich-ofi-gnu12-ohpc
####
yum -y -q install lmod-defaults-gnu12-openmpi4-ohpc
yum -y -q install glibc-static libstdc++-static ## libstdc++-devel  ## 
yum -y -q install dos2unix
###


#####install intel one api########
###extract and install#
cd /root
res_tmp=($(find /root /mnt /media /run/media -name 'l_BaseKit*.sh'))
if [ -z ${res_tmp[0]} ]; then
    echo "Intel oneAPI l_BaseKit not find !!!"
    else
    sh ${res_tmp[0]} -x 
    tmp_folder_p=${res_tmp[0]%.*}
    tmp_folder=${tmp_folder_p##*/}
    cd ${tmp_folder}
    ./install.sh --components intel.oneapi.lin.dpcpp-cpp-compiler:intel.oneapi.lin.mkl.devel  --install-dir=/opt/ohpc/pub/apps/intel --silent --eula accept
    sleep 6
    cd /root
fi

cd /root
res_tmp=($(find /root /mnt /media /run/media -name 'l_HPCKit*.sh'))
if [ -z ${res_tmp[0]} ]; then
    echo "Intel oneAPI l_HPCKit not find !!!"
    else
    sh ${res_tmp[0]} -x 
    tmp_folder_p=${res_tmp[0]%.*}
    tmp_folder=${tmp_folder_p##*/}
    cd ${tmp_folder}
    ./install.sh --components intel.oneapi.lin.ifort-compiler:intel.oneapi.lin.dpcpp-cpp-compiler-pro:intel.oneapi.lin.mpi.devel --install-dir=/opt/ohpc/pub/apps/intel --silent --eula accept
    sleep 6
    cd /root
fi

## how to make module###
/opt/ohpc/pub/apps/intel/modulefiles-setup.sh
echo 'export MODULEPATH=${MODULEPATH}:/opt/ohpc/pub/apps/intel/modulefiles' >> /etc/profile.d/lmod.sh

echo "-->执行 $0 : 安装设置开发环境完毕 + = + = + = + = + ="
echo "$0 执行完成！" >${0##*/}.log
