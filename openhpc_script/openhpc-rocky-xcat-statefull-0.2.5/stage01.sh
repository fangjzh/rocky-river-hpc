#!/bin/sh
source ./env.sh

echo " ## user define " >> /root/.bashrc
echo "unset command_not_found_handle" >> /root/.bashrc
source /root/.bashrc

if [ $? != 0 ]; then
echo "no env.sh find. error!"
exit
fi

#### check files ###
filelist=(
backup_xcat_hack.tgz
env.sh
epel.tar
l_BaseKit_p_2021.3.0.3219_offline.sh
l_HPCKit_p_2021.3.0.3230_offline.sh
mypostboot.bash
OpenHPC-2.3.CentOS_8.x86_64.tar
Rocky-8.4-x86_64-dvd1.iso
Rocky-local.repo
RockyOs.tgz
stage01.sh
stage02.sh
stage03.sh
stage04.sh
stage05.sh
xcat/xcat-core-2.16.2-linux.tar.bz2  
xcat/xcat-dep-2.16.2-linux.tar.bz2
)

for ifile in ${filelist[@]}
do
  if [ ! -e ${package_dir}/${ifile} ] ; then
  echo "${ifile} is not exist!!!"
  exit
fi
done

###source ./env.sh

###make local repo####
perl -pi -e "s/enabled=1/enabled=0/" /etc/yum.repos.d/Rocky-*.repo

mkdir -p /opt/repo/rocky
mkdir -p /root/iso_mnt
mount -o loop ${package_dir}/Rocky-8.4-x86_64-dvd1.iso   /root/iso_mnt
cp -r /root/iso_mnt/*  /opt/repo/rocky

# for virmachine mount cdrom device
# mkdir /mnt/cdrom
# mount -t auto /dev/cdrom /mnt/cdrom
# cp -r /mnt/cdrom/*  /opt/repo/rocky

##cp -r ${package_dir}/Rocky-package/* /opt/repo/rocky

tar -xf ${package_dir}/epel.tar -C /opt/repo/rocky
tar -xzf ${package_dir}/RockyOs.tgz -C /opt/repo/rocky
mv /opt/repo/rocky/RockyOs/* /opt/repo/rocky
rm -rf /opt/repo/rocky/RockyOs

/bin/cp ${package_dir}/Rocky-local.repo  /etc/yum.repos.d/

mkdir -p /opt/repo/openhpc
tar -xf ${package_dir}/OpenHPC-2.3.CentOS_8.x86_64.tar -C /opt/repo/openhpc
/opt/repo/openhpc/make_repo.sh

mkdir -p /opt/repo/xcat
tar -xjf ${package_dir}/xcat/xcat-dep-2.16.2-linux.tar.bz2 -C /opt/repo/xcat
tar -xjf ${package_dir}/xcat/xcat-core-2.16.2-linux.tar.bz2 -C /opt/repo/xcat
/opt/repo/xcat/xcat-dep/rh8/x86_64/mklocalrepo.sh
/opt/repo/xcat/xcat-core/mklocalrepo.sh


yum clean all
yum makecache

if [ $? != 0 ]; then
echo "make repo error!"
exit
else
echo "make repo succeed !"
fi


#######################
### create repo file for compute node ###
##package_dir=/root/package
cat ${package_dir}/Rocky-local.repo | sed 's/file:\//http:\/\/'"${sms_ip}"':80/' > /opt/repo/compute_node.repo
echo "     " >> /opt/repo/compute_node.repo
cat /etc/yum.repos.d/OpenHPC.local.repo | sed 's/file:\//http:\/\/'"${sms_ip}"':80/' >> /opt/repo/compute_node.repo
echo "     " >> /opt/repo/compute_node.repo
cat /etc/yum.repos.d/xcat-core.repo | sed 's/file:\//http:\/\/'"${sms_ip}"':80/' >> /opt/repo/compute_node.repo
echo "     " >> /opt/repo/compute_node.repo
cat /etc/yum.repos.d/xcat-dep.repo | sed 's/file:\//http:\/\/'"${sms_ip}"':80/' >> /opt/repo/compute_node.repo
echo "     " >> /opt/repo/compute_node.repo



#########change server name#########
echo ${sms_name} > /etc/hostname
echo "${sms_ip}  ${sms_name}  ${sms_name}.${domain_name}" >>/etc/hosts
nmcli g hostname ${sms_name}


#########set internal interface####
nmcli conn mod ${sms_eth_internal} ipv4.address ${sms_ip}/${internal_netmask_l}
nmcli conn mod ${sms_eth_internal} ipv4.gateway ${sms_ip}
nmcli conn mod ${sms_eth_internal} ipv4.dns ${sms_ip}
nmcli conn mod ${sms_eth_internal} ipv4.method manual
nmcli conn up ${sms_eth_internal}

if [ $? != 0 ]; then
echo "network error!"
exit
fi

###设置时区###
# timedatectl list-timezones
timedatectl set-timezone Asia/Shanghai

########disable firewall#####
systemctl disable firewalld
systemctl stop firewalld
###disable selinux####
setenforce 0   
perl -pi -e "s/ELINUX=enforcing/SELINUX=disabled/" /etc/sysconfig/selinux
### need reboot ##


######install ohpc and xcat #########
yum -y -q install ohpc-base  xCAT.x86_64 


# enable xCAT tools for use in current shell
. /etc/profile.d/xcat.sh

if [ $? != 0 ]; then
echo xcat install or initiation error!
exit
fi

# Register internal provisioning interface with xCAT for DHCP
chdef -t site dhcpinterfaces="xcatmn|${sms_eth_internal}"
####
chdef -t site domain=${domain_name}
###


#########  add postbootscripts ####
sed -i 's/10.0.0.1/'${sms_ip}'/' ${package_dir}/mypostboot.bash
sed -i 's/sms_name=cjhpc/sms_name='${sms_name}'/' ${package_dir}/mypostboot.bash
sed -i 's/domain_name=local/domain_name='${domain_name}'/' ${package_dir}/mypostboot.bash
/bin/cp ${package_dir}/mypostboot.bash /install/postscripts/mypostboot
chmod +x /install/postscripts/mypostboot


###disable ipv6####
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p /etc/sysctl.conf

######set ntp server########
yum -y -q install chrony
systemctl enable chronyd.service       
echo "server ${sms_name}" >> /etc/chrony.conf
echo "allow all" >> /etc/chrony.conf   
systemctl restart chronyd 

#### install slurm ######
yum -y -q install munge ohpc-slurm-server  
/bin/cp /etc/slurm/slurm.conf.ohpc /etc/slurm/slurm.conf
###start slurm###
perl -pi -e "s/ControlMachine=\S+/ControlMachine=${sms_name}/" /etc/slurm/slurm.conf
##
perl -pi -e "s/JobCompType=jobcomp\/none/#JobCompType=jobcomp\/none/" /etc/slurm/slurm.conf
perl -pi -e 's/NodeName=/##NodeName=/' /etc/slurm/slurm.conf
perl -pi -e 's/PartitionName=/##PartitionName=/' /etc/slurm/slurm.conf
systemctl enable munge
systemctl enable slurmctld
### slurm.conf need to be modified.

### add http repo for compute nodes 
cat >/etc/httpd/conf.d/repo.conf <<'EOF'
AliasMatch ^/opt/repo/(.*)$ "/opt/repo/$1"
<Directory "/opt/repo">
    Options Indexes FollowSymLinks Includes MultiViews
    AllowOverride None
    Require all granted
</Directory>
EOF
systemctl restart httpd
####


#### Install ClusterShell
yum -y -q install clustershell
# Setup node definitions
cd /etc/clustershell/groups.d
cat local.cfg > local.cfg.orig
echo "adm: ${sms_name}" > local.cfg
echo "compute: ${compute_prefix}0[1-3]" >> local.cfg   ####need to be modified
echo "all: @adm,@compute" >> local.cfg
cd ~
######

# Update memlock settings on master
perl -pi -e 's/# End of file/\* soft memlock unlimited\n$&/s' /etc/security/limits.conf
perl -pi -e 's/# End of file/\* hard memlock unlimited\n$&/s' /etc/security/limits.conf

# Disable /tftpboot and /install export entries
perl -pi -e "s|/tftpboot|#/tftpboot|" /etc/exports
perl -pi -e "s|/install|#/install|" /etc/exports
### note: fsid should be uniq, if add dir###
echo "/home *(rw,no_subtree_check,fsid=10,no_root_squash)" >> /etc/exports
echo "/opt/ohpc/pub *(ro,no_subtree_check,fsid=11)" >> /etc/exports
##echo "/opt/repo *(ro,no_subtree_check,fsid=12)" >> /etc/exports
exportfs -a
systemctl restart nfs-server
systemctl enable nfs-server


#####################         ###############################
## add nis server 
yum install -y -q rpcbind yp-tools ypbind ypserv 
systemctl enable rpcbind ypserv ypxfrd yppasswdd
##add ypdomainname
echo "NISDOMAIN=${domain_name}" >> /etc/sysconfig/network
systemctl start rpcbind ypserv ypxfrd yppasswdd
### update nis database 
sleep 6
echo y | /usr/lib64/yp/ypinit -m
sleep 6
###  ctrl-d to continue
systemctl restart rpcbind ypserv ypxfrd yppasswdd
###########



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

